//
//  OnboardingView.swift
//  SnapLingo
//

import SwiftUI
import SwiftData

/// 首次启动：欢迎 → 水平自测 → 每日节奏 → 提醒
struct OnboardingView: View {
    @Bindable var settings: UserSettings
    @Environment(\.modelContext) private var context
    @State private var step: Step = .welcome

    private enum Step: Int, CaseIterable {
        case welcome, level, pace, reminder
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground()
                Group {
                    switch step {
                    case .welcome:
                        WelcomeStep { go(.level) }
                    case .level:
                        LevelTestView(onSkip: { go(.pace) }) { score in
                            settings.levelScore = score
                            settings.assessmentCompleted = true
                            go(.pace)
                        }
                    case .pace:
                        PaceStep(selection: $settings.newWordsPerDay) { go(.reminder) }
                    case .reminder:
                        ReminderStep(settings: settings) { finish() }
                    }
                }
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
            }
        }
    }

    private func go(_ next: Step) {
        try? context.save()
        withAnimation(.smooth) { step = next }
    }

    private func finish() {
        settings.onboardingCompleted = true
        try? context.save()
        StudyReminder.refresh(context: context)
    }
}

// MARK: - 欢迎

private struct WelcomeStep: View {
    var onContinue: () -> Void
    @State private var appeared = false

    var body: some View {
        ZStack(alignment: .top) {
            MeshBackdrop()
                .frame(height: 560)
                .mask(LinearGradient(colors: [.black, .black, .clear], startPoint: .top, endPoint: .bottom))
                .ignoresSafeArea(edges: .top)

            VStack(spacing: 0) {
                StickerCollage()
                    .frame(height: 300)
                    .padding(.top, 70)
                    .scaleEffect(appeared ? 1 : 0.85)
                    .opacity(appeared ? 1 : 0)

                Spacer(minLength: Spacing.lg)

                VStack(spacing: Spacing.sm) {
                    Text("See it. Snap it.\nLearn it.")
                        .font(.system(size: 40, weight: .bold, design: .serif))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Theme.ink)
                    Text("拍下身边的英文，按你的水平挑词，\n每天几分钟，把它们变成你的词汇。")
                        .font(.body.weight(.medium))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .offset(y: appeared ? 0 : 20)
                .opacity(appeared ? 1 : 0)

                HStack(spacing: Spacing.xs) {
                    Pill(text: "拍照识词", emoji: "📸", style: .tinted(Pastel.peach))
                    Pill(text: "按水平推荐", emoji: "✨", style: .tinted(Pastel.lavender))
                    Pill(text: "每日计划", emoji: "⏰", style: .tinted(Pastel.mint))
                }
                .padding(.top, Spacing.lg)
                .opacity(appeared ? 1 : 0)

                Spacer(minLength: Spacing.lg)

                PrimaryButton(title: "开始", trailingSymbol: "arrow.right", action: onContinue)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.md)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.75)) { appeared = true }
        }
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
    var title: String
    var hour: Int
    var minute: Int
    var color: Color

    var id: String { title }
    var timeText: String { String(format: "%02d:%02d", hour, minute) }

    static let all = [
        ReminderPreset(emoji: "🌅", title: "早上", hour: 8, minute: 0, color: Pastel.peach),
        ReminderPreset(emoji: "🥪", title: "午休", hour: 12, minute: 30, color: Pastel.butter),
        ReminderPreset(emoji: "🚌", title: "下班路上", hour: 18, minute: 0, color: Pastel.mint),
        ReminderPreset(emoji: "🌙", title: "睡前", hour: 21, minute: 30, color: Pastel.lavender)
    ]
}
