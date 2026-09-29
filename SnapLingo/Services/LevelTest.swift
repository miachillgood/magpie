//
//  LevelTest.swift
//  SnapLingo
//

import Foundation

/// 3 轮自适应“点你认识的词”水平自测
struct LevelTest: Sendable {
    struct Item: Identifiable, Hashable, Sendable {
        var word: String
        var level: CEFRLevel
        var id: String { word }
    }

    static let rounds = 3

    /// 生活场景常见词，按大致 CEFR 等级分组
    static let bank: [CEFRLevel: [String]] = [
        .a1: ["water", "bread", "ticket", "open", "price", "milk", "cheap", "left", "bus", "shop"],
        .a2: ["receipt", "towel", "borrow", "delay", "fridge", "platform", "discount", "refund", "luggage", "queue"],
        .b1: ["deposit", "landlord", "appointment", "allergy", "expire", "insurance", "ingredient", "commute", "complaint", "schedule"],
        .b2: ["eligible", "lease", "overdue", "installment", "dispute", "vacancy", "premium", "prescription", "mortgage", "warranty"],
        .c1: ["deductible", "arrears", "exemption", "stipulate", "provisional", "liability", "levy", "surcharge", "tenancy", "amend"],
        .c2: ["indemnify", "forfeit", "lien", "encumbrance", "abatement", "covenant", "subrogation", "rescind", "bequeath", "remittance"]
    ]

    private(set) var round = 0
    private(set) var answers: [Item: Bool] = [:]
    private var used = Set<String>()

    var isFinished: Bool { round >= LevelTest.rounds }

    /// 当前估计分数
    var score: Double { LevelTest.score(for: answers) }
    var estimatedLevel: CEFRLevel { CEFRLevel.from(score: score) }

    /// 生成下一轮要展示的词
    mutating func nextRound() -> [Item] {
        let plan: [(CEFRLevel, Int)]
        if round == 0 {
            plan = [(.a2, 2), (.b1, 2), (.b2, 2), (.c1, 2)]
        } else {
            let center = estimatedLevel
            let lower = CEFRLevel(rawValue: center.rawValue - 1)
            let upper = center.next
            plan = [(lower, 3), (center, 3), (upper, 3)].compactMap { level, count in
                level.map { ($0, count) }
            }
        }
        var items: [Item] = []
        for (level, count) in plan {
            let pool = (LevelTest.bank[level] ?? []).filter { !used.contains($0) }.shuffled()
            for word in pool.prefix(count) {
                items.append(Item(word: word, level: level))
                used.insert(word)
            }
        }
        return items.shuffled()
    }

    mutating func submit(_ items: [Item], known: Set<String>) {
        for item in items {
            answers[item] = known.contains(item.word)
        }
        round += 1
    }

    // MARK: - 计分

    /// 每级“认识比例”做单调递减平滑后求和（减半级），每级约 16.7 分
    static func score(for answers: [Item: Bool]) -> Double {
        var tested: [Int: (known: Int, total: Int)] = [:]
        for (item, known) in answers {
            var entry = tested[item.level.rawValue] ?? (0, 0)
            entry.total += 1
            if known { entry.known += 1 }
            tested[item.level.rawValue] = entry
        }
        guard !tested.isEmpty else { return CEFRLevel.b1.midScore }

        let levels = CEFRLevel.allCases.map(\.rawValue)
        let lowest = tested.keys.min() ?? 1
        let highest = tested.keys.max() ?? 6

        // 1. 已测等级取比例；没测的：比最低还低的视为认识，比最高还高的视为不认识，中间线性插值
        var ratios: [Double] = []
        var weights: [Double] = []
        for level in levels {
            if let entry = tested[level] {
                ratios.append(Double(entry.known) / Double(entry.total))
                weights.append(Double(entry.total))
            } else if level < lowest {
                ratios.append(1); weights.append(1)
            } else if level > highest {
                ratios.append(0); weights.append(1)
            } else {
                let below = tested.keys.filter { $0 < level }.max() ?? lowest
                let above = tested.keys.filter { $0 > level }.min() ?? highest
                let b = tested[below].map { Double($0.known) / Double($0.total) } ?? 1
                let a = tested[above].map { Double($0.known) / Double($0.total) } ?? 0
                let t = Double(level - below) / Double(max(above - below, 1))
                ratios.append(b + (a - b) * t)
                weights.append(0.5)
            }
        }

        // 2. 保序回归（PAV），保证难度越高认识比例不升
        let smoothed = pavDecreasing(ratios, weights: weights)
        // 3. 减去半级：某一级认识一半以上才算达到这一级
        let reachedLevels = smoothed.reduce(0, +) - 0.5
        return min(max(reachedLevels * CEFRLevel.scorePerLevel, 0), 100)
    }

    /// Pool-adjacent-violators，得到单调不增序列
    static func pavDecreasing(_ values: [Double], weights: [Double]) -> [Double] {
        var blocks: [(value: Double, weight: Double, count: Int)] = []
        for (value, weight) in zip(values, weights) {
            blocks.append((value, weight, 1))
            while blocks.count >= 2, blocks[blocks.count - 2].value < blocks[blocks.count - 1].value {
                let last = blocks.removeLast()
                let prev = blocks.removeLast()
                let w = prev.weight + last.weight
                blocks.append(((prev.value * prev.weight + last.value * last.weight) / w, w, prev.count + last.count))
            }
        }
        return blocks.flatMap { Array(repeating: $0.value, count: $0.count) }
    }
}
