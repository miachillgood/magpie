//
//  LevelTests.swift
//  SnapLingoTests
//

import CoreGraphics
import Foundation
import Testing
@testable import SnapLingo

private func candidate(_ word: String, _ level: CEFRLevel?, fromPhoto: Bool = false) -> WordCandidate {
    WordCandidate(word: word, lemma: word, partOfSpeech: "", cefrRaw: level?.rawValue ?? 0, gloss: "", pickedFromPhoto: fromPhoto)
}

@MainActor
struct LevelServiceTests {
    @Test func groupsFollowIPlusOne() {
        let items = [
            candidate("bread", .a1),
            candidate("receipt", .a2),
            candidate("deposit", .b1),
            candidate("lease", .b2),
            candidate("arrears", .c1),
            candidate("mystery", nil)
        ]
        let result = LevelService.classify(items, level: .b1, familiarity: [:], savedKeys: ["bread"])
        let groups = Dictionary(uniqueKeysWithValues: result.map { ($0.id, $0.group) })
        #expect(groups["bread"] == .saved)
        #expect(groups["receipt"] == .known)
        #expect(groups["deposit"] == .recommended)
        #expect(groups["lease"] == .recommended)
        #expect(groups["arrears"] == .advanced)
        #expect(groups["mystery"] == .recommended, "未知难度按用户当前等级处理")
    }

    @Test func familiarityOverridesLevel() {
        let items = [candidate("lease", .b2), candidate("receipt", .a2)]
        let result = LevelService.classify(items, level: .b1, familiarity: ["lease": 0.9, "receipt": 0.1], savedKeys: [])
        #expect(result.first { $0.id == "lease" }?.group == .known)
        #expect(result.first { $0.id == "receipt" }?.group == .recommended)
    }

    @Test func preselectsAtMostEightRecommendedPlusPhotoPicks() {
        var items = (0..<12).map { candidate("word\($0)", .b1) }
        items.append(candidate("tapped", .a1, fromPhoto: true))
        let result = LevelService.classify(items, level: .b1, familiarity: [:], savedKeys: [])
        #expect(result.filter { $0.preselected && !$0.candidate.pickedFromPhoto }.count == LevelService.maxPreselected)
        #expect(result.first { $0.id == "tapped" }?.preselected == true)
    }

    @Test func selectionFeedbackMovesScoreBothWaysAndIsClamped() {
        let items = LevelService.classify(
            [candidate("deposit", .b1), candidate("lease", .b2), candidate("receipt", .a2)],
            level: .b1, familiarity: [:], savedKeys: []
        )
        // 取消两个推荐词 → 偏简单
        #expect(LevelService.selectionDelta(classified: items, selectedKeys: []) == 1.2)
        // 勾选“可能认识”的词 → 偏难
        #expect(LevelService.selectionDelta(classified: items, selectedKeys: ["deposit", "lease", "receipt"]) == -0.6)

        let many = LevelService.classify((0..<20).map { candidate("w\($0)", .b1) }, level: .b1, familiarity: [:], savedKeys: [])
        #expect(LevelService.selectionDelta(classified: many, selectedKeys: []) == 3)
    }
}

@MainActor
struct LevelTestScoringTests {
    private func answers(_ known: [CEFRLevel: Double]) -> [LevelTest.Item: Bool] {
        var result: [LevelTest.Item: Bool] = [:]
        for (level, ratio) in known {
            let words = LevelTest.bank[level] ?? []
            for (index, word) in words.prefix(4).enumerated() {
                result[LevelTest.Item(word: word, level: level)] = Double(index) < ratio * 4
            }
        }
        return result
    }

    @Test func knowingThroughB1ButNotB2IsB1() {
        let score = LevelTest.score(for: answers([.a2: 1, .b1: 1, .b2: 0, .c1: 0]))
        #expect(CEFRLevel.from(score: score) == .b1)
    }

