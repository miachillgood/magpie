//
//  SchedulingTests.swift
//  SnapLingoTests
//

import Foundation
import Testing
@testable import SnapLingo

private let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Pacific/Auckland")!
    return calendar
}()

private func date(_ day: Int, hour: Int = 9) -> Date {
    calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour))!
}

// MARK: - 间隔重复

@MainActor
struct SpacedRepetitionTests {
    @Test func firstCorrectAnswerIsDueTomorrowAtStartOfDay() {
        let next = SpacedRepetition.schedule(.fresh(on: date(10), calendar: calendar), rating: .good, on: date(10, hour: 23), calendar: calendar)
        #expect(next.state == .learning)
        #expect(next.intervalDays == 1)
        #expect(next.dueDate == calendar.startOfDay(for: date(11)))
    }

    @Test func intervalsGrowAndReachMastered() {
        var state = SRSState.fresh(on: date(1), calendar: calendar)
        var intervals: [Int] = []
        for day in [1, 2, 5, 12] {
            state = SpacedRepetition.schedule(state, rating: .good, on: date(day), calendar: calendar)
            intervals.append(state.intervalDays)
        }
        #expect(intervals == [1, 3, 8, 20])
        state = SpacedRepetition.schedule(state, rating: .good, on: date(28), calendar: calendar)
        #expect(state.intervalDays >= SpacedRepetition.masteredThreshold)
        #expect(state.state == .mastered)
    }

    @Test func forgettingResetsAndCountsLapseOnlyAfterLearning() {
        let fresh = SRSState.fresh(on: date(1), calendar: calendar)
        let firstMiss = SpacedRepetition.schedule(fresh, rating: .again, on: date(1), calendar: calendar)
        #expect(firstMiss.lapses == 0)
        #expect(firstMiss.intervalDays == 1)

        var learned = SpacedRepetition.schedule(fresh, rating: .good, on: date(1), calendar: calendar)
        learned = SpacedRepetition.schedule(learned, rating: .good, on: date(2), calendar: calendar)
        let lapse = SpacedRepetition.schedule(learned, rating: .again, on: date(5), calendar: calendar)
        #expect(lapse.lapses == 1)
        #expect(lapse.repetitions == 0)
        #expect(lapse.easeFactor < learned.easeFactor)
        #expect(lapse.state == .learning)
    }

    @Test func easeFactorNeverDropsBelowMinimum() {
        var state = SRSState.fresh(on: date(1), calendar: calendar)
        for day in 1...15 {
            state = SpacedRepetition.schedule(state, rating: .again, on: date(day), calendar: calendar)
        }
        #expect(state.easeFactor == SpacedRepetition.minEase)
    }
}

// MARK: - 今日计划

private struct TestWord: PlannableWord {
    var id = UUID()
    var state: WordState
    var excludedFromReview = false
    var dueDate: Date
    var addedAt: Date
    var easeFactor = 2.5
}

private struct TestEvent: StudyEvent {
    var wordID: UUID
    var reviewedAt: Date
    var wasNew: Bool
}

@MainActor
struct DailyPlannerTests {
    private let today = date(20, hour: 14)

    @Test func capsNewWordsAndPrefersMostRecentlySaved() {
        let words = (0..<8).map { offset in
            TestWord(state: .new, dueDate: date(20), addedAt: date(10 + offset))
        }
        let plan = DailyPlanner.plan(words: words, events: [TestEvent](), newPerDay: 3, maxReviews: 100, now: today, calendar: calendar)
        #expect(plan.newIDs == words.suffix(3).reversed().map(\.id))
        #expect(plan.reviewIDs.isEmpty)
    }

    @Test func reviewsAreMostOverdueFirstAndCapped() {
        let due = [15, 12, 19, 18].map { day in
            TestWord(state: .learning, dueDate: calendar.startOfDay(for: date(day)), addedAt: date(1))
        }
        let future = TestWord(state: .learning, dueDate: calendar.startOfDay(for: date(22)), addedAt: date(1))
        let plan = DailyPlanner.plan(words: due + [future], events: [TestEvent](), newPerDay: 10, maxReviews: 3, now: today, calendar: calendar)
        #expect(plan.reviewIDs == [due[1].id, due[0].id, due[3].id])
    }

