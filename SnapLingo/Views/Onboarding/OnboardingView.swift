//
//  OnboardingView.swift
//  SnapLingo
//

import SwiftUI
import SwiftData

/// 首次启动：欢迎 →（登录）→ 水平小测 → 母语 → AI 说明 → 每日节奏 → 提醒（顺序见 OnboardingFlow）
struct OnboardingView: View {
    @Bindable var settings: UserSettings
    @Environment(\.modelContext) private var context
    @State private var step: OnboardingStep = {
        #if DEBUG
        OnboardingDebug.initialStep
        #else
        .welcome
        #endif
    }()

    private let accountsEnabled = AccountFeatures.isEnabled

    var body: some View {
        NavigationStack {
            ZStack {
                OnboardingBackground()
                Group {
                    switch step {
                    case .welcome:
                        WelcomeStep { advance() }
                    case .login:
                        loginStep
                    case .level:
                        LevelTestView(onSkip: { advance() }) { score in
                            settings.levelScore = score
                            settings.assessmentCompleted = true
                            advance()
                        }
                    case .language:
                        LanguageStep(selection: $settings.nativeLanguage) { advance() }
                    case .ai:
                        AIConsentView {
                            AIConsent.grant(context: context)
                            advance()
                        } onDecline: {
                            AIConsent.decline()
                            advance()
                        }
                    case .pace:
                        PaceStep(selection: $settings.newWordsPerDay) { advance() }
                    case .reminder:
                        ReminderStep(settings: settings) { finish() }
                    }
                }
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
            }
            .toolbarVisibility(.hidden, for: .navigationBar)
        }
    }

    /// 账号服务上线前（阶段 D）只在调试预览里出现，用假的验证码服务
    @ViewBuilder
    private var loginStep: some View {
        #if DEBUG
        LoginFlowView(actions: .preview, onApple: { result in
            if case .signedIn = AppleAccount.handle(result, settings: settings, context: context) { advance() }
        }, onDone: { advance() })
        #else
        Color.clear.onAppear { advance() }
        #endif
    }

    private func advance() {
        guard let next = OnboardingFlow.next(after: step, accountsEnabled: accountsEnabled) else {
            finish()
            return
        }
        try? context.save()
        withAnimation(.smooth) { step = next }
    }

    private func finish() {
        settings.onboardingCompleted = true
        try? context.save()
        StudyReminder.refresh(context: context)
    }
}

/// 引导页的底：上面暖沙斑点（和欢迎页同一个颜色），往下过渡成浅灰
struct OnboardingBackground: View {
    var body: some View {
        Theme.mist
            .overlay(alignment: .top) { ThemeWash(height: 640, theme: .sand) }
            .ignoresSafeArea()
    }
}

// MARK: - 母语

private struct LanguageStep: View {
    @Binding var selection: NativeLanguage
    var onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("你的母语是？")
                    .font(.display)
                Text("单词的释义和例句翻译会用这种语言。随时可以在“我的”里改。")
                    .foregroundStyle(.secondary)
            }
            .padding(.top, Spacing.xl)

            ScrollView {
                VStack(spacing: Spacing.xs + 2) {
                    ForEach(NativeLanguage.allCases) { language in
                        let isOn = selection == language
                        Button {
                            withAnimation(.snappy) { selection = language }
                        } label: {
                            HStack(spacing: Spacing.md) {
                                Text(verbatim: language.endonym)
                                    .font(.headline.weight(.heavy))
                                Spacer()
                                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                                    .font(.title2)
                                    .foregroundStyle(isOn ? Theme.ink : Theme.ink.opacity(0.2))
                                    .contentTransition(.symbolEffect(.replace))
                            }
                            .padding(.horizontal, Spacing.md)
                            .frame(height: 58)
                            .background(Theme.card, in: .rect(cornerRadius: Radius.card - 4, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: Radius.card - 4, style: .continuous)
                                    .strokeBorder(isOn ? Theme.ink : .clear, lineWidth: 2.5)
                            )
                        }
                        .buttonStyle(.pressable)
                        .foregroundStyle(Theme.ink)
                    }
                }
                .padding(2)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            .sensoryFeedback(.selection, trigger: selection)

            PrimaryButton(title: "继续", trailingSymbol: "arrow.right", action: onContinue)
        }
        .padding(Spacing.lg)
    }
}

// MARK: - 节奏

private struct PaceStep: View {
    @Binding var selection: Int
    var onContinue: () -> Void

    private func color(for pace: StudyPace) -> Color {
        switch pace {
        case .relaxed:  Pastel.mint
        case .standard: Pastel.butter
        case .intense:  Pastel.peach
        }
    }

