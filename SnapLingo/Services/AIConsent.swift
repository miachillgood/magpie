//
//  AIConsent.swift
//  SnapLingo
//
//  用户同不同意把文字发给 Anthropic 的 Claude（挑词、写释义）。
//  没同意之前一个请求都不发；可以在「我的」里随时改。
//  存在 UserDefaults 里：网络层在后台线程也能直接读，界面用 @AppStorage 跟着刷新。
//

import Foundation
import SwiftData

nonisolated enum AIConsent {
    enum State: String {
        /// 还没问过（老用户升级后会补问一次）
        case undecided
        case granted
        case declined
    }

    static let storageKey = "aiDataConsent"
    static let privacyPolicyURL = URL(string: "https://www.anthropic.com/legal/privacy")!

    static var state: State {
        get { UserDefaults.standard.string(forKey: storageKey).flatMap(State.init(rawValue:)) ?? .undecided }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: storageKey) }
    }

    static var isGranted: Bool { state == .granted }
}

extension AIConsent {
    /// 同意后把之前攒下的词的释义补上
    @MainActor
    static func grant(context: ModelContext) {
        state = .granted
        ExplanationQueue.shared.run(context: context)
    }

    static func decline() {
        state = .declined
    }
}
