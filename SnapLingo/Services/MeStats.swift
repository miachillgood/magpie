//
//  MeStats.swift
//  SnapLingo
//
//  「我的」页和首页用到的长期统计：来了多少天、英语从哪类场景来、总是记不住的词。
//  只放纯逻辑，方便测试；视图层把 Scan / VocabWord 转成这里的输入。
//

import Foundation

/// 一次拍摄在统计里需要的信息
struct SceneRecord: Sendable {
    var id: UUID
    var scene: SceneType
    var createdAt: Date
    var wordIDs: Set<UUID>
}

/// 某一类场景贡献了多少词
struct SceneTypeShare: Identifiable, Equatable, Sendable {
    var scene: SceneType
    var wordCount: Int
    var scanCount: Int
    /// 0...1，所有类型加起来是 1
    var share: Double
    /// 这一类里最近拍的场景，用来当封面
    var coverScanID: UUID
    var id: SceneType { scene }

    var percent: Int { Int((share * 100).rounded()) }
}

/// 一个忘过的词
struct LapseRecord: Sendable {
    var id: UUID
    var lapses: Int
    var excludedFromReview: Bool
    var addedAt: Date
}

enum MeStats {
    /// 从第一次拍照那天算起是第几天（当天算第 1 天）；还没拍过返回 0
    static func daysSinceFirst(_ dates: [Date], now: Date = Date(), calendar: Calendar = .current) -> Int {
        guard let first = dates.min() else { return 0 }
        let start = calendar.startOfDay(for: first)
        let today = calendar.startOfDay(for: now)
        return max(1, (calendar.dateComponents([.day], from: start, to: today).day ?? 0) + 1)
    }

    /// 按场景类型统计词数（同一类里去重），词多的在前；占比按各类词数之和计算
    static func sceneShares(_ records: [SceneRecord]) -> [SceneTypeShare] {
        let grouped = Dictionary(grouping: records, by: \.scene)
        let counts: [(scene: SceneType, words: Int, scans: Int, cover: UUID)] = grouped.compactMap { scene, items in
            let words = items.reduce(into: Set<UUID>()) { $0.formUnion($1.wordIDs) }.count
            guard words > 0, let latest = items.max(by: { $0.createdAt < $1.createdAt }) else { return nil }
            return (scene, words, items.count, latest.id)
        }
        let total = counts.reduce(0) { $0 + $1.words }
        guard total > 0 else { return [] }
        return counts
            .sorted { $0.words != $1.words ? $0.words > $1.words : $0.scene.rawValue < $1.scene.rawValue }
            .map { SceneTypeShare(scene: $0.scene, wordCount: $0.words, scanCount: $0.scans, share: Double($0.words) / Double(total), coverScanID: $0.cover) }
    }

    /// 总是记不住的词：忘过至少一次、还在复习的，按忘记次数从多到少，一样多时新存的在前
    static func hardestWordIDs(_ records: [LapseRecord], limit: Int = 5) -> [UUID] {
        records
            .filter { $0.lapses > 0 && !$0.excludedFromReview }
            .sorted { $0.lapses != $1.lapses ? $0.lapses > $1.lapses : $0.addedAt > $1.addedAt }
            .prefix(limit)
            .map(\.id)
    }
}
