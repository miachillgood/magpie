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
    @AppStorage(AIConsent.storageKey) private var consentRaw = AIConsent.State.undecided.rawValue

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
        }
        .fullScreenCover(isPresented: $coordinator.showingScan) {
            ScanFlowView()
        }
        .fullScreenCover(item: $coordinator.studyRequest) { request in
            StudySessionView(request: request)
        }
        // 这一版之前装的 App 没问过要不要用 AI，补问一次
        .sheet(isPresented: Binding(
            get: { AIConsent.State(rawValue: consentRaw) ?? .undecided == .undecided },
            set: { _ in }
        )) {
            AIConsentSheet()
        }
        .onChange(of: hasStudyWork, initial: true) { _, pending in
            coordinator.reviewPending = pending
        }
        #if DEBUG
        .task { openDebugScreen() }
        #endif
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard phase == .active else { return }
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
