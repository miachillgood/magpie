//
//  ReviewTests.swift
//  SnapLingoTests
//

import Foundation
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
    var easeFactor = 2.5
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
