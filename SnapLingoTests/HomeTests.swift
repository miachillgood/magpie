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
private let chinese = Locale(identifier: "zh-Hans")

private func date(_ day: Int, hour: Int = 9, minute: Int = 0, month: Int = 9, year: Int = 2026) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
}

// MARK: - 顶部状态

@MainActor
struct HomeMoodTests {
    @Test func neverScannedIsEmpty() {
        #expect(HomeMood.pick(latestScanDate: nil, now: date(28), calendar: calendar) == .empty)
    }

    @Test func followsTheLatestShootingDay() {
        let now = date(28, hour: 20)
        #expect(HomeMood.pick(latestScanDate: date(28, hour: 7), now: now, calendar: calendar) == .today)
        #expect(HomeMood.pick(latestScanDate: date(27, hour: 23), now: now, calendar: calendar) == .recent)
        #expect(HomeMood.pick(latestScanDate: date(25), now: now, calendar: calendar) == .recent)
        #expect(HomeMood.pick(latestScanDate: date(18), now: now, calendar: calendar) == .away)
    }

    @Test func awayStartsAfterAWeek() {
        let now = date(28)
        #expect(HomeMood.pick(latestScanDate: date(21), now: now, calendar: calendar) == .recent, "正好 7 天前还算最近")
        #expect(HomeMood.pick(latestScanDate: date(20), now: now, calendar: calendar) == .away)
    }
}

// MARK: - 日期怎么叫

@MainActor
struct HomeDatesTests {
    @Test func dayNamesWithinAWeek() {
        let now = date(28, hour: 15)
        #expect(HomeDates.dayName(for: date(28, hour: 8), now: now, calendar: calendar, locale: chinese) == "今天")
        #expect(HomeDates.dayName(for: date(27, hour: 23), now: now, calendar: calendar, locale: chinese) == "昨天")
        #expect(HomeDates.dayName(for: date(26), now: now, calendar: calendar, locale: chinese) == "周六")
        #expect(HomeDates.dayName(for: date(21), now: now, calendar: calendar, locale: chinese) == nil)
    }

    @Test func dateTextAddsYearOnlyForOtherYears() {
        let now = date(28)
        #expect(HomeDates.dateText(for: date(23), now: now, calendar: calendar, locale: chinese) == "9月23日")
        #expect(HomeDates.dateText(for: date(30, month: 12, year: 2025), now: now, calendar: calendar, locale: chinese) == "2025年12月30日")
    }

    @Test func whenPhraseSaysJustNowForRecentScans() {
        let now = date(28, hour: 15)
        #expect(HomeDates.whenPhrase(for: date(28, hour: 14, minute: 10), now: now, calendar: calendar, locale: chinese) == "刚刚")
        #expect(HomeDates.whenPhrase(for: date(28, hour: 9), now: now, calendar: calendar, locale: chinese) == "今天")
        #expect(HomeDates.whenPhrase(for: date(27), now: now, calendar: calendar, locale: chinese) == "昨天")
        #expect(HomeDates.whenPhrase(for: date(10), now: now, calendar: calendar, locale: chinese) == "9月10日")
    }

    @Test func formatsDatesInOtherLanguages() {
        let now = date(28)
        let english = Locale(identifier: "en_NZ")
        let japanese = Locale(identifier: "ja_JP")
        #expect(HomeDates.dateText(for: date(23), now: now, calendar: calendar, locale: english) == "23 Sep")
        #expect(HomeDates.dateText(for: date(23), now: now, calendar: calendar, locale: Locale(identifier: "en_US")) == "Sep 23")
        #expect(HomeDates.dateText(for: date(23), now: now, calendar: calendar, locale: japanese) == "9月23日")
        #expect(HomeDates.weekday(for: date(26), calendar: calendar, locale: english) == "Saturday")
        #expect(HomeDates.weekday(for: date(26), calendar: calendar, locale: japanese) == "土曜日")
        #expect(HomeDates.narrowWeekday(for: date(26), calendar: calendar, locale: chinese) == "六")
        #expect(HomeDates.narrowWeekday(for: date(26), calendar: calendar, locale: japanese) == "土")
        #expect(HomeDates.monthName(for: date(26), calendar: calendar, locale: chinese) == "9月")
        #expect(HomeDates.monthName(for: date(26), calendar: calendar, locale: english) == "September")
        #expect(HomeDates.monthName(for: date(26), calendar: calendar, locale: Locale(identifier: "es_MX")) == "Septiembre")
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

    @Test func shortGlossCutsLatinAtWordBoundary() {
        #expect(HomeView.shortGloss("horario, agenda") == "horario")
        #expect(HomeView.shortGloss("fecha de caducidad del producto") == "fecha de caducidad…")
        #expect(HomeView.shortGloss("aviso de mantenimiento") == "aviso de…")
        #expect(HomeView.shortGloss("contraindicaciones") == "contraindicaciones")
        #expect(HomeView.shortGloss("時刻表、スケジュール") == "時刻表")
        #expect(HomeView.shortGloss("유통기한이 지난 음식입니다") == "유통기한이 지난…")
    }
}

// MARK: - 句子里的地点

@MainActor
struct HomePlaceTests {
    @Test func englishNameGoesIntoTheChip() {
        #expect(HomeHeroContent.place(symbol: "fork.knife", title: "Little Bird 咖啡菜单") == .place(symbol: "fork.knife", highlight: "Little Bird", rest: "咖啡菜单"))
    }

    @Test func titlesWithoutAMixKeepEverythingInTheChip() {
        #expect(HomeHeroContent.place(symbol: "house", title: "租房通知单") == .place(symbol: "house", highlight: "租房通知单", rest: ""))
        #expect(HomeHeroContent.place(symbol: "cart", title: "Countdown の棚") == .place(symbol: "cart", highlight: "Countdown", rest: "の棚"))
        #expect(HomeHeroContent.place(symbol: "cart", title: "Countdown 진열대") == .place(symbol: "cart", highlight: "Countdown", rest: "진열대"))
        #expect(HomeHeroContent.place(symbol: "cup.and.saucer", title: "Parlor Coffee") == .place(symbol: "cup.and.saucer", highlight: "Parlor Coffee", rest: ""))
        #expect(HomeHeroContent.place(symbol: "house", title: "租房通知单", suffix: " 等") == .place(symbol: "house", highlight: "租房通知单", rest: " 等"))
    }
}
