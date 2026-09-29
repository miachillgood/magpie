//
//  HomeTests.swift
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

/// 2026 年 9 月：28 日是周一，26 日是周六
private func date(_ day: Int, hour: Int = 9, minute: Int = 0, month: Int = 9, year: Int = 2026) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
}

// MARK: - 顶部状态

@MainActor
struct HomeMoodTests {
    @Test func scanningTodayWinsOverEverything() {
        let mood = HomeMood.pick(scannedToday: true, pendingStudy: 12, scansThisWeek: 5, now: date(27), calendar: calendar)
        #expect(mood == .captured)
    }

    @Test func pendingStudyComesBeforeWeeklyRecap() {
        let mood = HomeMood.pick(scannedToday: false, pendingStudy: 3, scansThisWeek: 5, now: date(27), calendar: calendar)
        #expect(mood == .review)
    }

    @Test func weeklyRecapOnlyOnWeekendsWithScans() {
        #expect(HomeMood.pick(scannedToday: false, pendingStudy: 0, scansThisWeek: 2, now: date(27), calendar: calendar) == .weekly)
        #expect(HomeMood.pick(scannedToday: false, pendingStudy: 0, scansThisWeek: 2, now: date(29), calendar: calendar) == .empty)
        #expect(HomeMood.pick(scannedToday: false, pendingStudy: 0, scansThisWeek: 0, now: date(27), calendar: calendar) == .empty)
    }
}

// MARK: - 日期怎么叫

@MainActor
struct HomeDatesTests {
    @Test func dayNamesWithinAWeek() {
        let now = date(28, hour: 15)
        #expect(HomeDates.dayName(for: date(28, hour: 8), now: now, calendar: calendar) == "今天")
        #expect(HomeDates.dayName(for: date(27, hour: 23), now: now, calendar: calendar) == "昨天")
        #expect(HomeDates.dayName(for: date(26), now: now, calendar: calendar) == "周六")
        #expect(HomeDates.dayName(for: date(21), now: now, calendar: calendar) == nil)
    }

    @Test func dateTextAddsYearOnlyForOtherYears() {
        let now = date(28)
        #expect(HomeDates.dateText(for: date(23), now: now, calendar: calendar) == "9 月 23 日")
        #expect(HomeDates.dateText(for: date(30, month: 12, year: 2025), now: now, calendar: calendar) == "2025 年 12 月 30 日")
    }

    @Test func whenPhraseSaysJustNowForRecentScans() {
        let now = date(28, hour: 15)
        #expect(HomeDates.whenPhrase(for: date(28, hour: 14, minute: 10), now: now, calendar: calendar) == "刚刚")
        #expect(HomeDates.whenPhrase(for: date(28, hour: 9), now: now, calendar: calendar) == "今天")
        #expect(HomeDates.whenPhrase(for: date(27), now: now, calendar: calendar) == "昨天")
        #expect(HomeDates.whenPhrase(for: date(10), now: now, calendar: calendar) == "9 月 10 日")
    }

    @Test func groupsByDayNewestFirst() {
        let items = [date(26, hour: 10), date(28, hour: 9), date(26, hour: 18), date(28, hour: 20)]
        let groups = HomeDates.groupByDay(items, calendar: calendar) { $0 }
        #expect(groups.map(\.day) == [calendar.startOfDay(for: date(28)), calendar.startOfDay(for: date(26))])
        #expect(groups[0].items == [date(28, hour: 9), date(28, hour: 20)])
        #expect(groups[1].items.count == 2)
    }
}

// MARK: - 胶囊里的释义

@MainActor
struct HomeGlossTests {
    @Test func shortGlossKeepsFirstSense() {
        #expect(HomeView.shortGloss("时刻表；日程") == "时刻表")
        #expect(HomeView.shortGloss("  ") == nil)
        #expect(HomeView.shortGloss("一个非常非常长的中文释义内容") == "一个非常非常长的…")
    }
}
