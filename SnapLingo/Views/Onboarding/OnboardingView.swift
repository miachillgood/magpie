//
//  OnboardingView.swift
//  SnapLingo
//

import SwiftUI
import SwiftData

/// 首次启动：欢迎 →（登录）→ 自选水平 → 母语（顺序见 OnboardingFlow）
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
                        // 引导里只让用户自己选一档；想测可以去「我的」里做小测
                        LevelPickStep { level in
                            settings.levelScore = level.cefr.midScore
                            advance()
                        }
                    case .language:
                        LanguageStep(selection: $settings.nativeLanguage) { advance() }
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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    /// 效果图里选中那一行的黄色
    private static let selectedFill = Color(light: UIColor(hex: 0xF6E3A8), dark: UIColor(hex: 0x5A4A1E))

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, Spacing.lg)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(Array(NativeLanguage.allCases.enumerated()), id: \.element) { index, language in
                        row(language)
                            .modifier(Entrance(appeared: appeared, delay: 0.15 + 0.04 * Double(index), reduceMotion: reduceMotion))
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, 4)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            .sensoryFeedback(.selection, trigger: selection)

            PrimaryButton(title: "继续", trailingSymbol: "arrow.right", action: onContinue)
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.md)

            // 左下角探出头的喜鹊，贴着屏幕底边
            HStack {
                Image("HelperMagpie")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 76)
                    .offset(x: -Spacing.lg - 6)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 40)
                    .animation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.7).delay(0.6), value: appeared)
                    .accessibilityHidden(true)
                Spacer()
            }
            .padding(.leading, Spacing.lg)
            .padding(.top, 6)
        }
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            guard !appeared else { return }
            if reduceMotion {
                appeared = true
            } else {
                Task {
                    try? await Task.sleep(for: .milliseconds(80))
                    appeared = true
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("你的母语是？")
                .font(.system(size: 31, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.homeInk)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.trailing, 40)
                .overlay(alignment: .topTrailing) {
                    Image("TitleSparks")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30)
                        .offset(x: -40, y: -26)
                        .accessibilityHidden(true)
                }
            Text("我们会用它来解释单词，帮你学英语。")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(Theme.homeInk.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 190, alignment: .leading)
        }
        .frame(maxWidth: .infinity, minHeight: 170, alignment: .bottomLeading)
        .modifier(Entrance(appeared: appeared, delay: 0, reduceMotion: reduceMotion))
        .overlay(alignment: .bottomTrailing) {
            Image("LanguageMagpie")
                .resizable()
                .scaledToFit()
                .frame(width: 165)
                .offset(x: Spacing.sm, y: 6)
                .rotationEffect(.degrees(appeared ? 0 : 6), anchor: .bottom)
                .scaleEffect(appeared ? 1 : 0.85, anchor: .bottom)
                .opacity(appeared ? 1 : 0)
                .animation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.65).delay(0.1), value: appeared)
                .accessibilityHidden(true)
        }
        .padding(.top, Spacing.xl)
        .padding(.bottom, Spacing.lg)
    }

    private func row(_ language: NativeLanguage) -> some View {
        let isOn = selection == language
        return Button {
            withAnimation(.snappy) { selection = language }
        } label: {
            HStack(spacing: Spacing.md) {
                Text(verbatim: language.endonym)
                    .font(.system(.headline, design: .rounded, weight: .heavy))
                Spacer()
                Circle()
                    .strokeBorder(isOn ? Theme.homeInk : Theme.homeInk.opacity(0.25), lineWidth: isOn ? 7 : 1.5)
                    .background(Circle().fill(isOn ? Theme.card : .clear))
                    .frame(width: 26, height: 26)
            }
            .foregroundStyle(Theme.homeInk)
            .padding(.horizontal, 20)
            .frame(height: 50)
            .background(isOn ? Self.selectedFill : Theme.card, in: .capsule)
            .overlay(Capsule().strokeBorder(isOn ? Theme.homeInk : .clear, lineWidth: 2))
            .shadow(color: .black.opacity(isOn ? 0 : 0.04), radius: 6, y: 2)
        }
        .buttonStyle(.pressable)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
