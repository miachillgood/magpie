//
//  InterfaceLanguage.swift
//  SnapLingo
//
//  界面语言跟随 iOS（系统语言，或「设置 → Magpie → 语言」）。
//  App 里不自己切语言：选的母语和界面语言不一样时问一句，答应了就跳到 iPhone 设置里 Magpie 那一页，
//  用户在「语言」里选好，iOS 会用新语言重新打开 App——整个 App 连同系统弹窗、日期格式一起换。
//

import SwiftUI
import UIKit

enum InterfaceLanguage {
    /// 现在界面用的是哪种语言
    static var current: NativeLanguage {
        NativeLanguage(preferredLanguages: Bundle.main.preferredLocalizations)
    }

    /// 打开 iPhone 设置里 Magpie 自己那一页（「语言」就在第一屏）
    @MainActor
    static func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

extension View {
    /// 母语和界面语言不一样时，问要不要把界面也换成母语。
    /// `language` 不为空就弹出；选「换」先跑 onDecide 再跳设置（引导里要先把进度存好，App 重开后才不会从头来）
    func interfaceLanguagePrompt(_ language: Binding<NativeLanguage?>, onDecide: @escaping () -> Void = {}) -> some View {
        alert(
            Text("要把 Magpie 的界面也换成\(language.wrappedValue?.endonym ?? "")吗？", comment: "Alert after picking a native language that differs from the app's interface language; the argument is a language name like 简体中文"),
            isPresented: Binding(get: { language.wrappedValue != nil }, set: { if !$0 { language.wrappedValue = nil } }),
            presenting: language.wrappedValue
        ) { target in
            Button("换成\(target.endonym)") {
                onDecide()
                InterfaceLanguage.openSystemSettings()
            }
            Button("保持现在的界面", role: .cancel) { onDecide() }
        } message: { target in
            Text("会打开 iPhone 设置，点「语言」选\(target.endonym)，Magpie 会用新语言重新打开。", comment: "Alert message explaining how to switch the app's interface language; the argument is a language name")
        }
    }
}
