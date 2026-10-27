//
//  ReviewTests.swift
//  SnapLingoTests
//

import Foundation
import SwiftData
import Testing
@testable import SnapLingo

private let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Pacific/Auckland")!
    calendar.firstWeekday = 2
    return calendar
}()

/// 2026 年 9 月：1 号是周二，28 号是周一
private func date(_ day: Int, hour: Int = 10, month: Int = 9) -> Date {
    calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
}

private struct Word: PlannableWord {
    var id = UUID()
    var state: WordState
    var excludedFromReview = false
    var dueDate: Date
    var addedAt = Date()
    var difficulty = 5.0
}

// MARK: - 最近两周 / 整月

@MainActor
struct ReviewDaysTests {
    @Test func recentDaysEndOnTodayAndCountUniqueWords() {
        let shared = UUID()
        let captures = [
            CaptureRecord(date: date(26, hour: 9), wordIDs: [shared, UUID(), UUID()]),
            CaptureRecord(date: date(26, hour: 18), wordIDs: [shared, UUID()]),
            CaptureRecord(date: date(20), wordIDs: [UUID()])
        ]
        let days = ReviewDays.recent(count: 14, endingAt: date(28, hour: 21), captures: captures, reviewDates: [date(27), date(27, hour: 22)], calendar: calendar)

        #expect(days.count == 14)
        #expect(days.first?.date == calendar.startOfDay(for: date(15)))
        #expect(days.last?.date == calendar.startOfDay(for: date(28)))

        let sixth = days.first { $0.date == calendar.startOfDay(for: date(26)) }
        #expect(sixth?.scanCount == 2)
        #expect(sixth?.wordCount == 4)
        #expect(days.first { $0.date == calendar.startOfDay(for: date(27)) }?.reviewCount == 2)
        #expect(days.first { $0.date == calendar.startOfDay(for: date(21)) }?.hasCaptures == false)
    }

    @Test func shadeGrowsWithWordCountNotScanCount() {
        func day(_ words: Int, scans: Int = 1) -> ReviewDay {
            ReviewDay(date: date(1), scanCount: scans, wordCount: words, reviewCount: 0)
        }
        #expect(ReviewDay(date: date(1), scanCount: 0, wordCount: 0, reviewCount: 3).shade == 0)
        #expect(day(2).shade == 1)
        #expect(day(5, scans: 3).shade == 2)
        #expect(day(12).shade == 3)
    }

    @Test func reviewRingFillsTowardsDailyGoal() {
        let day = ReviewDay(date: date(1), scanCount: 0, wordCount: 0, reviewCount: 4)
        #expect(day.reviewProgress(goal: 8) == 0.5)
        #expect(day.reviewProgress(goal: 3) == 1)
        #expect(ReviewDay(date: date(1), scanCount: 1, wordCount: 2, reviewCount: 0).reviewProgress(goal: 8) == 0)
    }

    @Test func monthHasEveryDayAndMondayFirstBlanks() {
        let days = ReviewDays.month(containing: date(15), captures: [], reviewDates: [], calendar: calendar)
        #expect(days.count == 30)
        #expect(days.first?.date == calendar.startOfDay(for: date(1)))
        // 9 月 1 日是周二，周一开头的日历前面空 1 格
        #expect(ReviewDays.leadingBlanks(forMonthContaining: date(15), calendar: calendar) == 1)
    }
}

// MARK: - 能不能学

@MainActor
struct StudyableTests {
    private let today = calendar.startOfDay(for: date(28))

    @Test func newAndDueWordsAreStudyable() {
        #expect(Word(state: .new, dueDate: date(30)).isStudyable(today: today))
        #expect(Word(state: .learning, dueDate: date(27)).isStudyable(today: today))
        #expect(Word(state: .learning, dueDate: date(27)).isDue(today: today))
    }

    @Test func notDueOrExcludedWordsAreNot() {
        #expect(!Word(state: .learning, dueDate: date(30)).isStudyable(today: today))
        #expect(!Word(state: .mastered, excludedFromReview: true, dueDate: date(1)).isStudyable(today: today))
        #expect(!Word(state: .new, dueDate: date(1)).isDue(today: today))
    }
}

// MARK: - 以后的日子怎么叫

