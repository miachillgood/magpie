//
//  OnboardingFlow.swift
//  SnapLingo
//
//  首次启动的步骤顺序：欢迎 → 介绍 →（登录）→ 自选水平 → 母语。
//  要不要用 AI 不在引导里问，第一次拍完照时再弹窗问（见 ScanFlowView）。
//  每日提醒不在引导里问，在“我的”里开。
//  每天几个新词不在这里问（新用户还没概念），默认 10 个，在“我的”里改。
//  登录要等账号服务上线（AccountFeatures.isEnabled）才出现。
//

import Foundation

enum OnboardingStep: String, CaseIterable, Sendable {
    case welcome, intro, login, level, language
}

enum OnboardingFlow {
    static func steps(accountsEnabled: Bool) -> [OnboardingStep] {
        OnboardingStep.allCases.filter { accountsEnabled || $0 != .login }
    }

    /// 下一步；已经是最后一步时返回 nil
    static func next(after step: OnboardingStep, accountsEnabled: Bool) -> OnboardingStep? {
        let steps = steps(accountsEnabled: accountsEnabled)
        guard let index = steps.firstIndex(of: step), index + 1 < steps.count else { return nil }
        return steps[index + 1]
    }
}

#if DEBUG
/// 截图用的启动参数：-onboardingStep level 直接从某一步开始；-loginPage phone / email / code 直接打开登录的某一页
enum OnboardingDebug {
    static func value(after flag: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
    }

    static var initialStep: OnboardingStep {
        value(after: "-onboardingStep").flatMap(OnboardingStep.init(rawValue:)) ?? .welcome
    }
}
#endif

/// 手机号、邮箱、Apple 登录要等账号服务（计划里的阶段 D）上线后才对用户开放。
/// 调试时加启动参数 -previewAccounts 可以先看界面，用的是假的验证码服务。
enum AccountFeatures {
    static var isEnabled: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-previewAccounts")
        #else
        false
        #endif
    }
}
