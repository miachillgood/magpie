//
//  AppShortcuts.swift
//  SnapLingo
//
//  快捷指令 / Siri / Spotlight 里的两个动作：开始今天的复习、拍一个新场景
//

import AppIntents

struct StartReviewIntent: AppIntent {
    static let title: LocalizedStringResource = "开始今天的复习"
    static let description = IntentDescription("打开 Magpie，直接开始今天要学和要复习的词。")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        let coordinator = NotificationRouter.shared.coordinator
        coordinator?.showingScan = false
        coordinator?.selectedTab = .review
        coordinator?.startStudy()
        return .result()
    }
}

struct SnapSceneIntent: AppIntent {
    static let title: LocalizedStringResource = "拍一个新场景"
    static let description = IntentDescription("打开 Magpie 的相机，拍下身边的英文。")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationRouter.shared.coordinator?.startScan()
        return .result()
    }
}

struct MagpieShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartReviewIntent(),
            phrases: [
                "Start review in \(.applicationName)",
                "用\(.applicationName)复习"
            ],
            shortTitle: "开始复习",
            systemImageName: "rectangle.on.rectangle.angled"
        )
        AppShortcut(
            intent: SnapSceneIntent(),
            phrases: [
                "Snap a scene in \(.applicationName)",
                "用\(.applicationName)拍照"
            ],
            shortTitle: "拍一个新场景",
            systemImageName: "camera"
        )
    }
}
