//
//  VoiceCaptureSheet.swift
//  SnapLingo
//
//  「说一说」：在词库右上角点麦克风打开的半屏面板。
//  - 念一个英文词（或问「燕麦英语怎么说」）→ 关掉面板，打开查词
//  - 说一段话（「明天要去看牙医」）→ 面板拉到全屏，AI 推荐这个场景的词，挑完保存成一个场景
//

import SwiftUI
import SwiftData

struct VoiceCaptureSheet: View {
    /// 听出来是查一个词：交给词库去打开查词面板
    var onLookup: (String) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var recorder = VoiceRecorder()
    @State private var stage: Stage = .listen
    @State private var detent: PresentationDetent = .medium
    @State private var showingConsent = false
    /// 等同意 AI 之后再接着处理的那段话
    @State private var pending: (english: String, native: String)?

    private enum Stage {
        case listen
        case thinking
        case picking(WordLibrary.VoiceDraft)
        case failed(String)
    }

    var body: some View {
        NavigationStack {
            Group {
                switch stage {
                case .picking(let draft):
                    WordPickerView(voice: draft) { restart() }
                default:
                    capture
                }
            }
        }
        .presentationDetents([.medium, .large], selection: $detent)
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        .presentationBackground(Theme.cream)
        .sheet(isPresented: $showingConsent) {
            AIConsentSheet {
                guard let pending else { return }
                self.pending = nil
                Task { await interpret(pending) }
            }
        }
        .task {
            #if DEBUG
            // 模拟器上没法真的说话：-voiceTranscript "明天去看牙医" 直接当成听到了这句
            if let index = ProcessInfo.processInfo.arguments.firstIndex(of: "-voiceTranscript"),
               ProcessInfo.processInfo.arguments.indices.contains(index + 1) {
                let text = ProcessInfo.processInfo.arguments[index + 1]
                await handle((english: text, native: text))
            }
            #endif
        }
        .onDisappear {
            let recorder = recorder
            Task { await recorder.cancel() }
        }
    }

    // MARK: - 录音界面

    private var isRecording: Bool { recorder.phase == .recording }