    @Test func knowingEverythingIsTopLevelAndNothingIsA1() {
        #expect(CEFRLevel.from(score: LevelTest.score(for: answers([.a2: 1, .b1: 1, .b2: 1, .c1: 1, .c2: 1]))) == .c2)
        #expect(CEFRLevel.from(score: LevelTest.score(for: answers([.a2: 0, .b1: 0, .b2: 0]))) == .a1)
    }

    @Test func noisyAnswersAreSmoothedMonotonically() {
        let smoothed = LevelTest.pavDecreasing([1, 0.2, 0.8, 0], weights: [1, 1, 1, 1])
        #expect(smoothed == [1, 0.5, 0.5, 0])
    }

    @Test func adaptiveRoundsNeverRepeatWords() {
        var test = LevelTest()
        var seen = Set<String>()
        while !test.isFinished {
            let round = test.nextRound()
            #expect(!round.isEmpty)
            for item in round { #expect(seen.insert(item.word).inserted) }
            test.submit(round, known: Set(round.filter { $0.level <= .b1 }.map(\.word)))
        }
        #expect(test.estimatedLevel == .b1)
    }

    /// 按固定规则作答，把整个测试跑完，返回总词数和结果
    private func run(knowing rule: (LevelTest.Item) -> Bool) -> (words: Int, level: CEFRLevel) {
        var test = LevelTest()
        var total = 0
        while !test.isFinished {
            let round = test.nextRound()
            total += round.count
            test.submit(round, known: Set(round.filter(rule).map(\.word)))
        }
        return (total, test.estimatedLevel)
    }

    @Test func twoShortRounds() {
        #expect(LevelTest.rounds == 2)
        for rule: (LevelTest.Item) -> Bool in [{ _ in true }, { _ in false }, { $0.level <= .b1 }] {
            let words = run(knowing: rule).words
            #expect((14...17).contains(words))
        }
    }

    @Test func twoRoundsStillReachBothEnds() {
        #expect(run { _ in true }.level == .c2)
        #expect(run { _ in false }.level == .a1)
        #expect(run { $0.level <= .b2 }.level == .b2)
    }
}

@MainActor
struct TokenMatcherTests {
    private func token(_ id: Int, _ text: String, line: Int) -> OCRToken {
        OCRToken(id: id, text: text, rect: CGRect(x: Double(id) * 0.1, y: Double(line) * 0.1, width: 0.08, height: 0.05), lineIndex: line)
    }

    @Test func matchesPhrasesAndPluralsButNotStrayParts() {
        let tokens = [
            token(0, "TENANCY", line: 0), token(1, "NOTICE", line: 0),
            token(2, "the", line: 1), token(3, "smoke", line: 1), token(4, "alarms", line: 1),
            token(5, "a", line: 2), token(6, "breach", line: 2), token(7, "notice.", line: 2)
        ]
        let matcher = TokenMatcher(tokens: tokens)
        #expect(matcher.tokenIDs(for: ["smoke alarm"]) == [3, 4])
        #expect(matcher.tokenIDs(for: ["breach notice"]) == [6, 7])
        #expect(matcher.tokenIDs(for: ["tenancy"]) == [0])
        #expect(matcher.occurrences(of: "missing phrase").isEmpty)
    }
}

@MainActor
struct LevelResultTests {
    @Test func everyLevelGetsAThreeTileThreeExampleBand() {
        #expect(LevelBand(.a1) == .everyday)
        #expect(LevelBand(.a2) == .everyday)
        #expect(LevelBand(.b1) == .practical)
        #expect(LevelBand(.b2) == .practical)
        #expect(LevelBand(.c1) == .advanced)
        #expect(LevelBand(.c2) == .advanced)
        for band in LevelBand.allCases {
            #expect(band.focus.count == 3)
            #expect(Set(band.focus.map(\.title)).count == 3)
            #expect(band.examples.count == 3)
            #expect(band.examples.allSatisfy { !$0.phrase.isEmpty && !$0.meaning.isEmpty })
        }
    }
}
