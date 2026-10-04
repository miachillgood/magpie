//
//  RootTabView.swift
//  SnapLingo
//

import CoreSpotlight
import SwiftUI
import SwiftData

struct RootTabView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query private var words: [VocabWord]
    @Query(sort: \ReviewLog.reviewedAt) private var logs: [ReviewLog]
    @Query(sort: \UserSettings.createdAt) private var settingsRows: [UserSettings]

    /// 今天还有没有要学的词（图片底部导航里“复习”图标上的小圆点；系统标签栏不显示角标，
    /// 红色数字太抢眼，复习页顶部已经写了今天的数量）
    private var hasStudyWork: Bool {
        guard let settings = settingsRows.first else { return false }
        return StudyStore.plan(settings: settings, words: words, logs: logs).hasWork
    }

    var body: some View {
        @Bindable var coordinator = coordinator

        // iOS 26 的系统玻璃标签栏；拍照放在标签栏上方的附属按钮里。
        // 想换回图片做的底部导航：把 AppTabBar.usesSystemTabBar 改成 false
        TabView(selection: Binding(
            get: { coordinator.selectedTab },
            set: { tab in
                // 快门只是一个按钮：打开相机，标签停在原来那页
                if tab == .snap { coordinator.startScan() } else { coordinator.selectedTab = tab }
            }
        )) {
            Tab("场景", systemImage: "photo.on.rectangle.angled", value: AppTab.home) {
                HomeView().hidingSystemTabBar()
                    .tint(Theme.brand)
            }
            Tab("复习", systemImage: "rectangle.on.rectangle.angled", value: AppTab.review) {
                ReviewView().hidingSystemTabBar()
                    .tint(Theme.brand)
            }
            if AppTabBar.usesSystemTabBar {
                // role: .search 让系统把它放成标签栏右边独立的圆形玻璃按钮
                Tab("拍照", systemImage: "camera.fill", value: AppTab.snap, role: .search) {
                    Color.clear
                }
                .accessibilityLabel("拍一拍，扫描新场景")
            }
        }
        // 选中的标签用墨色（页面内容在上面单独设回品牌色）
        .tint(AppTabBar.usesSystemTabBar ? Theme.homeInk : Theme.brand)
        .modifier(SystemTabBarChrome())
        .fullScreenCover(isPresented: $coordinator.showingScan) {
            ScanFlowView()
        }
        .fullScreenCover(item: $coordinator.studyRequest) { request in
            StudySessionView(request: request)
        }
        .onChange(of: hasStudyWork, initial: true) { _, pending in
            coordinator.reviewPending = pending
        }
        #if DEBUG
        .task { openDebugScreen() }
        #endif
        .onContinueUserActivity(CSSearchableItemActionType) { activity in
            guard let id = SpotlightIndexer.wordID(from: activity) else { return }
            coordinator.showingScan = false
            coordinator.studyRequest = nil
            coordinator.selectedTab = .review
            coordinator.openWordID = id
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard phase == .active else { return }
            SpotlightIndexer.reindex(words)
            let settings = UserSettings.current(in: context)
            SpeechService.shared.accent = settings.accent
            ExplanationQueue.shared.run(context: context)
            StudyReminder.refresh(context: context)
            Task { await AppleAccount.refreshCredentialState(settings: settings, context: context) }
        }
    }

    #if DEBUG
    /// 截图用：-screen review / camera / study 直接打开对应页面（我的页在 HomeView 里处理）
    private func openDebugScreen() {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-screen"), index + 1 < arguments.count else { return }
        switch arguments[index + 1] {
        case "review": coordinator.selectedTab = .review
        case "camera": coordinator.startScan()
        case "study": coordinator.startStudy()
        default: break
        }
    }
    #endif
}
