import Foundation
import FluidAudio

/// On-device CoreML SenseVoice Neural Inference Engine (Apple Neural Engine accelerated).
public actor LocalSenseVoiceEngine {
    public static let shared = LocalSenseVoiceEngine()
    private var manager: SenseVoiceManager?
    private var isInitializing = false
    private var hasWarmedUp = false

    public func initializeIfNeeded(progressHandler: ProgressHandler? = nil) async throws {
        if manager != nil { return }
        while isInitializing {
            try await Task.sleep(nanoseconds: 50_000_000)
            if manager != nil { return }
        }
        isInitializing = true
        defer { isInitializing = false }

        NSLog("[LocalSenseVoiceEngine] Loading SenseVoice CoreML model...")
        let mgr = try await SenseVoiceManager.load(precision: .int8, progressHandler: progressHandler)
        self.manager = mgr
        NSLog("[LocalSenseVoiceEngine] 🚀 SenseVoice local neural engine loaded successfully!")

        // Warm up Apple Neural Engine (ANE) with silent audio
        if !hasWarmedUp {
            NSLog("[LocalSenseVoiceEngine] Warming up Neural Engine (ANE) with silent buffer...")
            let silence = [Float](repeating: 0, count: 16_000)
            _ = try? await mgr.transcribe(audio: silence)
            hasWarmedUp = true
            NSLog("[LocalSenseVoiceEngine] ⚡️ ANE Warmup complete! Next inferences will be instant.")
        }
    }

    public func transcribe(samples: [Float]) async throws -> String {
        guard let manager = manager else { return "" }
        guard samples.count >= 4800 else { return "" } // Minimum 300ms audio
        let result = try await manager.transcribeDetailed(audio: samples)

        // 1. Drop if classified as nospeech/silence
        if result.language == "nospeech" || result.tags.contains("nospeech") {
            return ""
        }

        let cleanText = result.text.trimmingCharacters(in: .whitespacesAndNewlines)

        // 2. Filter out known silence/hallucinated single-letter noise tokens
        let lower = cleanText.lowercased()
        let noiseTokens: Set<String> = ["i", "y", "a", "u", "e", "o", "uh", "um", "ah", "eh", "er", "mm", "hmm"]
        if noiseTokens.contains(lower) {
            return ""
        }

        // 3. Filter out short random symbols
        let hasChinese = cleanText.contains { $0.unicodeScalars.contains { (0x4E00...0x9FA5).contains($0.value) } }
        let allowedShortWords: Set<String> = ["ok", "hi", "no", "we", "he", "me", "go", "up", "in", "on"]
        if !hasChinese && cleanText.count <= 2 && !allowedShortWords.contains(lower) {
            return ""
        }

        return TranscriptionEngineArtifactsFilter.filter(cleanText)
    }
}

/// Filter control tags and bracketed non-speech tokens.
public struct TranscriptionEngineArtifactsFilter {
    private static let artifactPatterns: [String] = [
        #"<\|[^|<>]*\|>"#,
        #"(?i)\[\s*(?:blank[_\s-]*audio|no[_\s-]*speech|silence|inaudible|music|applause|laughter|screaming|cheering)\s*\]"#,
        #"(?i)\(\s*(?:blank[_\s-]*audio|no[_\s-]*speech|silence|inaudible|music|applause|laughter)\s*\)"#,
        #"(?i)<\s*(?:eou|eob|unk|blank|pad)\s*>"#
    ]

    private static let fillerTokens: Set<String> = [
        "uh", "um", "uhh", "umm", "err", "ah", "ahh", "hmm", "hm", "mm", "mmm"
    ]

    public static func filter(_ text: String) -> String {
        guard !text.isEmpty else { return "" }
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. Remove control tags and bracketed non-speech annotations
        for pattern in artifactPatterns {
            result = result.replacingOccurrences(of: pattern, with: " ", options: .regularExpression)
        }

        // 2. Collapse redundant spaces
        result = result.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // 3. Drop isolated filler tokens
        let lower = result.lowercased()
        if fillerTokens.contains(lower) {
            return ""
        }

        // 4. Drop if only punctuation characters left
        let strippedPunct = result.trimmingCharacters(in: .punctuationCharacters.union(.whitespacesAndNewlines))
        if strippedPunct.isEmpty {
            return ""
        }

        return result
    }
}