@MainActor
struct UpcomingNameTests {
    @Test func namesTheNextFewDays() {
        let now = date(28, hour: 20)
        #expect(HomeDates.upcomingName(for: date(29), now: now, calendar: calendar, locale: Locale(identifier: "zh-Hans")) == "明天")
        #expect(HomeDates.upcomingName(for: date(30), now: now, calendar: calendar, locale: Locale(identifier: "zh-Hans")) == "后天")
        #expect(HomeDates.upcomingName(for: date(1, month: 10), now: now, calendar: calendar, locale: Locale(identifier: "zh-Hans")) == "周四")
        #expect(HomeDates.upcomingName(for: date(8, month: 10), now: now, calendar: calendar, locale: Locale(identifier: "zh-Hans")) == "10月8日")
    }
}

@MainActor
struct TooEasyUndoTests {
    @Test func undoRestoresWordLogAndCard() throws {
        let container = try ModelContainer(for: SnapLingoApp.schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let word = VocabWord(word: "gluten free")
        context.insert(word)
        let other = VocabWord(word: "bond")
        context.insert(other)
        try context.save()
        let scoreBefore = UserSettings.current(in: context).levelScore

        let session = StudySession(scope: .today(extraNew: 0), reviews: [], news: [word, other])
        session.revealed = true
        session.rate(.easy, context: context)

        #expect(word.excludedFromReview)
        #expect(session.pendingUndo != nil)
        #expect(session.current?.word.id == other.id)
        #expect(try context.fetchCount(FetchDescriptor<ReviewLog>()) == 1)

        session.undoLast(context: context)

        #expect(!word.excludedFromReview)
        #expect(word.state == .new)
        #expect(word.introducedAt == nil)
        #expect(session.current?.word.id == word.id)
        #expect(session.completedCount == 0)
        #expect(session.pendingUndo == nil)
        #expect(try context.fetchCount(FetchDescriptor<ReviewLog>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<WordFamiliarity>()) == 0)
        #expect(UserSettings.current(in: context).levelScore == scoreBefore)
    }

    @Test func otherRatingsCannotBeUndone() throws {
        let container = try ModelContainer(for: SnapLingoApp.schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let word = VocabWord(word: "bond")
        context.insert(word)
        let session = StudySession(scope: .today(extraNew: 0), reviews: [], news: [word])
        session.rate(.good, context: context)
        #expect(session.pendingUndo == nil)
    }
}

@MainActor
struct WatchSyncTests {
    @Test func snapshotPutsReviewsBeforeNewWords() throws {
        let container = try ModelContainer(for: SnapLingoApp.schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let review = VocabWord(word: "receipt", gloss: "收据")
        review.state = .learning
        let fresh = VocabWord(word: "oat", gloss: "燕麦")
        [review, fresh].forEach(context.insert)
        let plan = DailyPlan(reviewIDs: [review.id], newIDs: [fresh.id], reviewsDone: 0, newDone: 0)

        let snapshot = WatchBridge.snapshot(plan: plan, words: [fresh, review], accent: "en-GB")

        #expect(snapshot.cards.map(\.word) == ["receipt", "oat"])
        #expect(snapshot.cards.map(\.isNew) == [false, true])
        #expect(snapshot.cards[1].meaning == "燕麦")
        #expect(snapshot.accent == "en-GB")
        #expect(snapshot.isCurrent())
        // 能编码成 Data 发出去，再原样解回来
        #expect(WatchSync.decode(WatchSnapshot.self, from: WatchSync.encode(snapshot)) == snapshot)
    }

    @Test func watchRatingIsRecordedOnceAndOnlyOncePerDay() throws {
        let container = try ModelContainer(for: SnapLingoApp.schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let word = VocabWord(word: "oat")
        context.insert(word)
        let rating = WatchRating(id: UUID(), wordID: word.id, ratingRaw: ReviewRating.good.rawValue, reviewedAt: Date())

        #expect(ReviewApplier.apply(rating, context: context))
        #expect(word.state != .new)
        #expect(word.introducedAt == rating.reviewedAt)
        let logs = try context.fetch(FetchDescriptor<ReviewLog>())
        #expect(logs.map(\.id) == [rating.id])
        #expect(logs.first?.wasNew == true)

        // 同一条又送到一次：不再记
        #expect(!ReviewApplier.apply(rating, context: context))
        // 同一天又评了一次（比如手机上先评过）：今天第一次的才算
        let again = WatchRating(id: UUID(), wordID: word.id, ratingRaw: ReviewRating.again.rawValue, reviewedAt: Date())
        #expect(!ReviewApplier.apply(again, context: context))
        #expect(try context.fetchCount(FetchDescriptor<ReviewLog>()) == 1)
        #expect(word.mistakeAt == nil)
    }
}