    private func emoji(for pace: StudyPace) -> String {
        switch pace {
        case .relaxed:  "🐢"
        case .standard: "🚶"
        case .intense:  "🐇"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("每天学多少？")
                    .font(.display)
                Text("随时可以在“我的”里调整，到期的复习会优先安排。")
                    .foregroundStyle(.secondary)
            }
            .padding(.top, Spacing.xl)

            VStack(spacing: Spacing.sm) {
                ForEach(StudyPace.allCases) { pace in
                    let isOn = selection == pace.rawValue
                    Button {
                        withAnimation(.snappy) { selection = pace.rawValue }
                    } label: {
                        HStack(spacing: Spacing.md) {
                            EmojiTile(emoji: emoji(for: pace), color: color(for: pace), size: 56)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(pace.title).font(.headline.weight(.heavy))
                                Text(pace.detail).font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                                .font(.title2)
                                .foregroundStyle(isOn ? Theme.ink : Theme.ink.opacity(0.2))
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .card(padding: Spacing.sm + 2)
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                                .strokeBorder(isOn ? Theme.ink : .clear, lineWidth: 2.5)
                        )
                    }
                    .buttonStyle(.pressable)
                    .foregroundStyle(Theme.ink)
                }
            }
            .sensoryFeedback(.selection, trigger: selection)

            Spacer()
            PrimaryButton(title: "继续", trailingSymbol: "arrow.right", action: onContinue)
        }
        .padding(Spacing.lg)
    }
}

// MARK: - 提醒

private struct ReminderStep: View {
    @Bindable var settings: UserSettings
    var onFinish: () -> Void
    @State private var ring = 0

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            Text("🔔")
                .font(.system(size: 64))
                .frame(width: 140, height: 140)
                .background(Pastel.butter, in: .circle)
                .rotationEffect(.degrees(ring.isMultiple(of: 2) ? -8 : 8))
                .animation(.easeInOut(duration: 0.18).repeatCount(5, autoreverses: true), value: ring)
                .onAppear { ring += 1 }
            VStack(spacing: Spacing.xs) {
                Text("每天提醒你一次？")
                    .font(.display)
                Text("在你方便的时间提醒一下，坚持更容易。")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: Spacing.sm), GridItem(.flexible(), spacing: Spacing.sm)], spacing: Spacing.sm) {
                ForEach(ReminderPreset.all) { preset in
                    let isOn = settings.reminderHour == preset.hour && settings.reminderMinute == preset.minute
                    Button {
                        withAnimation(.snappy) {
                            settings.reminderHour = preset.hour
                            settings.reminderMinute = preset.minute
                        }
                    } label: {
                        HStack(spacing: Spacing.xs) {
                            Text(preset.emoji).font(.title2)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(preset.title).font(.subheadline.weight(.heavy))
                                Text(preset.timeText).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(Spacing.sm)
                        .background(preset.color, in: .rect(cornerRadius: Radius.card - 6, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.card - 6, style: .continuous)
                                .strokeBorder(isOn ? Theme.ink : .clear, lineWidth: 2.5)
                        )
                    }
                    .buttonStyle(.pressable)
                    .foregroundStyle(Theme.ink)
                }
            }
            .sensoryFeedback(.selection, trigger: settings.reminderHour)

            DatePicker("其他时间", selection: $settings.reminderTime, displayedComponents: .hourAndMinute)
                .datePickerStyle(.compact)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)
                .background(Theme.card, in: .capsule)
                .frame(maxWidth: 240)
            Spacer()
            VStack(spacing: Spacing.sm) {
                PrimaryButton(title: "开启提醒", symbol: "bell.fill") {
                    Task {
                        settings.reminderEnabled = await NotificationService.requestAuthorization()
                        onFinish()
                    }
                }
                Button("以后再说") { onFinish() }
                    .font(.headline)
                    .foregroundStyle(Theme.ink.opacity(0.6))
                    .padding(.vertical, Spacing.xs)
            }
        }
        .padding(Spacing.lg)
    }
}

// MARK: - 提醒时间预设

private struct ReminderPreset: Identifiable {
    var emoji: String
    var title: LocalizedStringKey
    var hour: Int
    var minute: Int
    var color: Color

    var id: Int { hour * 60 + minute }
    /// 按地区显示时间：08:00 / 8:00 AM
    var timeText: String {
        let date = Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }

    static let all = [
        ReminderPreset(emoji: "🌅", title: "早上", hour: 8, minute: 0, color: Pastel.peach),
        ReminderPreset(emoji: "🥪", title: "午休", hour: 12, minute: 30, color: Pastel.butter),
        ReminderPreset(emoji: "🚌", title: "下班路上", hour: 18, minute: 0, color: Pastel.mint),
        ReminderPreset(emoji: "🌙", title: "睡前", hour: 21, minute: 30, color: Pastel.lavender)
    ]
}
