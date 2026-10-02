//
//  HomeView.swift
//  SnapLingo
//
//  首页 = 照片墙。上半部分是最近一次拍照那天的照片墙 + 一句话 + 单词胶囊 + 按钮，
//  文字跟着那天离现在多久变化（见 HomeMood）；下半部分是白色底板，按天排出拍过的照片。
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
    @State private var showingMe = false
    @AppStorage(HomeTheme.storageKey) private var themeRaw = HomeTheme.sky.rawValue
    @Namespace private var zoom

    var body: some View {
        NavigationStack(path: $path) {
            GeometryReader { proxy in
                let content = hero
                let metrics = HomeMetrics(size: proxy.size, firstScreen: HomeMetrics.firstScreenHeight(for: content))
                ScrollViewReader { reader in
                    ScrollView {
                        VStack(spacing: 0) {
                            HomeHero(
                                content: content,
                                background: theme.base,
                                minHeight: metrics.heroMinHeight,
                                metrics: metrics,
                                onAction: { perform($0, scroll: reader) },
                                onProfile: { showingMe = true }
                            )
                            .id(content.mood)

                            timeline(metrics: metrics)
                                .id(Self.timelineID)
                        }
                    }
                    .scrollIndicators(.hidden)
                    .background {
                        // 往下拉过头时露出白色，往上拉过头时露出顶部的底色
                        VStack(spacing: 0) {
                            theme.base
                            Theme.sheet
                        }
                        .ignoresSafeArea()
                    }
                }
            }
            .appTabBar()
            .toolbarVisibility(.hidden, for: .navigationBar)
            .libraryDestinations(zoom: zoom)
            .sheet(isPresented: $showingMe) {
                MeView()
            }
            #if DEBUG
            .task {
                // 截图用：-screen me 直接打开「我的」
                let arguments = ProcessInfo.processInfo.arguments
                if let index = arguments.firstIndex(of: "-screen"), index + 1 < arguments.count, arguments[index + 1] == "me" {
                    showingMe = true
                }
            }
            #endif
        }
    }

    private static let timelineID = "timeline"

    // MARK: - 数据

    private var calendar: Calendar { .current }

    /// 最近一次拍照那天的全部照片（新的在前）
    private var latestDayScans: [Scan] {
        #if DEBUG
        // 截图用：-homePhotos 8 用已有照片凑满 N 张，看照片墙排版
        if let index = ProcessInfo.processInfo.arguments.firstIndex(of: "-homePhotos"),
           index + 1 < ProcessInfo.processInfo.arguments.count,
           let count = Int(ProcessInfo.processInfo.arguments[index + 1]), !scans.isEmpty {
            return (0..<count).map { scans[$0 % scans.count] }
        }
        #endif
        guard let latest = scans.first else { return [] }
        return scans.filter { calendar.isDate($0.createdAt, inSameDayAs: latest.createdAt) }
    }

    private var plan: DailyPlan {
        guard let settings = settingsRows.first else { return .empty }
        return StudyStore.plan(settings: settings, words: words, logs: logs)
    }

    private var theme: HomeTheme { HomeTheme(storedValue: themeRaw) }

    private var mood: HomeMood {
        #if DEBUG
        if let forced = Self.forcedMood, forced == .empty || !scans.isEmpty { return forced }
        #endif
        return HomeMood.pick(latestScanDate: scans.first?.createdAt)
    }

    #if DEBUG
    /// 调试用：启动参数 -homeMood today / recent / away / empty 强制显示某种状态
    private static let forcedMood: HomeMood? = {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-homeMood"), index + 1 < arguments.count else { return nil }
        return HomeMood(rawValue: arguments[index + 1])
    }()
    #endif

    // MARK: - 顶部内容

    private var hero: HomeHeroContent {
        let day = latestDayScans
        guard !day.isEmpty, mood != .empty else { return emptyHero }
        switch mood {
        case .today: return todayHero(day)
        case .recent: return recentHero(day)
        default: return awayHero(day)
        }
    }

    /// 那天捡到的词（去重，先存的在前）
    private static func words(of day: [Scan]) -> [VocabWord] {
        var seen = Set<UUID>()
        return day.flatMap(\.words)
            .sorted { $0.addedAt < $1.addedAt }
            .filter { seen.insert($0.id).inserted }
    }

    /// 地点那一行：1 个场景放场景名，多个场景放“3 个场景”
    private static func placeLine(_ day: [Scan]) -> [HeadlinePiece] {
        if day.count == 1, let scan = day.first {
            return [HomeHeroContent.place(symbol: scan.scene.symbol, title: scan.displayTitle, suffix: placeSuffix(many: false))]
        }
        return [.place(symbol: "mappin.and.ellipse", highlight: String(localized: "\(day.count) 个场景", comment: "Home headline, place line when the photos come from several scenes (inside a white capsule)"), rest: placeSuffix(many: false))]
    }

    private static func pickedUp(_ count: Int) -> [HeadlinePiece] {
        HeadlinePiece.phrase(String(localized: "捡到 **\(count)** 个词", comment: "Home headline; follows the place line; **N** gets a highlighter mark"))
    }

    /// 今天在 [公交站] 捡到 [5 个词]
    private func todayHero(_ day: [Scan]) -> HomeHeroContent {
        let dayWords = Self.words(of: day)
        let single = day.count == 1
        return HomeHeroContent(
            mood: .today,
            label: "Nice find!",
            lines: [[.caption(Self.whereCaption(day[0].createdAt))], Self.placeLine(day), Self.pickedUp(dayWords.count)],
            chips: dayWords.prefix(4).map { .word($0) },
            chipsNote: nil,
            action: single ? .openScan(day[0]) : .studyDay(day[0].createdAt),
            actionTitle: single ? String(localized: "看看新词") : String(localized: "学这些词", comment: "Home button: study the words picked up that day"),
            actionSymbol: "arrow.right",
            photos: day
        )
    }

    /// 周六在 [公交站] 捡到 [5 个词]；有要复习的就“测一测”，没有就出去逛逛
    private func recentHero(_ day: [Scan]) -> HomeHeroContent {
        let dayWords = Self.words(of: day)
        let plan = plan
        let byID = Dictionary(words.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let due = (plan.reviewIDs + plan.newIDs).compactMap { byID[$0] }
        let lines = [[HeadlinePiece.caption(Self.whereCaption(day[0].createdAt))], Self.placeLine(day), Self.pickedUp(dayWords.count)]
        if due.isEmpty {
            return HomeHeroContent(
                mood: .recent,
                label: "Nice find!",
                lines: lines,
                chips: dayWords.prefix(4).map { .word($0) },
                chipsNote: nil,
                action: .scan,
                actionTitle: String(localized: "出去逛逛"),
                actionSymbol: "camera",
                photos: day
            )
        }
        return HomeHeroContent(
            mood: .recent,
            label: "Still remember?",
            lines: lines,
            chips: due.compactMap { word in Self.shortGloss(word.gloss).map { .text($0) } }.prefix(4).map { $0 },
            chipsNote: String(localized: "先想想这些用英文怎么说"),
            action: .study,
            actionTitle: String(localized: "测一测", comment: "Button: quiz yourself"),
            actionSymbol: "arrow.right",
            photos: day
        )
    }

    /// 上次是 9 月 20 日 / 在 [公交站] / 捡到 [5 个词]，好久不见
    private func awayHero(_ day: [Scan]) -> HomeHeroContent {
        let dayWords = Self.words(of: day)
        let when = String(localized: "上次是 \(HomeDates.dateText(for: day[0].createdAt))，在", comment: "Home headline line 1 when the user hasn't scanned for over a week; followed by a place on the next line. The argument is a date like Sep 20")
        return HomeHeroContent(
            mood: .away,
            label: "Miss you!",
            lines: [[.caption(when)], Self.placeLine(day), Self.pickedUp(dayWords.count)],
            chips: dayWords.prefix(4).map { .word($0) },
            chipsNote: String(localized: "好久不见，出去拍一张？"),
            action: .scan,
            actionTitle: String(localized: "出去逛逛"),
            actionSymbol: "camera",
            photos: day
        )
    }

    /// 从没拍过：拍下你的第一块招牌
    private var emptyHero: HomeHeroContent {
        HomeHeroContent(
            mood: .empty,
            label: "Go explore!",
            lines: [[.caption(String(localized: "从身边开始"))], [.text(String(localized: "拍下你的第一块招牌")), .emoji("👀")]],
            chips: [
                String(localized: "咖啡店菜单"),
                String(localized: "公交站牌"),
                String(localized: "超市价签"),
                String(localized: "街边告示")
            ].map { .text($0) },
            chipsNote: String(localized: "可以去这些地方找找"),
            action: .scan,
            actionTitle: String(localized: "出去逛逛"),
            actionSymbol: "camera",
            photos: []
        )
    }

    /// 句子第一行：刚刚在 / 昨天在 / Yesterday at
    private static func whereCaption(_ date: Date) -> String {
        String(localized: "\(HomeDates.whenPhrase(for: date))在", comment: "Home headline line 1, followed by a place on the next line. The argument is Just now / Today / Yesterday / a weekday / a date")
    }

    /// 地点胶囊后面接的小尾巴：中文不需要（或“等”），日文“で”，韩文“에서”
    private static func placeSuffix(many: Bool) -> String {
        many
            ? String(localized: "hero.placeSuffix.many", defaultValue: " 等", comment: "Appended after the place name when the words come from several places (e.g. ' etc.'). Keep the leading space if your language needs it")
            : String(localized: "hero.placeSuffix.one", defaultValue: " ", comment: "Appended after the place name, e.g. a particle like で or 에서. A single space means nothing")
    }

    /// 胶囊里放得下的简短释义：取第一个义项。
    /// 中日韩最多 8 个字；拉丁文字最多 18 个字符，并在单词边界截断
    static func shortGloss(_ gloss: String) -> String? {
        let first = gloss.split(whereSeparator: { "；;，,、/".contains($0) }).first.map(String.init) ?? gloss
        let trimmed = first.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let usesCharacters = trimmed.range(of: #"[\p{Han}\p{Hiragana}\p{Katakana}\p{Hangul}]"#, options: .regularExpression) != nil
        let limit = usesCharacters ? 8 : 18
        guard trimmed.count > limit else { return trimmed }
        var cut = String(trimmed.prefix(limit))
        let endsMidWord = !(trimmed.dropFirst(limit).first?.isWhitespace ?? true)
        if !usesCharacters, endsMidWord, let space = cut.lastIndex(of: " "), cut.distance(from: cut.startIndex, to: space) >= limit / 3 {
            cut = String(cut[..<space])
        }
        return cut.trimmingCharacters(in: .whitespaces) + "…"
    }

    // MARK: - 动作

    private func perform(_ action: HomeHeroAction, scroll: ScrollViewProxy) {
        switch action {
        case .openScan(let scan): path.append(scan)
        case .openWord(let word): path.append(word)
        case .study: coordinator.startStudy()
        case .studyDay(let day): coordinator.startStudy(.day(day))
        case .scan: coordinator.startScan()
        case .showTimeline:
            withAnimation(.smooth) { scroll.scrollTo(Self.timelineID, anchor: .top) }
        }
    }

    // MARK: - 下方的照片时间线

    private func timeline(metrics: HomeMetrics) -> some View {
        let groups = HomeDates.groupByDay(scans) { $0.createdAt }.map { DayGroup(day: $0.day, scans: $0.items) }
        return LazyVStack(alignment: .leading, spacing: 0) {
            if groups.isEmpty {
                Text("拍过的照片会按天出现在这里")
                    .font(.subheadline)
                    .foregroundStyle(Theme.homeMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
            }
            ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                if index > 0 {
                    DayDivider(index: index - 1, sidePadding: metrics.sidePadding)
                }
                DayGroupSection(group: group, index: index, width: metrics.width, scale: metrics.width / 390, sidePadding: metrics.sidePadding, zoom: zoom)
            }
        }
        .padding(.top, 26)
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
        let fixed: CGFloat = 48 + PhotoWall.designHeight(photoCount: min(content.photos.count, PhotoWall.maxPhotos)) + 14 + 16 + 38 + 22 + 48 + 26
        let headline = content.lines.reduce(CGFloat(0)) { total, line in
            total + (line.contains(where: \.isCaption) ? 22 : 40)
        }
        let note: CGFloat = content.chipsNote == nil ? 0 : 22
        // 再留出白色底板露出的一截（日期 + 照片的上沿），让人知道下面还有照片墙
        return fixed + headline + note + 12 + Self.sheetPeek
    }

    /// 第一屏底部，白色照片墙露出的高度
    static let sheetPeek: CGFloat = 104

    /// 顶部斑点底纹至少占多高（屏幕够高时，底纹占掉第一屏的大部分）
    var heroMinHeight: CGFloat { height - Self.sheetPeek }

    /// 横向缩放
    var widthScale: CGFloat { min(max(width / 390, 0.86), 1.15) }

    private var designedFirstScreen: CGFloat { firstScreen * widthScale }

    /// 纵向压缩：放不下时按比例压，最多压到 0.74
    var heightScale: CGFloat { min(1, max(0.74, height / designedFirstScreen)) }

    /// 矮屏幕上单词胶囊只放一行
    var maxChips: Int { isCompact ? 3 : 4 }

    var isCompact: Bool { heightScale < 0.97 }

    var stackScale: CGFloat { width / 390 * heightScale }
    var headlineSize: CGFloat { 25 * widthScale * (isCompact ? max(heightScale, 0.9) : 1) }
    var chipSize: CGFloat { 15 * min(widthScale, 1.06) }
    var sidePadding: CGFloat { width < 380 ? 20 : 24 }
    /// 纵向留白
    func gap(_ value: CGFloat) -> CGFloat { value * heightScale }
}
