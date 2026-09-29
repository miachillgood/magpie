//
//  HomeView.swift
//  SnapLingo
//
//  首页 = 照片墙。上半部分随当天状态变化（柔光色 + 一句话 + 单词胶囊 + 按钮），
//  下半部分是白色底板，按天排出拍过的照片。
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @Query(sort: \Scan.createdAt, order: .reverse) private var scans: [Scan]
    @Query private var words: [VocabWord]
    @Query(sort: \ReviewLog.reviewedAt) private var logs: [ReviewLog]
    @Query(sort: \UserSettings.createdAt) private var settingsRows: [UserSettings]
    @State private var path = NavigationPath()
    @Namespace private var zoom

    var body: some View {
        NavigationStack(path: $path) {
            GeometryReader { proxy in
                let content = hero
                let metrics = HomeMetrics(size: proxy.size, firstScreen: HomeMetrics.firstScreenHeight(for: content))
                ScrollViewReader { reader in
                    ScrollView {
                        VStack(spacing: 0) {
                            HomeHero(content: content, streak: streak, metrics: metrics) { action in
                                perform(action, scroll: reader)
                            }
                            .id(content.mood)

                            timeline(metrics: metrics)
                                .id(Self.timelineID)
                        }
                    }
                    .scrollIndicators(.hidden)
                    .background {
                        // 往下拉过头时露出白色，往上拉过头时露出奶油色
                        VStack(spacing: 0) {
                            Theme.cream
                            Theme.sheet
                        }
                        .ignoresSafeArea()
                    }
                }
            }
            .appTabBar()
            .toolbarVisibility(.hidden, for: .navigationBar)
            .libraryDestinations(zoom: zoom)
        }
    }

    private static let timelineID = "timeline"

    // MARK: - 数据

    private var calendar: Calendar { .current }

    private var todayScans: [Scan] {
        scans.filter { calendar.isDateInToday($0.createdAt) }
    }

    private var weekScans: [Scan] {
        scans.filter { calendar.isDate($0.createdAt, equalTo: Date(), toGranularity: .weekOfYear) }
    }

    private var plan: DailyPlan {
        guard let settings = settingsRows.first else { return .empty }
        return StudyStore.plan(settings: settings, words: words, logs: logs)
    }

    private var streak: Int { DailyPlanner.streak(events: logs) }

    private var mood: HomeMood {
        #if DEBUG
        if let forced = Self.forcedMood { return forced }
        #endif
        return HomeMood.pick(scannedToday: !todayScans.isEmpty, pendingStudy: plan.remaining, scansThisWeek: weekScans.count)
    }

    #if DEBUG
    /// 调试用：启动参数 -homeMood review 强制显示某种状态
    private static let forcedMood: HomeMood? = {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-homeMood"), index + 1 < arguments.count else { return nil }
        return HomeMood(rawValue: arguments[index + 1])
    }()
    #endif

    // MARK: - 顶部内容

    private var hero: HomeHeroContent {
        switch mood {
        case .captured: capturedHero ?? emptyHero
        case .review: reviewHero ?? emptyHero
        case .weekly: weeklyHero ?? emptyHero
        case .empty: emptyHero
        }
    }

    /// 刚刚在 [公交站] 捡到 [5 个新词]
    private var capturedHero: HomeHeroContent? {
        guard let focus = todayScans.first else { return nil }
        let todayWords = Set(todayScans.flatMap { $0.words.map(\.id) }).count
        let focusWords = focus.words.sorted { $0.addedAt < $1.addedAt }
        let lines: [[HeadlinePiece]]
        let label: String
        if todayWords >= 15 {
            lines = [[.text("今天已经捕捉")], [.marker("\(todayWords)", "个词了！")]]
            label = "On a roll!"
        } else {
            lines = [
                [.text("\(HomeDates.whenPhrase(for: focus.createdAt))在")],
                [.place(focus.scene.symbol, focus.displayTitle)],
                [.text("捡到"), .marker("\(focusWords.count)", "个新词")]
            ]
            label = "Nice find!"
        }
        return HomeHeroContent(
            mood: .captured,
            label: label,
            lines: lines,
            chips: focusWords.prefix(6).map { .word($0) },
            chipsNote: nil,
            action: .openScan(focus),
            actionTitle: "看看新词",
            actionSymbol: "arrow.right",
            photos: Self.stackPhotos(todayScans, fillingWith: scans),
            stackStyle: .pile
        )
    }

    /// 昨天在 [公交站] 遇见 [5 个词]，还记得几个？
    private var reviewHero: HomeHeroContent? {
        let plan = plan
        let byID = Dictionary(words.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let due = (plan.reviewIDs + plan.newIDs).compactMap { byID[$0] }
        guard !due.isEmpty else { return nil }

        // 这些词大多来自哪个场景
        var counts: [UUID: (scan: Scan, count: Int)] = [:]
        for word in due {
            guard let scan = word.latestScan else { continue }
            counts[scan.id, default: (scan, 0)].count += 1
        }
        let sources = counts.values.sorted { lhs, rhs in
            lhs.count != rhs.count ? lhs.count > rhs.count : lhs.scan.createdAt > rhs.scan.createdAt
        }

        var lines: [[HeadlinePiece]]
        if let focus = sources.first {
            // 词来自好几个场景时，地点后面加一个“等”
            let place = focus.count < due.count ? focus.scan.displayTitle + " 等" : focus.scan.displayTitle
            lines = [
                [.text("\(HomeDates.whenPhrase(for: focus.scan.createdAt))在"), .place(focus.scan.scene.symbol, place)],
                [.text("遇见"), .marker("\(due.count)", "个词")],
                [.text("还记得几个？")]
            ]
        } else {
            lines = [[.text("有"), .marker("\(due.count)", "个词")], [.text("等你复习")]]
        }

        return HomeHeroContent(
            mood: .review,
            label: "Still remember?",
            lines: lines,
            chips: due.compactMap { word in Self.shortGloss(word.gloss).map { .text($0) } }.prefix(4).map { $0 },
            chipsNote: "先想想这些用英文怎么说",
            headlineScale: 0.9,
            action: .study,
            actionTitle: "测一测",
            actionSymbol: "arrow.right",
            photos: Self.stackPhotos(sources.map(\.scan), fillingWith: scans),
            stackStyle: .pile
        )
    }

    /// 这周你在 [5 个地方] 发现了 [16 个词]
    private var weeklyHero: HomeHeroContent? {
        let week = weekScans
        guard !week.isEmpty else { return nil }
        var seen = Set<UUID>()
        let weekWords = week.flatMap(\.words)
            .sorted { $0.addedAt > $1.addedAt }
            .filter { seen.insert($0.id).inserted }
        return HomeHeroContent(
            mood: .weekly,
            label: "Great week!",
            lines: [
                [.text("这周你在"), .place("mappin.and.ellipse", "\(week.count) 个地方")],
                [.text("发现了"), .marker("\(weekWords.count)", "个词")]
            ],
            chips: weekWords.prefix(5).map { .word($0) },
            chipsNote: "这周遇见的词",
            action: .showTimeline,
            actionTitle: "看看这一周",
            actionSymbol: "arrow.right",
            photos: Self.stackPhotos(week, fillingWith: scans, limit: 4),
            stackStyle: .fan
        )
    }

    /// 今天还没发现新单词 👀
    private var emptyHero: HomeHeroContent {
        let lines: [[HeadlinePiece]] = scans.isEmpty
            ? [[.text("拍下你的")], [.text("第一块招牌"), .emoji("👀")]]
            : [[.text("今天还没发现")], [.text("新单词"), .emoji("👀")]]
        return HomeHeroContent(
            mood: .empty,
            label: "Go explore!",
            lines: lines,
            chips: ["咖啡店菜单", "公交站牌", "超市价签", "药店货架", "街边告示"].map { .text($0) },
            chipsNote: "可以去这些地方找找",
            action: .scan,
            actionTitle: "出去逛逛",
            actionSymbol: "camera",
            photos: Array(scans.prefix(2)),
            stackStyle: .emptySlot
        )
    }

    /// 照片堆最多三张：先放主要的，不够再用最近拍的补上
    static func stackPhotos(_ primary: [Scan], fillingWith recent: [Scan], limit: Int = 3) -> [Scan] {
        var result = Array(primary.prefix(limit))
        for scan in recent where result.count < limit && !result.contains(where: { $0.id == scan.id }) {
            result.append(scan)
        }
        return result
    }

    /// 胶囊里放得下的简短释义：取第一个义项，最多 8 个字
    static func shortGloss(_ gloss: String) -> String? {
        let first = gloss.split(whereSeparator: { "；;，,、/".contains($0) }).first.map(String.init) ?? gloss
        let trimmed = first.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        return trimmed.count > 8 ? String(trimmed.prefix(8)) + "…" : trimmed
    }

    // MARK: - 动作

    private func perform(_ action: HomeHeroAction, scroll: ScrollViewProxy) {
        switch action {
        case .openScan(let scan): path.append(scan)
        case .openWord(let word): path.append(word)
        case .study: coordinator.startStudy()
        case .scan: coordinator.startScan()
        case .showTimeline:
            withAnimation(.smooth) { scroll.scrollTo(Self.timelineID, anchor: .top) }
        }
    }

    // MARK: - 下方的照片时间线

    private func timeline(metrics: HomeMetrics) -> some View {
        let groups = HomeDates.groupByDay(scans) { $0.createdAt }.map { DayGroup(day: $0.day, scans: $0.items) }
        return LazyVStack(alignment: .leading, spacing: 34) {
            if groups.isEmpty {
                Text("拍过的照片会按天出现在这里")
                    .font(.subheadline)
                    .foregroundStyle(Theme.homeMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
            }
            ForEach(groups) { group in
                DayGroupSection(group: group, scale: metrics.width / 390, zoom: zoom)
            }
        }
        .padding(.horizontal, metrics.sidePadding)
        .padding(.top, 30)
        .padding(.bottom, 40)
        .frame(maxWidth: .infinity, minHeight: metrics.height * 0.5, alignment: .top)
        .background(
            Theme.sheet,
            in: UnevenRoundedRectangle(topLeadingRadius: 32, topTrailingRadius: 32, style: .continuous)
        )
        .shadow(color: .black.opacity(0.05), radius: 16, y: -8)
    }
}

// MARK: - 屏幕适配

/// 设计稿按 390pt 宽画。宽度决定整体缩放；矮屏幕（SE、mini）再压缩照片堆和留白，保证按钮在第一屏
struct HomeMetrics {
    var width: CGFloat
    var height: CGFloat
    /// 这一屏内容在设计稿（390pt 宽）里的高度
    var firstScreen: CGFloat

    init(size: CGSize, firstScreen: CGFloat = 650) {
        width = max(size.width, 320)
        height = max(size.height, 480)
        self.firstScreen = firstScreen
    }

    /// 第一屏（标题、照片堆、句子、胶囊、按钮）的设计稿高度：随句子行数、有没有提示语变化。
    /// 按 iPhone 17 Pro 实测校准（三行句子、两行胶囊约 640pt），再留一点余量
    static func firstScreenHeight(for content: HomeHeroContent) -> CGFloat {
        let fixed: CGFloat = 48 + PhotoStack.designHeight + 32 + 18 + 30 + 56
        let headline = CGFloat(content.lines.count) * 50 * content.headlineScale
        let note: CGFloat = content.chipsNote == nil ? 0 : 25
        return fixed + headline + note + 2 * 46 + 12
    }

    /// 横向缩放
    var widthScale: CGFloat { min(max(width / 390, 0.86), 1.15) }

    private var designedFirstScreen: CGFloat { firstScreen * widthScale }

    /// 纵向压缩：放不下时按比例压，最多压到 0.74
    var heightScale: CGFloat { min(1, max(0.74, height / designedFirstScreen)) }

    /// 矮屏幕上单词胶囊只放一行
    var maxChips: Int { isCompact ? 3 : 6 }

    var isCompact: Bool { heightScale < 0.97 }

    var stackScale: CGFloat { width / 390 * heightScale }
    var headlineSize: CGFloat { 36 * widthScale * (isCompact ? max(heightScale, 0.88) : 1) }
    var chipSize: CGFloat { 16 * min(widthScale, 1.08) }
    var sidePadding: CGFloat { width < 380 ? 20 : 24 }
    /// 纵向留白
    func gap(_ value: CGFloat) -> CGFloat { value * heightScale }
}
