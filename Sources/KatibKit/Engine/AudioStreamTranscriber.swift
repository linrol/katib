import Foundation

/// Low-Latency Adaptive VAD & Smart Pause Chunking Stream Transcriber.
public final class AudioStreamTranscriber: @unchecked Sendable {
    public let label: String
    public var onCommitSentence: (@Sendable (String) -> Void)?

    private var accumulatedSamples: [Float] = []
    private var lastSpeechTime: Date = Date.distantPast
    private var hasVoiceActivity: Bool = false
    private var silenceTimer: Timer?

    // Low-latency timing parameters
    private let silenceThreshold: TimeInterval = 0.45 // Fast sentence pause cut
    private let shortPauseThreshold: TimeInterval = 0.25 // Quick pause cut when buffer is long
    private let targetSegmentSamples: Int = 16000 * 3 // 3s target segment
    private let maxContinuousSamples: Int = 16000 * 5 // 5s hard cap
    private let minSpeechSamples: Int = 4800 // 300ms minimum speech length
    private let voiceRmsThreshold: Float // Sensitivity threshold

    public private(set) var isRunning: Bool = false
    private let lock = NSLock()

    public init(label: String, rmsThreshold: Float = 0.012) {
        self.label = label
        self.voiceRmsThreshold = rmsThreshold
    }

    public func start() throws {
        stop()
        lock.lock()
        isRunning = true
        accumulatedSamples.removeAll()
        hasVoiceActivity = false
        lastSpeechTime = Date.distantPast
        lock.unlock()

        DispatchQueue.main.async { [weak self] in
            self?.startSilenceWatcher()
        }
        NSLog("[Transcriber-\(label)] SenseVoice offline audio stream monitoring started")
    }

    public func stop() {
        lock.lock()
        isRunning = false
        accumulatedSamples.removeAll()
        hasVoiceActivity = false
        silenceTimer?.invalidate()
        silenceTimer = nil
        lock.unlock()
        NSLog("[Transcriber-\(label)] SenseVoice offline audio stream monitoring stopped")
    }

    public func appendAudioSamples(_ floats: [Float]) {
        guard !floats.isEmpty else { return }
        lock.lock()
        defer { lock.unlock() }
        guard isRunning else { return }

        // Calculate RMS energy to detect voice activity
        var sumSquares: Float = 0
        for s in floats {
            sumSquares += s * s
        }
        let rms = sqrt(sumSquares / Float(floats.count))

        if rms >= voiceRmsThreshold {
            lastSpeechTime = Date()
            hasVoiceActivity = true
        }

        if hasVoiceActivity || !accumulatedSamples.isEmpty {
            accumulatedSamples.append(contentsOf: floats)
            // Hard limit: if continuous non-stop talking reaches 5s, commit chunk immediately
            if accumulatedSamples.count >= maxContinuousSamples {
                commitAndTranscribeLocked()
            }
        }
    }

    private func startSilenceWatcher() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.lock.lock()
            guard self.isRunning, self.hasVoiceActivity else {
                self.lock.unlock()
                return
            }
            let elapsedSilence = Date().timeIntervalSince(self.lastSpeechTime)
            let sampleCount = self.accumulatedSamples.count

            // 1. Natural sentence ending: >= 450ms silence and >= 300ms valid speech
            if elapsedSilence >= self.silenceThreshold && sampleCount >= self.minSpeechSamples {
                self.commitAndTranscribeLocked()
            }
            // 2. Continuous speech slicing: buffer >= 3s and minor pause >= 250ms
            else if sampleCount >= self.targetSegmentSamples && elapsedSilence >= self.shortPauseThreshold {
                self.commitAndTranscribeLocked()
            }
            // 3. Drop transient noise spike if silence exceeds 1.8s and speech too short
            else if elapsedSilence >= 1.8 && sampleCount < self.minSpeechSamples {
                self.accumulatedSamples.removeAll()
                self.hasVoiceActivity = false
            }
            self.lock.unlock()
        }
    }

    private func commitAndTranscribeLocked() {
        guard isRunning, !accumulatedSamples.isEmpty else { return }
        let chunk = accumulatedSamples
        accumulatedSamples.removeAll()
        hasVoiceActivity = false

        // Check average energy to silently drop floating noise
        var sumSq: Float = 0
        for s in chunk { sumSq += s * s }
        let chunkRms = sqrt(sumSq / Float(chunk.count))
        let minChunkRms: Float = (label == "Remote") ? 0.005 : 0.012
        guard chunkRms >= minChunkRms else { return }

        Task.detached(priority: .userInitiated) { [weak self, chunk, label = self.label] in
            do {
                let text = try await LocalSenseVoiceEngine.shared.transcribe(samples: chunk)
                if !text.isEmpty {
                    NSLog("[Transcriber-\(label)] 🎯 SenseVoice transcription result: '\(text)'")
                    self?.onCommitSentence?(text)
                }
            } catch {
                NSLog("[Transcriber-\(label)] Transcription error: \(error.localizedDescription)")
            }
        }
    }
}
