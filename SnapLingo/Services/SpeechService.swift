//
//  SpeechService.swift
//  SnapLingo
//

import AVFoundation

/// 单词发音（系统语音，支持选择口音）
@Observable
final class SpeechService: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = SpeechService()

    @ObservationIgnored private nonisolated(unsafe) let synthesizer = AVSpeechSynthesizer()
    private(set) var speakingText: String?
    var accent: SpeechAccent = .regionDefault

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String, slow: Bool = false) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }

        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = AVSpeechSynthesisVoice(language: accent.rawValue) ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = slow ? 0.35 : 0.46
        speakingText = trimmed
        synthesizer.speak(utterance)
    }

    func isSpeaking(_ text: String) -> Bool {
        speakingText == text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.speakingText = nil }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.speakingText = nil }
    }
}
