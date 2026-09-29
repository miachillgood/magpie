//
//  RootTabView.swift
//  SnapLingo
//

import SwiftUI
import SwiftData

struct RootTabView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query private var words: [VocabWord]
    @Query(sort: \ReviewLog.reviewedAt) private var logs: [ReviewLog]
    @Query(sort: \UserSettings.createdAt) private var settingsRows: [UserSettings]

    /// 今天还有没有要学的词（驱动“复习”图标上的小红点）
    private var hasStudyWork: Bool {
        guard let settings = settingsRows.first else { return false }
        return StudyStore.plan(settings: settings, words: words, logs: logs).hasWork
    }

    var body: some View {
        @Bindable var coordinator = coordinator

        // 系统标签栏隐藏，每个标签页底部放自定义的图标导航（中间是快门）
        TabView(selection: $coordinator.selectedTab) {
            Tab("照片墙", systemImage: "photo.on.rectangle.angled", value: AppTab.home) {
                HomeView().hidingSystemTabBar()
            }
            Tab("复习", systemImage: "rectangle.on.rectangle.angled", value: AppTab.review) {
                ReviewView().hidingSystemTabBar()
            }
            Tab("词库", systemImage: "book.closed", value: AppTab.words) {
                WordsView().hidingSystemTabBar()
            }
            Tab("我的", systemImage: "person", value: AppTab.me) {
                MeView().hidingSystemTabBar()
            }
        }
        .fullScreenCover(isPresented: $coordinator.showingScan) {
            ScanFlowView()
        }
        .fullScreenCover(item: $coordinator.studyRequest) { request in
            StudySessionView(request: request)
        }
        .onChange(of: hasStudyWork, initial: true) { _, pending in
            coordinator.reviewPending = pending
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard phase == .active else { return }
            SpeechService.shared.accent = UserSettings.current(in: context).accent
            ExplanationQueue.shared.run(context: context)
            StudyReminder.refresh(context: context)
        }
    }
}
