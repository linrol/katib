import Foundation
import CoreGraphics
import ScreenCaptureKit
import AVFoundation

/// Zero-virtual-audio-device system audio capture engine based on ScreenCaptureKit.
public final class RemoteScreenCaptureEngine: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    public static let shared = RemoteScreenCaptureEngine()

    private var stream: SCStream?
    private let resampler = Mono16kResampler()
    private let processingQueue = DispatchQueue(label: "com.katib.screen-audio-proc", qos: .userInteractive)
    public var onPCMSamples: (([Float]) -> Void)?
    public private(set) var isRunning: Bool = false
    private var packetCount: Int = 0

    private override init() {
        super.init()
    }

    public func start() async throws {
        guard !isRunning else { return }
        packetCount = 0

        // 1. ScreenCaptureKit permission check
        if !CGPreflightScreenCaptureAccess() {
            let requested = CGRequestScreenCaptureAccess()
            if !requested {
                throw NSError(
                    domain: "RemoteScreenCaptureEngine",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Screen & System Audio Recording permission is required. Please grant permission in System Settings -> Privacy & Security -> Screen & System Audio Recording."]
                )
            }
        }

        // 2. Fetch shareable displays
        let shareableContent = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false)
        guard let display = shareableContent.displays.first else {
            throw NSError(
                domain: "RemoteScreenCaptureEngine",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "No active display found to attach audio stream."]
            )
        }

        // 3. Content filter: capture full display audio, exclude self process to avoid audio loop
        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])

        // 4. Stream configuration for audio-only
        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = true
        config.sampleRate = 48000
        config.channelCount = 1

        // Minimal video footprint (0% GPU/CPU overhead)
        config.width = 2
        config.height = 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale.max)
        config.showsCursor = false
        config.queueDepth = 3

        // 5. Initialize and start stream
        let newStream = SCStream(filter: filter, configuration: config, delegate: self)
        try newStream.addStreamOutput(self, type: .audio, sampleHandlerQueue: processingQueue)
        try await newStream.startCapture()

        self.stream = newStream
        self.isRunning = true
        NSLog("[RemoteScreenCaptureEngine] 🚀 ScreenCaptureKit system audio capture started (48kHz Mono, excludes self)")
    }

    public func stop() {
        guard isRunning || stream != nil else { return }
        isRunning = false
        let s = self.stream
        self.stream = nil
        if let s = s {
            Task {
                try? await s.stopCapture()
            }
        }
        NSLog("[RemoteScreenCaptureEngine] ScreenCaptureKit system audio capture stopped")
    }

    // MARK: - SCStreamOutput Conformance
    public nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
        guard outputType == .audio, CMSampleBufferIsValid(sampleBuffer), self.isRunning else { return }

        guard let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer),
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc)?.pointee else {
            return
        }

        let sampleRate = asbd.mSampleRate
        var descCopy = asbd
        guard let audioFormat = AVAudioFormat(streamDescription: &descCopy) else { return }

        var monoSamples: [Float] = []

        do {
            try sampleBuffer.withAudioBufferList { audioBufferList, _ in
                guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, bufferListNoCopy: audioBufferList.unsafePointer) else {
                    return
                }

                let frameCount = Int(pcmBuffer.frameLength)
                guard frameCount > 0 else { return }

                if let floatChannelData = pcmBuffer.floatChannelData {
                    let channels = Int(pcmBuffer.format.channelCount)
                    if channels == 1 {
                        let ptr = floatChannelData[0]
                        monoSamples = Array(UnsafeBufferPointer(start: ptr, count: frameCount))
                    } else if channels >= 2 {
                        let leftPtr = floatChannelData[0]
                        let rightPtr = floatChannelData[1]
                        monoSamples = (0..<frameCount).map { (leftPtr[$0] + rightPtr[$0]) * 0.5 }
                    }
                } else if let int16ChannelData = pcmBuffer.int16ChannelData {
                    let channels = Int(pcmBuffer.format.channelCount)
                    if channels == 1 {
                        let ptr = int16ChannelData[0]
                        monoSamples = (0..<frameCount).map { Float(ptr[$0]) / 32768.0 }
                    } else if channels >= 2 {
                        let leftPtr = int16ChannelData[0]
                        let rightPtr = int16ChannelData[1]
                        monoSamples = (0..<frameCount).map { (Float(leftPtr[$0]) + Float(rightPtr[$0])) * (0.5 / 32768.0) }
                    }
                }
            }
        } catch {
            return
        }

        guard !monoSamples.isEmpty else { return }

        self.packetCount += 1
        if self.packetCount % 50 == 0 {
            let sampleCount = min(monoSamples.count, 160)
            if sampleCount > 0 {
                let sumSquares = monoSamples[0..<sampleCount].reduce(Float(0)) { $0 + $1 * $1 }
                let rms = sqrt(sumSquares / Float(sampleCount))
                if rms > 0.003 {
                    NSLog("[RemoteScreenCaptureEngine] 🔊 Received remote audio signal (RMS: %.4f, samples: %d)", rms, monoSamples.count)
                }
            }
        }

        if let resampledFloats = self.resampler.resample(floats: monoSamples, sampleRate: sampleRate) {
            self.onPCMSamples?(resampledFloats)
        }
    }

    public nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        NSLog("[RemoteScreenCaptureEngine] ❌ Stream stopped with error: \(error.localizedDescription)")
    }
}
