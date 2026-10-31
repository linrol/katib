import Foundation
import AVFoundation

/// Low-latency local microphone audio capture based on AVAudioEngine.
public final class LocalMicAudioEngine: @unchecked Sendable {
    public static let shared = LocalMicAudioEngine()

    private let audioEngine = AVAudioEngine()
    private let resampler = Mono16kResampler()
    private let processingQueue = DispatchQueue(label: "com.katib.local-mic-proc", qos: .userInteractive)
    public var onPCMSamples: (([Float]) -> Void)?
    public private(set) var isRunning: Bool = false
    private var packetCount: Int = 0
    private let lock = NSLock()

    private init() {
        // Automatically respond to audio hardware changes (e.g. AirPods connected/disconnected)
        NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: audioEngine,
            queue: nil
        ) { [weak self] _ in
            self?.restart()
        }
    }

    public func start() throws {
        lock.lock()
        defer { lock.unlock() }
        guard !isRunning else { return }
        packetCount = 0

        let inputNode = audioEngine.inputNode
        let bus: AVAudioNodeBus = 0
        let format = inputNode.outputFormat(forBus: bus)

        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw NSError(
                domain: "LocalMicAudioEngine",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to obtain valid microphone hardware format"]
            )
        }

        NSLog("[LocalMicAudioEngine] Microphone hardware format: \(format.sampleRate)Hz, \(format.channelCount) channels")

        inputNode.removeTap(onBus: bus)
        inputNode.installTap(onBus: bus, bufferSize: 1024, format: format) { [weak self] (buffer, _) in
            self?.handlePCMBuffer(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        self.isRunning = true
        NSLog("[LocalMicAudioEngine] 🚀 Local microphone AVAudioEngine capture started!")
    }

    public func stop() {
        lock.lock()
        defer { lock.unlock() }
        guard isRunning else { return }
        isRunning = false

        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        NSLog("[LocalMicAudioEngine] Local microphone capture stopped")
    }

    public func restart() {
        lock.lock()
        defer { lock.unlock() }
        guard isRunning else { return }

        NSLog("[LocalMicAudioEngine] 🔄 Audio route configuration changed, restarting AVAudioEngine...")
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        audioEngine.reset()

        do {
            let inputNode = audioEngine.inputNode
            let bus: AVAudioNodeBus = 0
            let format = inputNode.outputFormat(forBus: bus)
            guard format.sampleRate > 0, format.channelCount > 0 else { return }

            inputNode.installTap(onBus: bus, bufferSize: 1024, format: format) { [weak self] (buffer, _) in
                self?.handlePCMBuffer(buffer)
            }
            audioEngine.prepare()
            try audioEngine.start()
            NSLog("[LocalMicAudioEngine] 🚀 AVAudioEngine restarted successfully!")
        } catch {
            NSLog("[LocalMicAudioEngine] ❌ Failed to restart AVAudioEngine: \(error.localizedDescription)")
        }
    }

    private func handlePCMBuffer(_ buffer: AVAudioPCMBuffer) {
        guard isRunning else { return }
        guard let floatChannelData = buffer.floatChannelData else { return }

        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return }

        let channels = Int(buffer.format.channelCount)
        let sampleRate = buffer.format.sampleRate
        var monoSamples: [Float] = []

        if channels == 1 {
            monoSamples = Array(UnsafeBufferPointer(start: floatChannelData[0], count: frameLength))
        } else if channels >= 2 {
            let leftPtr = floatChannelData[0]
            let rightPtr = floatChannelData[1]
            monoSamples = (0..<frameLength).map { (leftPtr[$0] + rightPtr[$0]) * 0.5 }
        }

        guard !monoSamples.isEmpty else { return }

        processingQueue.async { [weak self] in
            guard let self = self, self.isRunning else { return }

            self.packetCount += 1
            if self.packetCount % 50 == 0 {
                let sampleCount = min(monoSamples.count, 160)
                if sampleCount > 0 {
                    let sumSquares = monoSamples[0..<sampleCount].reduce(Float(0)) { $0 + $1 * $1 }
                    let rms = sqrt(sumSquares / Float(sampleCount))
                    if rms > 0.005 {
                        NSLog("[LocalMicAudioEngine] 🎤 Received microphone audio signal (RMS: %.4f, samples: %d)", rms, monoSamples.count)
                    }
                }
            }

            if let resampledFloats = self.resampler.resample(floats: monoSamples, sampleRate: sampleRate) {
                self.onPCMSamples?(resampledFloats)
            }
        }
    }
}
