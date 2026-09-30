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
    @State private var path = NavigationPath()
    @State private var pickedDay: PickedDay?
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

    /// 该复习的场景排在前面（到期 + 新词多的在前，一样多时新拍的在前）
    private var sceneCards: [Scan] {
        let today = today
        return scans
            .filter { !$0.words.isEmpty }
            .map { scan -> (scan: Scan, score: Int) in
                let counts = scan.studyCounts(today: today)
                return (scan, counts.due * 2 + counts.new)
            }
            .sorted { $0.score != $1.score ? $0.score > $1.score : $0.scan.createdAt > $1.scan.createdAt }
            .prefix(12)
            .map(\.scan)
    }

    /// 总是记不住的词：忘过的、还在复习的，按忘记次数排，最多 5 个
    private var hardestWords: [VocabWord] {
        let ids = MeStats.hardestWordIDs(words.map { LapseRecord(id: $0.id, lapses: $0.lapses, excludedFromReview: $0.excludedFromReview, addedAt: $0.addedAt) })
        let byID = Dictionary(words.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return ids.compactMap { byID[$0] }
    }

    private var libraryCounts: [WordsFilter: Int] {
        Dictionary(uniqueKeysWithValues: [WordsFilter.new, .learning, .mastered].map { filter in
            (filter, words.filter(filter.matches).count)
        })
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
            onStart: { coordinator.startStudy() },
            onMore: { coordinator.startStudy(.today(extraNew: 5)) }
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

        let cards = sceneCards
        if !cards.isEmpty {
            SceneReviewRow(scans: cards, sidePadding: side, zoom: zoom)
                .padding(.top, 32)
        }

        let hardest = hardestWords
        if !hardest.isEmpty {
            HardestWordsCard(words: hardest) {
                coordinator.startStudy(.words(hardest.map(\.id)))
            }
            .padding(.horizontal, side - 4)
            .padding(.top, 26)
        }

        LibraryEntryCard(total: words.count, counts: libraryCounts)
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
