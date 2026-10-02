//
//  SchedulingTests.swift
//  SnapLingoTests
//

import Foundation
import SwiftData
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
    /// 每次都在到期那天复习
    private func reviewOnDue(_ state: SRSState, _ rating: ReviewRating, seed: UInt64 = 0) -> SRSState {
        SpacedRepetition.schedule(state, rating: rating, on: state.dueDate.addingTimeInterval(9 * 3600), seed: seed, calendar: calendar)
    }

    @Test func firstKnowIsDueInTwoDaysAtStartOfDay() {
        let next = SpacedRepetition.schedule(.fresh(on: date(10), calendar: calendar), rating: .good, on: date(10, hour: 23), calendar: calendar)
        #expect(next.state == .learning)
        #expect(next.intervalDays == 2)
        #expect(next.dueDate == calendar.startOfDay(for: date(12)))
        #expect(next.lastReviewedAt == date(10, hour: 23))
    }

    @Test func intervalsGrowAndReachMastered() {
        var state = SpacedRepetition.schedule(.fresh(on: date(1), calendar: calendar), rating: .good, on: date(1), calendar: calendar)
        var intervals = [state.intervalDays]
        while state.state != .mastered && intervals.count < 10 {
            state = reviewOnDue(state, .good)
            intervals.append(state.intervalDays)
        }
        #expect(zip(intervals, intervals.dropFirst()).allSatisfy { $0 < $1 })
        #expect(state.state == .mastered)
        #expect(intervals.count <= 5, "一直记得的话，几次之后就该算掌握了：\(intervals)")
    }

    @Test func intervalIsWhenRecallDropsToNinetyPercent() {
        var state = SpacedRepetition.schedule(.fresh(on: date(1), calendar: calendar), rating: .good, on: date(1), calendar: calendar)
        state = reviewOnDue(state, .good)
        let r = SpacedRepetition.retrievability(elapsedDays: state.stability, stability: state.stability)
        #expect(abs(r - SpacedRepetition.desiredRetention) < 0.0001)
    }

    @Test func forgettingShrinksStabilityAndCountsLapseOnlyAfterLearning() {
        let fresh = SRSState.fresh(on: date(1), calendar: calendar)
        let firstMiss = SpacedRepetition.schedule(fresh, rating: .again, on: date(1), calendar: calendar)
        #expect(firstMiss.lapses == 0)
        #expect(firstMiss.intervalDays == 1)

        var learned = SpacedRepetition.schedule(fresh, rating: .good, on: date(1), calendar: calendar)
        learned = reviewOnDue(learned, .good)
        let lapse = reviewOnDue(learned, .again)
        #expect(lapse.lapses == 1)
        #expect(lapse.repetitions == 0)
        #expect(lapse.stability < learned.stability)
        #expect(lapse.difficulty > learned.difficulty)
        #expect(lapse.intervalDays < learned.intervalDays)
        #expect(lapse.state == .learning)
    }

    @Test func difficultyStaysInRange() {
        var state = SRSState.fresh(on: date(1), calendar: calendar)
        for _ in 0..<15 { state = reviewOnDue(state, .again) }
        #expect(state.difficulty <= 10)
        for _ in 0..<15 { state = reviewOnDue(state, .easy) }
        #expect(state.difficulty >= 1)
    }

    @Test func fuzzStaysCloseAndIsRepeatable() {
        var state = SpacedRepetition.schedule(.fresh(on: date(1), calendar: calendar), rating: .good, on: date(1), calendar: calendar)
        state = reviewOnDue(state, .good)
        let id = UUID()
        let intervals = (0..<20).map { reviewOnDue(state, .good, seed: SpacedRepetition.seed(for: id, reviewCount: $0)).intervalDays }
        let unfuzzed = min(reviewOnDue(state, .good).stability, Double(SpacedRepetition.maxInterval))
        #expect(intervals.allSatisfy { abs(Double($0) - unfuzzed) <= unfuzzed * 0.15 + 1 })
        #expect(Set(intervals).count > 1, "同一个间隔应该会被分散到前后几天")
        let seed = SpacedRepetition.seed(for: id, reviewCount: 3)
        #expect(reviewOnDue(state, .good, seed: seed) == reviewOnDue(state, .good, seed: seed))
    }

    @Test func onlyThreeButtonsAreShown() {
        #expect(ReviewRating.buttons == [.again, .good, .easy])
    }
}

// MARK: - 今日计划

private struct TestWord: PlannableWord {
    var id = UUID()
    var state: WordState
    var excludedFromReview = false
    var dueDate: Date
    var addedAt: Date
    var difficulty = 5.0
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
        for day in [1, 3, 8] {
            state = SpacedRepetition.schedule(state, rating: .good, on: date(day), calendar: calendar)
            let hard = SpacedRepetition.schedule(state, rating: .hard, on: date(day + 2), calendar: calendar).stability
            let good = SpacedRepetition.schedule(state, rating: .good, on: date(day + 2), calendar: calendar).stability
            let easy = SpacedRepetition.schedule(state, rating: .easy, on: date(day + 2), calendar: calendar).stability
            #expect(hard <= good)
            #expect(easy > good)
        }
    }
}

// MARK: - 三个按钮 + 旧数据迁移

