//
//  OnboardingView.swift
//  SnapLingo
//

import SwiftUI
import SwiftData

/// 首次启动：欢迎 → 介绍 →（登录）→ 自选水平 → 母语（顺序见 OnboardingFlow）
struct OnboardingView: View {
    @Bindable var settings: UserSettings
    @Environment(\.modelContext) private var context
    /// 第一步（根页面）；之后每一步 push 进导航栈，左上角返回和边缘右滑都能回到上一步
    private let firstStep: OnboardingStep = {
        #if DEBUG
        OnboardingDebug.initialStep
        #else
        .welcome
        #endif
    }()
    @State private var path: [OnboardingStep] = []

    private let accountsEnabled = AccountFeatures.isEnabled

    var body: some View {
        NavigationStack(path: $path) {
            stepView(firstStep)
                .toolbarVisibility(.hidden, for: .navigationBar)
                .navigationDestination(for: OnboardingStep.self) { step in
                    stepView(step)
                }
        }
    }

    @ViewBuilder
    private func stepView(_ step: OnboardingStep) -> some View {
        ZStack {
            OnboardingBackground()
            switch step {
            case .welcome:
                WelcomeStep { advance(from: step) }
            case .intro:
                IntroStep { advance(from: step) }
            case .login:
                loginStep
            case .level:
                // 引导里只让用户自己选一档；想测可以去「我的」里做小测
                LevelPickStep { level in
                    settings.levelScore = level.cefr.midScore
                    advance(from: step)
                }
            case .language:
                LanguageStep(selection: $settings.nativeLanguage) { advance(from: step) }
            }
        }
        // 插画页没有标题，只留系统的返回按钮
        .navigationBarTitleDisplayMode(.inline)
    }

    /// 账号服务上线前（阶段 D）只在调试预览里出现，用假的验证码服务
    @ViewBuilder
    private var loginStep: some View {
        #if DEBUG
        LoginFlowView(actions: .preview, onApple: { result in
            if case .signedIn = AppleAccount.handle(result, settings: settings, context: context) { advance(from: .login) }
        }, onDone: { advance(from: .login) })
        #else
        Color.clear.onAppear { advance(from: .login) }
        #endif
    }

    private func advance(from step: OnboardingStep) {
        guard let next = OnboardingFlow.next(after: step, accountsEnabled: accountsEnabled) else {
            finish()
            return
        }
        try? context.save()
        path.append(next)
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
    /// 选的母语和界面语言不一样时，问要不要把界面也换过去
    @State private var askInterface: NativeLanguage?

    /// 设计稿里的蜡笔黄和比纸底深一点的米色（和选水平页一样）
    private static let selectedFill = Color(hex: 0xFCEFA0)
    private static let fill = Color(hex: 0xF5F0E3)

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let compact = proxy.size.height < 700
            VStack(spacing: 0) {
                header(width: width, compact: compact)

                ScrollView {
                    VStack(spacing: compact ? 7 : 10) {
                        ForEach(Array(NativeLanguage.allCases.enumerated()), id: \.element) { index, language in
                            row(language, compact: compact)
                                .modifier(Entrance(appeared: appeared, delay: 0.15 + 0.04 * Double(index), reduceMotion: reduceMotion))
                        }
                    }
                    .padding(.horizontal, 28)
                    // 和标题区拉开一点距离；放不下时可以滑动
                    .padding(.top, compact ? 8 : 22)
                    .padding(.bottom, 4)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
                .sensoryFeedback(.selection, trigger: selection)

                // 左下角两颗小石子，和选水平页呼应
                ContinueSketchButton {
                    if selection != InterfaceLanguage.current {
                        askInterface = selection
                    } else {
                        onContinue()
                    }
                }
                    .frame(maxWidth: .infinity)
                    .overlay(alignment: .bottomLeading) {
                        Image("LanguageDots")
                            .resizable()
                            .scaledToFit()
                            .frame(width: width * 0.18)
                            .padding(.leading, width * 0.06)
                            .offset(y: 26)
                            .accessibilityHidden(true)
                    }
                    .padding(.top, compact ? 12 : 20)
                    .padding(.bottom, 28)
                    .modifier(Entrance(appeared: appeared, delay: 0.5, reduceMotion: reduceMotion))
            }
            .frame(width: width, height: proxy.size.height, alignment: .top)
        }
        .background { Theme.sketchPaper.ignoresSafeArea() }
        // 蜡笔插画固定配色，深色模式下也保持浅色底
        .environment(\.colorScheme, .light)
        // 不管换不换都先走完引导（标记完成并保存），跳去设置后 App 重开就直接进首页
        .interfaceLanguagePrompt($askInterface, onDecide: onContinue)
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

    /// 手写标题图（所有语言都用英文），下面一句手写说明，右边一只张嘴说话的小鸟
    private func header(width: CGFloat, compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 8) {
            Image("LanguageTitle")
                .resizable()
                .scaledToFit()
                .frame(width: min(width * 0.68, 300))
                .accessibilityLabel(Text("你的母语是？"))
                .accessibilityAddTraits(.isHeader)
                .modifier(Entrance(appeared: appeared, delay: 0, reduceMotion: reduceMotion))

            // 手写的说明图，和标题一样所有语言都用英文
            Image("LanguageSubtitle")
                .resizable()
                .scaledToFit()
                .frame(width: width * 0.55, alignment: .leading)
                .accessibilityLabel(Text("我们会用它来解释单词，帮你学英语。"))
                .rotationEffect(.degrees(-1), anchor: .leading)
                .padding(.leading, 6)
                .modifier(Entrance(appeared: appeared, delay: 0.08, reduceMotion: reduceMotion))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, width * 0.08)
        .overlay(alignment: .bottomTrailing) {
            Image("LanguageBird")
                .resizable()
                .scaledToFit()
                .frame(width: width * (compact ? 0.3 : 0.34))
                .padding(.trailing, width * 0.01)
                .offset(y: compact ? 0 : 6)
                .rotationEffect(.degrees(appeared ? 0 : 6), anchor: .bottom)
                .scaleEffect(appeared ? 1 : 0.85, anchor: .bottom)
                .opacity(appeared ? 1 : 0)
                .animation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.65).delay(0.15), value: appeared)
                .accessibilityHidden(true)
        }
        .padding(.top, compact ? 4 : 24)
        .padding(.bottom, compact ? 12 : 20)
    }

    private func row(_ language: NativeLanguage, compact: Bool) -> some View {
        let isOn = selection == language
        return Button {
            withAnimation(.snappy(duration: 0.25)) { selection = language }
        } label: {
            HStack(spacing: Spacing.md) {
                // 和选水平页一样用系统自带的 Chalkboard SE Light（中日韩文字会自动用系统字体）
                Text(verbatim: language.endonym)
                    .font(.custom("ChalkboardSE-Light", size: compact ? 18 : 20))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer()
                ZStack {
                    Circle()
                        .strokeBorder(Theme.homeInk, lineWidth: 2)
                    Circle()
                        .fill(Theme.homeInk)
                        .padding(6)
                        .scaleEffect(isOn ? 1 : 0.01)
                        .opacity(isOn ? 1 : 0)
                }
                .frame(width: 24, height: 24)
            }
            .foregroundStyle(Theme.homeInk)
            .padding(.leading, 22)
            .padding(.trailing, 20)
            .frame(height: compact ? 46 : 52)
            .background(isOn ? Self.selectedFill : Self.fill, in: .capsule)
            .overlay(Capsule().strokeBorder(Theme.homeInk.opacity(isOn ? 0 : 0.06), lineWidth: 1.5))
        }
        .buttonStyle(.pressable)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }
}
