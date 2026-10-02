//
//  StudySession.swift
//  SnapLingo
//

import Foundation
import SwiftData

/// 一次学习会话：先复习到期的词，再学新词；“不会”的词在本轮稍后再出现，“太简单”的词以后不再出现
@Observable
final class StudySession {
    struct Card: Identifiable, Equatable {
        let id = UUID()
        let word: VocabWord
        let isNew: Bool
        /// 还没到期、顺便再看一遍的词：评分不改变复习安排
        var isPractice = false
        /// 第几次出现（0 = 第一次）
        let attempt: Int

        static func == (lhs: Card, rhs: Card) -> Bool { lhs.id == rhs.id }
    }

    static let retryGap = 4
    static let maxAttempts = 3

    let scope: StudyScope
    private(set) var queue: [Card]
    private(set) var position = 0
    var revealed = false
    /// 点了“不会”、翻过来看意思，等用户点“下一个”才真正记下这次评分
    var missedCurrent = false
    /// 每个词第一次的评分（决定排期）
    private(set) var firstRatings: [UUID: ReviewRating] = [:]
    private(set) var newWordIDs: Set<UUID> = []
    private(set) var lastRating: ReviewRating?
    private(set) var ratingCount = 0
    let initialCount: Int
    /// 刚点的「太简单」可以撤销：记下点之前的样子
    private(set) var pendingUndo: Undo?

    /// 「太简单」是唯一移出复习的评分，手滑了要能退回去
    struct Undo {
        let word: VocabWord
        let srs: SRSState
        let excluded: Bool
        let introducedAt: Date?
        let levelScore: Double
        let firstRating: ReviewRating?
        let log: ReviewLog?
        /// 这个词的熟悉度记录原来的样子；nil 表示原来没有，撤销时删掉新建的那条
        let familiarity: FamiliaritySnapshot?
        let position: Int
    }

    struct FamiliaritySnapshot {
        let confidence: Double
        let evidenceCount: Int
        let lastSourceRaw: String
        let updatedAt: Date
    }

    init(scope: StudyScope, reviews: [VocabWord], news: [VocabWord], practice: [VocabWord] = []) {
        self.scope = scope
        let reviewCards = reviews.map { Card(word: $0, isNew: false, attempt: 0) }
        let newCards = news.map { Card(word: $0, isNew: true, attempt: 0) }
        let practiceCards = practice.map { Card(word: $0, isNew: false, isPractice: true, attempt: 0) }
        let cards = reviewCards + newCards + practiceCards
        self.queue = cards
        self.initialCount = cards.count
        self.newWordIDs = Set(news.map(\.id))
    }

    var current: Card? { position < queue.count ? queue[position] : nil }
    var isFinished: Bool { current == nil }
    var completedCount: Int { firstRatings.count }
    var progress: Double { initialCount == 0 ? 1 : Double(completedCount) / Double(initialCount) }

    var newLearnedCount: Int { firstRatings.keys.filter(newWordIDs.contains).count }
    var reviewedCount: Int { completedCount - newLearnedCount }
    var rememberedCount: Int { firstRatings.values.filter(\.isSuccess).count }

    /// 某个评分会把下次复习安排到几天后（本轮重试的卡不改排期）
    func previewInterval(for rating: ReviewRating) -> Int? {
        guard let card = current, card.attempt == 0, !card.isPractice, rating != .easy else { return nil }
        return SpacedRepetition.schedule(card.word.srs, rating: rating, on: Date(), seed: Self.seed(for: card.word)).intervalDays
    }

    private static func seed(for word: VocabWord) -> UInt64 {
        SpacedRepetition.seed(for: word.id, reviewCount: word.repetitions + word.lapses)
    }

    func rate(_ rating: ReviewRating, context: ModelContext) {
        guard let card = current else { return }
        let word = card.word
        let now = Date()
        pendingUndo = nil
        var undo: Undo?
        if rating == .easy {
            let settings = UserSettings.current(in: context)
            undo = Undo(
                word: word,
                srs: word.srs,
                excluded: word.excludedFromReview,
                introducedAt: word.introducedAt,
                levelScore: settings.levelScore,
                firstRating: firstRatings[word.id],
                log: nil,
                familiarity: Self.familiarity(for: word, in: context).map {
                    FamiliaritySnapshot(confidence: $0.confidence, evidenceCount: $0.evidenceCount, lastSourceRaw: $0.lastSourceRaw, updatedAt: $0.updatedAt)
                },
                position: position
            )
        }
        var insertedLog: ReviewLog?

        if card.attempt == 0 && card.isPractice {
            // 顺便再看一遍：只记本轮结果，不改排期、不写复习记录
            firstRatings[word.id] = rating
        } else if card.attempt == 0 {
            let settings = UserSettings.current(in: context)
            let wasNew = word.state == .new
            let next = SpacedRepetition.schedule(word.srs, rating: rating, on: now, seed: Self.seed(for: word))
            word.srs = next
            word.lastReviewedAt = now
            if wasNew { word.introducedAt = now }

            let log = ReviewLog(wordID: word.id, word: word.word, rating: rating, wasNew: wasNew, intervalAfter: next.intervalDays, reviewedAt: now)
            context.insert(log)
            insertedLog = log
            LevelService.recordFamiliarity(key: word.normalizedForm, confidence: LevelService.confidence(for: rating), source: .review, in: context)
            if wasNew {
                let delta = LevelService.firstSightDelta(rating: rating, wordLevel: word.cefr, userLevel: settings.level)
                settings.levelScore = LevelService.clamp(settings.levelScore + delta)
            }
            firstRatings[word.id] = rating
            try? context.save()
        }

        if rating == .easy, let undo {
            // 太简单：以后不再出现。几秒内可以撤销，之后也能在单词页里“恢复复习”
            WordLibrary.setMastered(word, true, context: context)
            pendingUndo = Undo(
                word: undo.word, srs: undo.srs, excluded: undo.excluded, introducedAt: undo.introducedAt,
                levelScore: undo.levelScore, firstRating: undo.firstRating, log: insertedLog,
                familiarity: undo.familiarity, position: undo.position
            )
        }

        if rating == .again && card.attempt + 1 < StudySession.maxAttempts {
            let retry = Card(word: word, isNew: card.isNew, isPractice: card.isPractice, attempt: card.attempt + 1)
            let index = min(position + 1 + StudySession.retryGap, queue.count)
            queue.insert(retry, at: index)
        }

        lastRating = rating
        ratingCount += 1
        revealed = false
        missedCurrent = false
        position += 1
    }