@MainActor
struct ThreeButtonSessionTests {
    @Test func tooEasyRetiresTheWordAndKnowSchedulesIt() throws {
        let container = try ModelContainer(for: SnapLingoApp.schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let easy = VocabWord(word: "queue")
        let known = VocabWord(word: "deductible")
        [easy, known].forEach(context.insert)
        try context.save()

        let session = StudySession(scope: .words([easy.id, known.id]), reviews: [], news: [easy, known])
        #expect(session.previewInterval(for: .easy) == nil)
        session.rate(.easy, context: context)
        let preview = session.previewInterval(for: .good)
        session.rate(.good, context: context)

        #expect(easy.excludedFromReview)
        #expect(easy.state == .mastered)
        #expect(!known.excludedFromReview)
        #expect(known.stability > 0)
        #expect(known.intervalDays == preview)
        #expect(session.isFinished)
        #expect(try context.fetch(FetchDescriptor<ReviewLog>()).count == 2)
    }

    @Test func migrationReplaysOldReviewsAndKeepsRetiredWords() throws {
        let container = try ModelContainer(for: SnapLingoApp.schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let reviewed = VocabWord(word: "bond")
        reviewed.state = .learning
        reviewed.intervalDays = 8
        let noHistory = VocabWord(word: "tenancy")
        noHistory.state = .mastered
        noHistory.intervalDays = 30
        noHistory.excludedFromReview = true
        let fresh = VocabWord(word: "platform")
        [reviewed, noHistory, fresh].forEach(context.insert)
        for (day, rating) in [(1, ReviewRating.good), (2, .hard), (5, .good)] {
            context.insert(ReviewLog(wordID: reviewed.id, word: reviewed.word, rating: rating, wasNew: day == 1, intervalAfter: 0, reviewedAt: date(day)))
        }
        try context.save()

        SpacedRepetitionMigration.run(context: context)

        #expect(reviewed.stability > 0)
        #expect(reviewed.lastReviewedAt == date(5))
        #expect(reviewed.dueDate > date(5))
        #expect(noHistory.stability == 30)
        #expect(noHistory.excludedFromReview)
        #expect(noHistory.state == .mastered)
        #expect(fresh.stability == 0)

        // 再跑一次不会重算
        let due = reviewed.dueDate
        SpacedRepetitionMigration.run(context: context)
        #expect(reviewed.dueDate == due)
    }
}

struct StudyPaceTests {
    @Test func adjustingMovesOneOptionAndStopsAtEnds() {
        #expect(StudyPace.adjusted(10, by: 1) == 15)
        #expect(StudyPace.adjusted(10, by: -1) == 5)
        #expect(StudyPace.adjusted(5, by: -1) == 5)
        #expect(StudyPace.adjusted(30, by: 1) == 30)
        #expect(StudyPace.adjusted(8, by: 0) == 10)
        #expect(StudyPace.adjusted(8, by: 1) == 10)
        #expect(StudyPace.adjusted(8, by: -1) == 5)
        #expect(StudyPace.adjusted(2, by: 1) == 5)
    }

    @Test func asksOnlyWhenTheCapHeldWordsBack() {
        let done = DailyPlan(reviewIDs: [], newIDs: [], reviewsDone: 3, newDone: 10)
        let unfinished = DailyPlan(reviewIDs: [UUID()], newIDs: [], reviewsDone: 0, newDone: 10)
        #expect(StudyPace.shouldAsk(plan: done, backlog: 4, asked: false))
        #expect(!StudyPace.shouldAsk(plan: done, backlog: 0, asked: false))
        #expect(!StudyPace.shouldAsk(plan: done, backlog: 4, asked: true))
        #expect(!StudyPace.shouldAsk(plan: unfinished, backlog: 4, asked: false))
    }
}

struct LearningProgressTests {
    @Test func segmentsAddUpAndTooEasyIsSeparate() {
        let words = [
            ProgressRecord(id: UUID(), state: .new, excludedFromReview: false),
            ProgressRecord(id: UUID(), state: .learning, excludedFromReview: false),
            ProgressRecord(id: UUID(), state: .mastered, excludedFromReview: false),
            ProgressRecord(id: UUID(), state: .mastered, excludedFromReview: true)
        ]
        let progress = MeStats.progress(words: words, events: [], now: date(10), calendar: calendar)
        #expect(progress == LearningProgress(new: 1, learning: 1, mastered: 1, tooEasy: 1, masteredThisWeek: 0))
        #expect(progress.total == 4)
    }

    @Test func masteredThisWeekCountsOnlyTheFirstCrossing() {
        let recent = UUID(), old = UUID(), never = UUID()
        let events = [
            IntervalEvent(wordID: recent, reviewedAt: date(8), intervalAfter: 25),
            IntervalEvent(wordID: recent, reviewedAt: date(9), intervalAfter: 60),
            IntervalEvent(wordID: old, reviewedAt: date(1), intervalAfter: 22),
            IntervalEvent(wordID: old, reviewedAt: date(9), intervalAfter: 50),
            IntervalEvent(wordID: never, reviewedAt: date(9), intervalAfter: 10)
        ]
        let progress = MeStats.progress(words: [], events: events, now: date(10), calendar: calendar)
        #expect(progress.masteredThisWeek == 1)
    }
}