    private var capture: some View {
        VStack(spacing: Spacing.md) {
            VStack(spacing: 6) {
                Text("说一说")
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundStyle(Theme.homeInk)
                    .accessibilityAddTraits(.isHeader)
                Text("念一个英文词，或者说说你要去做什么")
                    .font(.subheadline)
                    .foregroundStyle(Theme.homeMuted)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, Spacing.xl)

            transcript
                .frame(maxWidth: .infinity, minHeight: 64)
                .padding(.horizontal, Spacing.lg)

            Spacer(minLength: 0)

            switch stage {
            case .thinking:
                VStack(spacing: Spacing.sm) {
                    ProgressView()
                    Text("正在挑这个场景用得上的词…")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.homeMuted)
                }
                .frame(height: 120)
            case .failed(let message):
                VStack(spacing: Spacing.sm) {
                    Text(verbatim: message)
                        .font(.subheadline)
                        .foregroundStyle(Theme.homeMuted)
                        .multilineTextAlignment(.center)
                    micButton
                }
            default:
                micButton
            }

            Text(hint)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.homeMuted)
                .padding(.bottom, Spacing.lg)
        }
        .padding(.horizontal, Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.cream.ignoresSafeArea())
        .sensoryFeedback(.start, trigger: isRecording) { _, new in new }
        .sensoryFeedback(.stop, trigger: isRecording) { old, _ in old }
    }

    @ViewBuilder
    private var transcript: some View {
        let primary = recorder.native.isEmpty ? recorder.english : recorder.native
        if primary.isEmpty {
            HStack(spacing: Spacing.xs) {
                example("oat milk")
                example(String(localized: "明天要去看牙医", comment: "Example of a situation to say into the voice input"))
            }
        } else {
            VStack(spacing: 4) {
                Text(verbatim: primary)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.homeInk)
                if !recorder.native.isEmpty, !recorder.english.isEmpty, recorder.english != recorder.native {
                    Text(verbatim: recorder.english)
                        .font(.subheadline)
                        .foregroundStyle(Theme.homeMuted)
                }
            }
            .multilineTextAlignment(.center)
            .lineLimit(3)
            .contentTransition(.opacity)
            .animation(.snappy, value: primary)
        }
    }

    private func example(_ text: String) -> some View {
        Text(verbatim: "“\(text)”")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Theme.homeInk.opacity(0.7))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Theme.sheet, in: .capsule)
    }

    private var micButton: some View {
        Button {
            Task { await toggle() }
        } label: {
            ZStack {
                Circle()
                    .fill(Theme.streakFill)
                    .frame(width: 120, height: 120)
                    .scaleEffect(isRecording && !reduceMotion ? 1 + CGFloat(recorder.level) * 0.35 : 0.85)
                    .opacity(isRecording ? 1 : 0)
                    .animation(.easeOut(duration: 0.12), value: recorder.level)
                Circle()
                    .fill(isRecording ? Theme.danger : Theme.homeInk)
                    .frame(width: 84, height: 84)
                Group {
                    if recorder.phase == .preparing || recorder.phase == .finishing {
                        ProgressView().tint(Theme.cream)
                    } else {
                        Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(Theme.cream)
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
            }
            .frame(width: 120, height: 120)
        }
        .buttonStyle(.pressable)
        .disabled(recorder.phase == .preparing || recorder.phase == .finishing)
        .accessibilityLabel(isRecording ? Text("说完了") : Text("开始说"))
    }

    private var hint: LocalizedStringKey {
        switch recorder.phase {
        case .preparing: "第一次用要下载语音模型，稍等一下"
        case .recording: "说完点一下"
        default: "识别在手机上完成，录音不会上传"
        }
    }

    // MARK: - 流程

    private func toggle() async {
        switch recorder.phase {
        case .idle:
            stage = .listen
            do {
                try await recorder.start(native: UserSettings.current(in: context).nativeLanguage)
            } catch {
                stage = .failed((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
            }
        case .recording:
            await handle(await recorder.stop())
        default:
            break
        }
    }

    private func handle(_ heard: (english: String, native: String)) async {
        guard !heard.english.isEmpty || !heard.native.isEmpty else {
            stage = .failed(String(localized: "没听清，再说一次？"))
            return
        }
        // 一个英文词就不用问 AI 了，直接查
        let english = heard.english.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        if WordLookupSheet.isLookupQuery(english), english.split(separator: " ").count == 1,
           heard.native.isEmpty || heard.native.trimmingCharacters(in: .punctuationCharacters).localizedCaseInsensitiveCompare(english) == .orderedSame {
            finish(lookup: english)
            return
        }
        switch AIConsent.state {
        case .granted:
            await interpret(heard)
        case .undecided:
            pending = heard
            showingConsent = true
        case .declined:
            if WordLookupSheet.isLookupQuery(english) {
                finish(lookup: english)
            } else {
                stage = .failed(ClaudeAPIError.aiDisabled.errorDescription ?? "")
            }
        }
    }

    private func interpret(_ heard: (english: String, native: String)) async {
        guard AIConsent.isGranted else {
            stage = .failed(ClaudeAPIError.aiDisabled.errorDescription ?? "")
            return
        }
        stage = .thinking
        let settings = UserSettings.current(in: context)
        do {
            let intent = try await ClaudeAPIService.shared.interpretSpeech(
                english: heard.english,
                native: heard.native,
                level: settings.level,
                language: settings.nativeLanguage
            )
            switch intent {
            case .word(let word):
                finish(lookup: word)
            case .scene(let extraction):
                let transcript = heard.native.isEmpty ? heard.english : heard.native
                withAnimation(.snappy) {
                    detent = .large
                    stage = .picking(WordLibrary.VoiceDraft(transcript: transcript, extraction: extraction))
                }
            case nil:
                stage = .failed(String(localized: "没听出要学什么，换个说法试试？"))
            }
        } catch {
            stage = .failed((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }

    private func finish(lookup word: String) {
        dismiss()
        onLookup(word)
    }

    private func restart() {
        withAnimation(.snappy) {
            stage = .listen
            detent = .medium
        }
    }
}
