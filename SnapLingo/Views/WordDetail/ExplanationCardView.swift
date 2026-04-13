//
//  ExplanationCardView.swift
//  SnapLingo
//

import SwiftUI
import AVFoundation

struct ExplanationCardView: View {
    let word: String
    let scene: SceneTag
    let explanation: WordExplanation?
    let isLoading: Bool
    let isSaved: Bool
    let onSave: () -> Void

    @State private var isSpeaking = false
    private let synthesizer = AVSpeechSynthesizer()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // MARK: 词汇标题区
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(word)
                            .font(.system(size: 36, weight: .bold))

                        // 朗读按钮
                        Button {
                            speak(word)
                        } label: {
                            Image(systemName: isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2")
                                .font(.title3)
                                .foregroundStyle(isSpeaking ? Color.accentColor : Color.secondary)
                                .symbolEffect(.variableColor, isActive: isSpeaking)
                        }
                        .buttonStyle(.plain)

                        Spacer()
                        Label(scene.rawValue, systemImage: scene.icon)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.tint.opacity(0.12), in: Capsule())
                            .foregroundStyle(.tint)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 20)

                Divider()

                // MARK: 内容区
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("AI 正在生成解释…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)

                } else if let exp = explanation {

                    VStack(alignment: .leading, spacing: 24) {

                        // 中文释义
                        InfoBlock(
                            icon: "character.book.closed.zh",
                            title: "中文释义",
                            content: exp.chineseExplanation,
                            contentFont: .title3.weight(.medium)
                        )

                        // 英文例句（带朗读）
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label("例句", systemImage: "quote.bubble")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.accentColor)
                                Spacer()
                                Button {
                                    speak(exp.exampleSentence)
                                } label: {
                                    Image(systemName: "speaker.wave.2")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            Text(exp.exampleSentence)
                                .font(.body)
                                .foregroundStyle(.primary)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.accentColor.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))

                        // 例句翻译
                        InfoBlock(
                            icon: "arrow.2.squarepath",
                            title: "例句翻译",
                            content: exp.exampleSentenceChinese,
                            contentFont: .body
                        )

                        // 场景说明（有内容时才显示）
                        if !exp.sceneNote.isEmpty {
                            InfoBlock(
                                icon: "lightbulb",
                                title: "场景说明",
                                content: exp.sceneNote,
                                contentFont: .subheadline,
                                tint: .orange
                            )
                        }
                    }
                    .padding(20)

                } else {
                    // 加载失败
                    ContentUnavailableView(
                        "加载失败",
                        systemImage: "exclamationmark.triangle",
                        description: Text("请检查网络或 API Key")
                    )
                    .padding(.vertical, 40)
                }

                Spacer(minLength: 100)
            }
        }
        .safeAreaInset(edge: .bottom) {
            saveButton
        }
    }

    func speakWord() {
        speak(word)
    }

    // MARK: - 朗读

    private func speak(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.45
        isSpeaking = true
        synthesizer.speak(utterance)
        // 朗读结束后重置状态（粗略估算时长）
        let duration = Double(text.count) * 0.08 + 0.5
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            isSpeaking = false
        }
    }

    private var saveButton: some View {
        Button(action: onSave) {
            Label(
                isSaved ? "已保存到词库" : "保存到词库",
                systemImage: isSaved ? "checkmark.circle.fill" : "plus.circle.fill"
            )
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(isSaved ? Color.green : Color.accentColor)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .disabled(isSaved || isLoading)
        .background(.regularMaterial)
        .animation(.easeInOut(duration: 0.2), value: isSaved)
    }
}

// MARK: - InfoBlock 子组件

private struct InfoBlock: View {
    let icon: String
    let title: String
    let content: String
    var contentFont: Font = .body
    var tint: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
            Text(content)
                .font(contentFont)
                .foregroundStyle(.primary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }
}
