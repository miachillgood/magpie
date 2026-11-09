//
//  WatchSpeech.swift
//  MagpieWatch
//
//  手表上的发音：口音跟手机设置走（快照里带过来）
//

import AVFoundation

enum WatchSpeech {
    private static let synthesizer = AVSpeechSynthesizer()

    static func speak(_ text: String, accent: String = WatchStore.shared.snapshot?.accent ?? "en-US") {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: accent)
        utterance.rate = 0.46
        synthesizer.stopSpeaking(at: .immediate)
        synthesizer.speak(utterance)
    }
}
