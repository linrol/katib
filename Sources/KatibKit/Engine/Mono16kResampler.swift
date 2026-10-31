import Foundation
import AVFoundation

/// High-performance audio resampler that converts any input sample rate & channels to 16000Hz Mono Float32.
public final class Mono16kResampler: @unchecked Sendable {
    public let targetFormat = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
    private var converter: AVAudioConverter?
    private var currentSampleRate: Double = 0

    public init() {}

    public func resample(floats: [Float], sampleRate: Double) -> [Float]? {
        guard !floats.isEmpty, sampleRate > 0 else { return nil }
        if sampleRate == 16000 {
            return floats
        }

        if converter == nil || currentSampleRate != sampleRate {
            guard let monoSource = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { return nil }
            self.currentSampleRate = sampleRate
            self.converter = AVAudioConverter(from: monoSource, to: targetFormat)
        }
        guard let conv = converter else { return nil }

        let monoSource = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        guard let inBuffer = AVAudioPCMBuffer(pcmFormat: monoSource, frameCapacity: AVAudioFrameCount(floats.count)) else { return nil }
        inBuffer.frameLength = AVAudioFrameCount(floats.count)

        floats.withUnsafeBufferPointer { ptr in
            if let base = ptr.baseAddress {
                inBuffer.floatChannelData?[0].update(from: base, count: floats.count)
            }
        }

        let outCapacity = AVAudioFrameCount(Double(floats.count) * (16000.0 / sampleRate) + 64)
        guard let outBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outCapacity) else { return nil }

        var error: NSError?
        var hasSupplied = false
        conv.convert(to: outBuffer, error: &error) { _, outStatus in
            if !hasSupplied {
                hasSupplied = true
                outStatus.pointee = .haveData
                return inBuffer
            } else {
                outStatus.pointee = .noDataNow
                return nil
            }
        }

        if let error = error {
            NSLog("[Mono16kResampler] Conversion error: \(error.localizedDescription)")
            return nil
        }

        guard let channelData = outBuffer.floatChannelData?[0] else { return nil }
        return Array(UnsafeBufferPointer(start: channelData, count: Int(outBuffer.frameLength)))
    }
}
