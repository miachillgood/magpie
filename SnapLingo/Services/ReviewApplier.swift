//
//  ReviewApplier.swift
//  SnapLingo
//
//  一个词「第一次」评分时要做的所有事：排下次复习、写复习记录、错词标记、熟悉度、水平分。
//  手机上的复习和手表传回来的评分都走这里，保证两边算出来的一样。
//

import Foundation
import SwiftData

enum ReviewApplier {
    /// 记下一次会改排期的评分。logID 给手表用：同一条评分重复送到时据此去重
    @discardableResult
    static func apply(_ rating: ReviewRating, to word: VocabWord, at now: Date = Date(), logID: UUID? = nil, context: ModelContext) -> ReviewLog {
        let settings = UserSettings.current(in: context)
        let wasNew = word.state == .new
        word.mistakeAt = MeStats.mistakeAt(after: rating, previous: word.mistakeAt, now: now)

        let seed = SpacedRepetition.seed(for: word.id, reviewCount: word.repetitions + word.lapses)
        let next = SpacedRepetition.schedule(word.srs, rating: rating, on: now, seed: seed)
        word.srs = next
        word.lastReviewedAt = now
        if wasNew { word.introducedAt = now }

        let log = ReviewLog(wordID: word.id, word: word.word, rating: rating, wasNew: wasNew, intervalAfter: next.intervalDays, reviewedAt: now)
        if let logID { log.id = logID }
        context.insert(log)
        LevelService.recordFamiliarity(key: word.normalizedForm, confidence: LevelService.confidence(for: rating), source: .review, in: context)
        if wasNew {
            let delta = LevelService.firstSightDelta(rating: rating, wordLevel: word.cefr, userLevel: settings.level)
            settings.levelScore = LevelService.clamp(settings.levelScore + delta)
        }
        try? context.save()
        return log
    }

    /// 手表上的评分：同一条只记一次；这个词今天已经在手机上评过了也不再记（今天第一次的评分才算数）
    @discardableResult
    static func apply(_ rating: WatchRating, context: ModelContext, calendar: Calendar = .current) -> Bool {
        guard let value = ReviewRating(rawValue: rating.ratingRaw) else { return false }
        let logID = rating.id
        let duplicates = (try? context.fetchCount(FetchDescriptor<ReviewLog>(predicate: #Predicate { $0.id == logID }))) ?? 0
        guard duplicates == 0 else { return false }

        let wordID = rating.wordID
        guard let word = try? context.fetch(FetchDescriptor<VocabWord>(predicate: #Predicate { $0.id == wordID })).first,
              !word.excludedFromReview
        else { return false }
        if let last = word.lastReviewedAt, calendar.isDate(last, inSameDayAs: rating.reviewedAt) { return false }

        apply(value, to: word, at: rating.reviewedAt, logID: rating.id, context: context)
        return true
    }
}