    /// 撤销刚才的「太简单」：词、复习记录、等级分、熟悉度都回到点之前，卡片重新出现
    func undoLast(context: ModelContext) {
        guard let undo = pendingUndo else { return }
        pendingUndo = nil
        let word = undo.word
        word.srs = undo.srs
        word.excludedFromReview = undo.excluded
        word.introducedAt = undo.introducedAt
        UserSettings.current(in: context).levelScore = undo.levelScore
        if let log = undo.log { context.delete(log) }
        if let existing = Self.familiarity(for: word, in: context) {
            if let old = undo.familiarity {
                existing.confidence = old.confidence
                existing.evidenceCount = old.evidenceCount
                existing.lastSourceRaw = old.lastSourceRaw
                existing.updatedAt = old.updatedAt
            } else {
                context.delete(existing)
            }
        }
        firstRatings[word.id] = undo.firstRating
        try? context.save()

        position = undo.position
        revealed = false
        missedCurrent = false
        lastRating = nil
    }

    /// 几秒后撤销条消失，不能再撤销
    func dismissUndo() { pendingUndo = nil }

    private static func familiarity(for word: VocabWord, in context: ModelContext) -> WordFamiliarity? {
        let key = word.normalizedForm
        return try? context.fetch(FetchDescriptor<WordFamiliarity>(predicate: #Predicate { $0.normalizedForm == key })).first
    }

    // MARK: - 创建

    static func make(scope: StudyScope, context: ModelContext, now: Date = Date()) -> StudySession {
        let settings = UserSettings.current(in: context)
        let words = StudyStore.words(context)
        switch scope {
        case .today(let extraNew):
            let startOfToday = Calendar.current.startOfDay(for: now)
            let plan = StudyStore.plan(
                settings: settings,
                words: words,
                logs: StudyStore.logs(since: startOfToday, context),
                extraNew: extraNew,
                now: now
            )
            let byID = Dictionary(words.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            return StudySession(
                scope: scope,
                reviews: plan.reviewIDs.compactMap { byID[$0] },
                news: plan.newIDs.compactMap { byID[$0] }
            )

        case .scan(let scanID):
            let descriptor = FetchDescriptor<Scan>(predicate: #Predicate { $0.id == scanID })
            let scanWords = (try? context.fetch(descriptor).first)?.words ?? []
            let parts = split(scanWords, now: now)
            return StudySession(scope: scope, reviews: parts.reviews, news: parts.news)

        case .day(let day):
            let calendar = Calendar.current
            let start = calendar.startOfDay(for: day)
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
            let descriptor = FetchDescriptor<Scan>(predicate: #Predicate { $0.createdAt >= start && $0.createdAt < end })
            // 场景和单词是多对多，同一个词可能出现在这天的好几个场景里
            var seen = Set<UUID>()
            let dayWords = ((try? context.fetch(descriptor)) ?? [])
                .flatMap(\.words)
                .filter { seen.insert($0.id).inserted }
            let parts = split(dayWords, now: now)
            return StudySession(scope: scope, reviews: parts.reviews, news: parts.news, practice: parts.notDue)

        case .words(let ids):
            let byID = Dictionary(words.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            let parts = split(ids.compactMap { byID[$0] }, now: now)
            return StudySession(scope: scope, reviews: parts.reviews, news: parts.news, practice: parts.notDue)
        }
    }

    /// 到期的（最逾期的在前）、新词（先保存的在前）、还没到期的学过的词
    private static func split(_ words: [VocabWord], now: Date) -> (reviews: [VocabWord], news: [VocabWord], notDue: [VocabWord]) {
        let today = Calendar.current.startOfDay(for: now)
        let active = words.filter { !$0.excludedFromReview }
        let reviews = active.filter { $0.isDue(today: today) }.sorted { $0.dueDate < $1.dueDate }
        let news = active.filter { $0.state == .new }.sorted { $0.addedAt < $1.addedAt }
        let notDue = active.filter { $0.state != .new && $0.dueDate > today }.sorted { $0.dueDate < $1.dueDate }
        return (reviews, news, notDue)
    }
}
