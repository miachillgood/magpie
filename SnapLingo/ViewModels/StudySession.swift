//
//  StudySession.swift
//  SnapLingo
//

import Foundation
import SwiftData

/// 一次学习会话：先复习到期的词，再学新词；“忘了”的词在本轮稍后再出现
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
    /// 每个词第一次的评分（决定排期）
    private(set) var firstRatings: [UUID: ReviewRating] = [:]
    private(set) var newWordIDs: Set<UUID> = []
    private(set) var lastRating: ReviewRating?
    private(set) var ratingCount = 0
    let initialCount: Int

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
        guard let card = current, card.attempt == 0, !card.isPractice else { return nil }
        return SpacedRepetition.schedule(card.word.srs, rating: rating, on: Date()).intervalDays
    }

    func rate(_ rating: ReviewRating, context: ModelContext) {
        guard let card = current else { return }
        let word = card.word
        let now = Date()

        if card.attempt == 0 && card.isPractice {
            // 顺便再看一遍：只记本轮结果，不改排期、不写复习记录
            firstRatings[word.id] = rating
        } else if card.attempt == 0 {
            let settings = UserSettings.current(in: context)
            let wasNew = word.state == .new
            let next = SpacedRepetition.schedule(word.srs, rating: rating, on: now)
            word.srs = next
            word.lastReviewedAt = now
            if wasNew { word.introducedAt = now }

            context.insert(ReviewLog(wordID: word.id, word: word.word, rating: rating, wasNew: wasNew, intervalAfter: next.intervalDays, reviewedAt: now))
            LevelService.recordFamiliarity(key: word.normalizedForm, confidence: LevelService.confidence(for: rating), source: .review, in: context)
            if wasNew {
                let delta = LevelService.firstSightDelta(rating: rating, wordLevel: word.cefr, userLevel: settings.level)
                settings.levelScore = LevelService.clamp(settings.levelScore + delta)
            }
            firstRatings[word.id] = rating
            try? context.save()
        }

        if rating == .again && card.attempt + 1 < StudySession.maxAttempts {
            let retry = Card(word: word, isNew: card.isNew, isPractice: card.isPractice, attempt: card.attempt + 1)
            let index = min(position + 1 + StudySession.retryGap, queue.count)
            queue.insert(retry, at: index)
        }

        lastRating = rating
        ratingCount += 1
        revealed = false
        position += 1
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
