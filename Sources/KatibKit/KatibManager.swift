import Foundation
import CoreGraphics
import FluidAudio

public enum KatibListenMode: String, CaseIterable, Identifiable, Codable {
    case remoteOnly = "remote"
    case localOnly = "local"
    case bidirectional = "both"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .remoteOnly:
            return "Remote Only"
        case .localOnly:
            return "Local Mic"
        case .bidirectional:
            return "Both"
        }
    }

    public var runningStatusText: String {
        switch self {
        case .remoteOnly:
            return "Listening to remote audio (ScreenCaptureKit)"
        case .localOnly:
            return "Listening to local microphone"
        case .bidirectional:
            return "Listening both sides (ScreenCaptureKit + Mic)"
        }
    }

    public var tipText: String {
        switch self {
        case .remoteOnly:
            return "Captures incoming meeting audio without using microphone"
        case .localOnly:
            return "Captures local microphone speech"
        case .bidirectional:
            return "Simultaneously captures and transcribes both participants"
        }
    }
}

public struct KatibSentence: Identifiable, Equatable {
    public let id = UUID()
    public let source: KatibSentenceSource
    public let text: String
    public let timestamp: Date

    public init(source: KatibSentenceSource, text: String, timestamp: Date = Date()) {
        self.source = source
        self.text = text
        self.timestamp = timestamp
    }
}

public enum KatibSentenceSource: String {
    case remote = "Remote"
    case local = "Local"

    public var icon: String {
        switch self {
        case .remote: return "speaker.wave.2.fill"
        case .local: return "mic.fill"
        }
    }
}

/// Unified High-level Controller for Katib Speech Transcription.
@MainActor
public final class KatibManager: ObservableObject {
    public static let shared = KatibManager()

    @Published public private(set) var isRunning: Bool = false
    @Published public var listenMode: KatibListenMode = .bidirectional {
        didSet {
            UserDefaults.standard.set(listenMode.rawValue, forKey: "katib.listenMode")
        }
    }
    @Published public var errorMessage: String? = nil
    @Published public var recentSentences: [KatibSentence] = []

    /// Callback fired whenever a new sentence is transcribed (sentence, isRemote)
    public var onSentence: ((KatibSentence) -> Void)?
    public var onLog: ((String, Bool) -> Void)? // message, isError

    private var remoteTranscriber: AudioStreamTranscriber?
    private var localTranscriber: AudioStreamTranscriber?

    private init() {
        if let savedMode = UserDefaults.standard.string(forKey: "katib.listenMode"),
           let mode = KatibListenMode(rawValue: savedMode) {
            self.listenMode = mode
        }
    }

    public func toggleCapture() {
        if isRunning {
            stopCapture()
        } else {
            startCapture()
        }
    }

    public func startCapture() {
        guard !isRunning else { return }
        errorMessage = nil

        onLog?("Initializing SenseVoice local neural engine...", false)

        Task {
            do {
                try await LocalSenseVoiceEngine.shared.initializeIfNeeded()

                let shouldCaptureRemote = (self.listenMode == .remoteOnly || self.listenMode == .bidirectional)
                let shouldCaptureLocal = (self.listenMode == .localOnly || self.listenMode == .bidirectional)

                if shouldCaptureRemote {
                    if !CGPreflightScreenCaptureAccess() {
                        onLog?("Requesting Screen & Audio Recording permission...", false)
                        _ = CGRequestScreenCaptureAccess()
                    }

                    let remoteTrans = AudioStreamTranscriber(label: "Remote", rmsThreshold: 0.008)
                    remoteTrans.onCommitSentence = { [weak self] text in
                        Task { @MainActor in
                            let sentence = KatibSentence(source: .remote, text: text)
                            self?.handleNewSentence(sentence)
                        }
                    }
                    try remoteTrans.start()
                    self.remoteTranscriber = remoteTrans

                    RemoteScreenCaptureEngine.shared.onPCMSamples = { [weak remoteTrans] samples in
                        remoteTrans?.appendAudioSamples(samples)
                    }
                    try await RemoteScreenCaptureEngine.shared.start()
                }

                if shouldCaptureLocal {
                    do {
                        let localTrans = AudioStreamTranscriber(label: "Local", rmsThreshold: 0.016)
                        localTrans.onCommitSentence = { [weak self] text in
                            Task { @MainActor in
                                let sentence = KatibSentence(source: .local, text: text)
                                self?.handleNewSentence(sentence)
                            }
                        }
                        try localTrans.start()
                        self.localTranscriber = localTrans

                        LocalMicAudioEngine.shared.onPCMSamples = { [weak localTrans] samples in
                            localTrans?.appendAudioSamples(samples)
                        }
                        try LocalMicAudioEngine.shared.start()
                    } catch {
                        NSLog("[KatibManager] Local microphone start skipped: \(error.localizedDescription)")
                        if self.listenMode == .localOnly {
                            throw error
                        }
                    }
                }

                self.isRunning = true
                onLog?("🚀 Katib SenseVoice audio monitor started (\(self.listenMode.title))", false)
            } catch {
                let err = "Failed to start: \(error.localizedDescription)"
                self.errorMessage = err
                self.onLog?(err, true)
                self.stopCapture()
            }
        }
    }

    public func stopCapture() {
        RemoteScreenCaptureEngine.shared.stop()
        RemoteScreenCaptureEngine.shared.onPCMSamples = nil
        remoteTranscriber?.stop()
        remoteTranscriber = nil

        LocalMicAudioEngine.shared.stop()
        LocalMicAudioEngine.shared.onPCMSamples = nil
        localTranscriber?.stop()
        localTranscriber = nil

        isRunning = false
        onLog?("Katib audio capture stopped", false)
    }

    private func handleNewSentence(_ sentence: KatibSentence) {
        recentSentences.append(sentence)
        if recentSentences.count > 100 {
            recentSentences.removeFirst(recentSentences.count - 100)
        }
        onSentence?(sentence)
        onLog?("[\(sentence.source.rawValue)]: \(sentence.text)", false)
    }
}
