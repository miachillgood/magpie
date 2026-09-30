//
//  MeTests.swift
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

private func date(_ day: Int, hour: Int = 10, month: Int = 9) -> Date {
    calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
}

private struct Event: StudyEvent {
    var wordID = UUID()
    var reviewedAt: Date
    var wasNew = false
}

// MARK: - 足迹 / 场景来源 / 记不住的词

@MainActor
struct MeStatsTests {
    @Test func daysSinceFirstCountsTheFirstDayAsOne() {
        #expect(MeStats.daysSinceFirst([], now: date(20), calendar: calendar) == 0)
        #expect(MeStats.daysSinceFirst([date(20, hour: 23)], now: date(20, hour: 8), calendar: calendar) == 1)
        #expect(MeStats.daysSinceFirst([date(18), date(3, hour: 22)], now: date(20, hour: 7), calendar: calendar) == 18)
    }

    @Test func sceneSharesDedupeWordsWithinATypeAndSortByWords() {
        let shared = UUID()
        let oldMenu = SceneRecord(id: UUID(), scene: .restaurant, createdAt: date(1), wordIDs: [shared, UUID()])
        let newMenu = SceneRecord(id: UUID(), scene: .restaurant, createdAt: date(5), wordIDs: [shared, UUID(), UUID()])
        let lease = SceneRecord(id: UUID(), scene: .housing, createdAt: date(3), wordIDs: [UUID(), UUID(), UUID(), UUID(), UUID(), UUID()])
        let empty = SceneRecord(id: UUID(), scene: .bank, createdAt: date(4), wordIDs: [])

        let shares = MeStats.sceneShares([oldMenu, lease, newMenu, empty])

        #expect(shares.map(\.scene) == [.housing, .restaurant])
        #expect(shares.map(\.wordCount) == [6, 4])
        #expect(shares.map(\.scanCount) == [1, 2])
        #expect(shares.map(\.percent) == [60, 40])
        #expect(shares[1].coverScanID == newMenu.id)
        #expect(MeStats.sceneShares([empty]).isEmpty)
    }

    @Test func hardestWordsSkipNeverForgottenAndExcluded() {
        let a = LapseRecord(id: UUID(), lapses: 2, excludedFromReview: false, addedAt: date(1))
        let b = LapseRecord(id: UUID(), lapses: 4, excludedFromReview: false, addedAt: date(2))
        let c = LapseRecord(id: UUID(), lapses: 2, excludedFromReview: false, addedAt: date(9))
        let never = LapseRecord(id: UUID(), lapses: 0, excludedFromReview: false, addedAt: date(3))
        let excluded = LapseRecord(id: UUID(), lapses: 9, excludedFromReview: true, addedAt: date(3))

        #expect(MeStats.hardestWordIDs([a, b, c, never, excluded]) == [b.id, c.id, a.id])
        #expect(MeStats.hardestWordIDs([a, b, c], limit: 2) == [b.id, c.id])
    }

    @Test func longestStreakFindsTheLongestRun() {
        let events = [date(1), date(2), date(2, hour: 20), date(3), date(7), date(8), date(10), date(11), date(12), date(13)]
            .map { Event(reviewedAt: $0) }
        #expect(DailyPlanner.longestStreak(events: events, calendar: calendar) == 4)
        #expect(DailyPlanner.longestStreak(events: [Event](), calendar: calendar) == 0)
        #expect(DailyPlanner.longestStreak(events: [Event(reviewedAt: date(5))], calendar: calendar) == 1)
    }

    @Test func longestStreakCrossesMonthBoundaries() {
        let events = [date(30, month: 9), date(1, month: 10), date(2, month: 10)].map { Event(reviewedAt: $0) }
        #expect(DailyPlanner.longestStreak(events: events, calendar: calendar) == 3)
    }
}

// MARK: - 导出

@MainActor
struct WordExportTests {
    @Test func escapesCommasQuotesAndNewlines() {
        #expect(WordExport.escape("rent") == "rent")
        #expect(WordExport.escape("bond, deposit") == "\"bond, deposit\"")
        #expect(WordExport.escape("say \"hi\"") == "\"say \"\"hi\"\"\"")
        #expect(WordExport.escape("line one\nline two") == "\"line one\nline two\"")
    }