    @Test func excludedWordsAreNeverPlanned() {
        let words = [
            TestWord(state: .mastered, excludedFromReview: true, dueDate: date(1), addedAt: date(1)),
            TestWord(state: .new, excludedFromReview: true, dueDate: date(1), addedAt: date(1))
        ]
        let plan = DailyPlanner.plan(words: words, events: [TestEvent](), newPerDay: 10, maxReviews: 10, now: today, calendar: calendar)
        #expect(plan.remaining == 0)
        #expect(!plan.isComplete)
    }

    @Test func workDoneTodayReducesQuotaAndCompletesPlan() {
        let learnedToday = (0..<2).map { _ in TestWord(state: .learning, dueDate: calendar.startOfDay(for: date(21)), addedAt: date(19)) }
        let waiting = TestWord(state: .new, dueDate: date(20), addedAt: date(19))
        let events = learnedToday.map { TestEvent(wordID: $0.id, reviewedAt: date(20, hour: 8), wasNew: true) }

        let plan = DailyPlanner.plan(words: learnedToday + [waiting], events: events, newPerDay: 2, maxReviews: 100, now: today, calendar: calendar)
        #expect(plan.newDone == 2)
        #expect(plan.newIDs.isEmpty)
        #expect(plan.isComplete)
        #expect(plan.newProgress == 1)
        #expect(plan.reviewProgress == 1, "没有复习任务时，完成计划后复习圈也闭合")

        let more = DailyPlanner.plan(words: learnedToday + [waiting], events: events, newPerDay: 2, maxReviews: 100, extraNew: 5, now: today, calendar: calendar)
        #expect(more.newIDs == [waiting.id])
    }

    @Test func streakCountsConsecutiveDaysAndToleratesTodayNotStarted() {
        let id = UUID()
        let events = [19, 18, 17, 15].map { TestEvent(wordID: id, reviewedAt: date($0), wasNew: false) }
        #expect(DailyPlanner.streak(events: events, now: today, calendar: calendar) == 3)
        let withToday = events + [TestEvent(wordID: id, reviewedAt: date(20, hour: 7), wasNew: false)]
        #expect(DailyPlanner.streak(events: withToday, now: today, calendar: calendar) == 4)
        #expect(DailyPlanner.streak(events: [TestEvent](), now: today, calendar: calendar) == 0)
    }

    @Test func forecastIncludesOverdueOnDayZero() {
        let words = [
            TestWord(state: .learning, dueDate: calendar.startOfDay(for: date(18)), addedAt: date(1)),
            TestWord(state: .learning, dueDate: calendar.startOfDay(for: date(20)), addedAt: date(1)),
            TestWord(state: .learning, dueDate: calendar.startOfDay(for: date(21)), addedAt: date(1)),
            TestWord(state: .new, dueDate: calendar.startOfDay(for: date(21)), addedAt: date(1))
        ]
        let forecast = DailyPlanner.forecast(words: words, days: 3, now: today, calendar: calendar)
        #expect(forecast.map(\.count) == [2, 1, 0])
        #expect(DailyPlanner.nextReviewDay(words: words, after: today, calendar: calendar)?.count == 1)
    }
}

@MainActor
struct RatingOrderTests {
    @Test func easyIsAlwaysLaterThanGoodAndHardNeverLater() {
        var state = SRSState.fresh(on: date(1), calendar: calendar)
        for day in [1, 2, 5] {
            state = SpacedRepetition.schedule(state, rating: .good, on: date(day), calendar: calendar)
            let hard = SpacedRepetition.schedule(state, rating: .hard, on: date(day + 1), calendar: calendar).intervalDays
            let good = SpacedRepetition.schedule(state, rating: .good, on: date(day + 1), calendar: calendar).intervalDays
            let easy = SpacedRepetition.schedule(state, rating: .easy, on: date(day + 1), calendar: calendar).intervalDays
            #expect(hard <= good)
            #expect(easy > good)
        }
    }
}
