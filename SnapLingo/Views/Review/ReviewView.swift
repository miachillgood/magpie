//
//  ReviewView.swift
//  SnapLingo
//
//  「复习」标签页（词库也合并在这里）：
//  今日复习是主角，场景是特色，日期是一条轻量的线索，熟悉程度只在词库里当筛选。
//

import SwiftUI
import SwiftData

struct ReviewView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @Query(sort: \Scan.createdAt, order: .reverse) private var scans: [Scan]
    @Query private var words: [VocabWord]
    @Query(sort: \ReviewLog.reviewedAt) private var logs: [ReviewLog]
    @Query(sort: \UserSettings.createdAt) private var settingsRows: [UserSettings]
    @Query(sort: \WordFolder.lastUsedAt, order: .reverse) private var folders: [WordFolder]
    @State private var path = NavigationPath()
    @State private var creatingFolder = false
    @State private var pickedDay: PickedDay?
    @State private var editingGoal = false
    @Namespace private var zoom

    var body: some View {
        NavigationStack(path: $path) {
            GeometryReader { proxy in
                let scale = min(max(proxy.size.width / 390, 0.86), 1.15)
                let side: CGFloat = proxy.size.width < 380 ? 20 : 24
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        header
                            .padding(.horizontal, side)
                            .padding(.top, 4)
                        if words.isEmpty {
                            emptyState
                                .padding(.horizontal, side)
                                .padding(.top, 60)
                        } else {
                            content(scale: scale, side: side)
                        }
                    }
                    .padding(.bottom, 30)
                    .background(alignment: .top) { ThemeWash() }
                }
                .scrollIndicators(.hidden)
            }
            .background(Theme.mist.ignoresSafeArea())
            .toolbarVisibility(.hidden, for: .navigationBar)
            .appTabBar()
            .navigationDestination(for: ReviewRoute.self) { route in
                switch route {
                case .library(let filter, let searching):
                    WordsView(initialFilter: filter, startsSearching: searching)
                case .month(let month):
                    MonthCalendarView(month: month) { pickedDay = PickedDay(date: $0) }
                case .mistakes:
                    MistakesView()
                case .collection(let source):
                    CollectionWordsView(source: source)
                }
            }
            .sheet(isPresented: $editingGoal) {
                if let settings = settingsRows.first {
                    DailyGoalSheet(settings: settings)
                }
            }
            .sheet(isPresented: $creatingFolder) {
                FolderEditorView { folder in
                    path.append(ReviewRoute.collection(.folder(folder)))
                }
            }
            .libraryDestinations(zoom: zoom)
            .sheet(item: $pickedDay) { picked in
                DayReviewSheet(
                    day: picked.date,
                    onStudy: { studyDay(picked.date) },
                    onOpenScan: { scan in
                        pickedDay = nil
                        path.append(scan)
                    },
                    onOpenWord: { word in
                        pickedDay = nil
                        path.append(word)
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - 数据

    private var today: Date { Calendar.current.startOfDay(for: Date()) }

    private var plan: DailyPlan {
        guard let settings = settingsRows.first else { return .empty }
        return StudyStore.plan(settings: settings, words: words, logs: logs)
    }

    /// 今天要学的词来自哪些场景，词多的在前
    private func sources(for plan: DailyPlan) -> [Scan] {
        let planned = Set(plan.reviewIDs + plan.newIDs)
        var counts: [UUID: (scan: Scan, count: Int)] = [:]
        for word in words where planned.contains(word.id) {
            guard let scan = word.latestScan else { continue }
            counts[scan.id, default: (scan, 0)].count += 1
        }
        return counts.values
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.scan.createdAt > $1.scan.createdAt }
            .map(\.scan)
    }

    /// 明天以后最近的两个有复习的日子
    private var upcoming: [ForecastDay] {
        Array(DailyPlanner.forecast(words: words, days: 14).dropFirst().filter { $0.count > 0 }.prefix(2))
    }

    private var backlog: Int {
        words.filter { $0.state == .new && !$0.excludedFromReview }.count
    }

    private var recentDays: [ReviewDay] {
        ReviewDays.recent(
            count: 7,
            captures: scans.map { CaptureRecord(date: $0.createdAt, wordIDs: Set($0.words.map(\.id))) },
            reviewDates: logs.map(\.reviewedAt)
        )
    }

    /// 有词的分类，按分类的固定顺序
    private var categoryCounts: [(scene: SceneType, count: Int)] {
        let counts = Dictionary(grouping: words, by: SceneType.of).mapValues(\.count)
        return SceneType.allCases.compactMap { scene in counts[scene].map { (scene, $0) } }
    }

    /// 错词：最近一次点了「不会」、还没答对的词，最近错的在前
    private var mistakeWords: [VocabWord] {
        let ids = MeStats.mistakeWordIDs(words.map { MistakeRecord(id: $0.id, mistakeAt: $0.mistakeAt, excludedFromReview: $0.excludedFromReview) })
        let byID = Dictionary(words.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return ids.compactMap { byID[$0] }
    }

    private var learningProgress: LearningProgress {
        MeStats.progress(
            words: words.map { ProgressRecord(id: $0.id, state: $0.state, excludedFromReview: $0.excludedFromReview) },
            events: logs.map { IntervalEvent(wordID: $0.wordID, reviewedAt: $0.reviewedAt, intervalAfter: $0.intervalAfter) }
        )
    }

    // MARK: - 布局

    private var header: some View {
        HStack {
            Text("复习")
                .font(.system(size: 30, weight: .heavy))
                .foregroundStyle(Theme.homeInk)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button {
                path.append(ReviewRoute.library(.all, searching: true))
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.homeInk)
                    .frame(width: 42, height: 42)
                    .background(Theme.sheet, in: .circle)
                    .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("搜索词库")
        }
        .frame(height: 50)
    }

    @ViewBuilder
    private func content(scale: CGFloat, side: CGFloat) -> some View {
        let plan = plan
        TodayReviewCard(
            plan: plan,
            sources: sources(for: plan),
            upcoming: upcoming,
            backlog: backlog,
            scale: scale,
            dailyNewGoal: settingsRows.first?.newWordsPerDay ?? StudyPace.standard.rawValue,
            onStart: { coordinator.startStudy() },
            onMore: { coordinator.startStudy(.today(extraNew: 5)) },
            onEditGoal: { editingGoal = true },
            onOpenSource: { path.append($0) }
        )
        .padding(.horizontal, side)
        .padding(.top, 16)

        RecentDaysStrip(
            days: recentDays,
            dailyGoal: settingsRows.first?.newWordsPerDay ?? 8,
            onPick: { pickedDay = PickedDay(date: $0) },
            onMonth: { path.append(ReviewRoute.month(Date())) }
        )
        .padding(.horizontal, side)
        .padding(.top, 30)

        // 自己建的文件夹和自动分类放在同一个格子里，点进去都一样
        CollectionGrid(
            folders: folders,
            categories: categoryCounts,
            sidePadding: side,
            onOpen: { path.append(ReviewRoute.collection($0)) },
            onNew: { creatingFolder = true }
        )
        .padding(.top, 32)

        let mistakes = mistakeWords
        if !mistakes.isEmpty {
            MistakesCard(words: mistakes) {
                coordinator.startStudy(.words(mistakes.map(\.id)))
            }
            .padding(.horizontal, side - 4)
            .padding(.top, 26)
        }

        LibraryEntryCard(progress: learningProgress)
            .padding(.horizontal, side - 4)
            .padding(.top, 26)
            .overlay(alignment: .topTrailing) {
                JournalStickerView(kind: .tapePlain).offset(x: 6, y: 14)
            }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Text("还没有要复习的词")
                .font(.system(size: 22, weight: .heavy))
            Text("拍一个英文场景，挑几个词，之后每天在这里按计划复习。")
                .font(.system(size: 15))
                .foregroundStyle(Theme.homeMuted)
                .multilineTextAlignment(.center)
            Button { coordinator.startScan() } label: {
                Label("去拍一个", systemImage: "camera")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.cream)
                    .padding(.horizontal, 24)
                    .frame(height: 50)
                    .background(Theme.homeInk, in: .capsule)
            }
            .buttonStyle(.pressable)
            .padding(.top, 6)
        }
        .foregroundStyle(Theme.homeInk)
        .frame(maxWidth: .infinity)
    }

    // MARK: - 动作

    /// 先收起半屏页，再打开学习（两个弹出层不能同时出现）
    private func studyDay(_ day: Date) {
        pickedDay = nil
        Task {
            try? await Task.sleep(for: .milliseconds(350))
            coordinator.startStudy(.day(day))
        }
    }
}