    @Test func csvHasHeaderAndLocalDates() {
        let auckland = TimeZone(identifier: "Pacific/Auckland")!
        // 新西兰 9 月 30 日早上 8 点 = UTC 9 月 29 日
        let row = ExportRow(
            word: "bond",
            partOfSpeech: "n.",
            meaning: "押金，租房时交的保证金",
            example: "Pay the bond, then move in.",
            exampleTranslation: "押金是四周的房租。",
            scene: "租房合同",
            addedAt: date(30, hour: 8)
        )
        let lines = WordExport.csv([row], timeZone: auckland).components(separatedBy: "\r\n")

        #expect(lines[0] == "word,part_of_speech,meaning,example,example_translation,scene,added")
        #expect(lines[1] == "bond,n.,押金，租房时交的保证金,\"Pay the bond, then move in.\",押金是四周的房租。,租房合同,2026-09-30")
        #expect(lines.count == 3 && lines[2].isEmpty)
    }
}

// MARK: - 母语匹配

@MainActor
struct NativeLanguageTests {
    @Test func matchesSystemLanguages() {
        #expect(NativeLanguage(preferredLanguages: ["zh-Hans-CN"]) == .simplifiedChinese)
        #expect(NativeLanguage(preferredLanguages: ["zh-Hant-TW"]) == .traditionalChinese)
        #expect(NativeLanguage(preferredLanguages: ["zh-HK"]) == .traditionalChinese)
        #expect(NativeLanguage(preferredLanguages: ["zh-Hans-HK"]) == .simplifiedChinese)
        #expect(NativeLanguage(preferredLanguages: ["ja-JP"]) == .japanese)
        #expect(NativeLanguage(preferredLanguages: ["ko-KR"]) == .korean)
        #expect(NativeLanguage(preferredLanguages: ["es-MX"]) == .spanish)
        #expect(NativeLanguage(preferredLanguages: ["pt-PT"]) == .portuguese)
        #expect(NativeLanguage(preferredLanguages: ["en-NZ"]) == .english)
    }

    @Test func skipsUnsupportedAndFallsBackToEnglish() {
        #expect(NativeLanguage(preferredLanguages: ["fr-FR", "ko-KR"]) == .korean)
        #expect(NativeLanguage(preferredLanguages: ["fr-FR", "de-DE"]) == .english)
        #expect(NativeLanguage(preferredLanguages: []) == .english)
    }

    @Test func lengthLimitUsesCharactersOnlyForCJK() {
        #expect(NativeLanguage.japanese.lengthLimit(characters: 8, words: 4) == "at most 8 characters")
        #expect(NativeLanguage.spanish.lengthLimit(characters: 8, words: 4) == "at most 4 words")
    }
}

// MARK: - 专门练几个词

@MainActor
struct WordsScopeTests {
    @Test func wordsScopeStudiesOnlyTheChosenWords() throws {
        let container = try ModelContainer(for: SnapLingoApp.schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let now = Date()
        let today = Calendar.current.startOfDay(for: now)

        let due = VocabWord(word: "bond")
        due.state = .learning
        due.dueDate = Calendar.current.date(byAdding: .day, value: -2, to: today)!
        let later = VocabWord(word: "tenancy")
        later.state = .learning
        later.dueDate = Calendar.current.date(byAdding: .day, value: 5, to: today)!
        let fresh = VocabWord(word: "gluten free")
        let excluded = VocabWord(word: "sale")
        excluded.state = .learning
        excluded.excludedFromReview = true
        let other = VocabWord(word: "platform")
        [due, later, fresh, excluded, other].forEach(context.insert)
        try context.save()

        let session = StudySession.make(scope: .words([later.id, fresh.id, due.id, excluded.id, UUID()]), context: context, now: now)

        #expect(session.initialCount == 3)
        #expect(session.current?.word.id == due.id)
        #expect(session.newWordIDs == [fresh.id])
    }
}

// MARK: - 解释结果对回单词

@MainActor
struct ExplanationKeyTests {
    @Test func matchesSlightlyRewrittenKeys() {
        let requested = ["bond", "tap on", "best before", "pw"]
        #expect(ClaudeAPIService.matchKey("bond", lemma: "bond", requested: requested) == "bond")
        #expect(ClaudeAPIService.matchKey("bond word", lemma: "bond", requested: requested) == "bond")
        #expect(ClaudeAPIService.matchKey("tap on word", lemma: "tap on", requested: requested) == "tap on")
        #expect(ClaudeAPIService.matchKey("Best Before.", lemma: "best before", requested: requested) == "best before")
        #expect(ClaudeAPIService.matchKey("per week", lemma: "pw", requested: requested) == "pw")
        #expect(ClaudeAPIService.matchKey("unrelated", lemma: "other", requested: requested) == "unrelated")
    }
}
