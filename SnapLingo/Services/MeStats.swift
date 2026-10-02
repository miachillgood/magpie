//
//  MeStats.swift
//  SnapLingo
//
//  「我的」页用到的长期统计：来了多少天、总是记不住的词。
//  只放纯逻辑，方便测试；视图层把 Scan / VocabWord 转成这里的输入。
//

import Foundation

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

    /// 总是记不住的词：忘过至少一次、还在复习的，按忘记次数从多到少，一样多时新存的在前
    static func hardestWordIDs(_ records: [LapseRecord], limit: Int = 5) -> [UUID] {
        records
            .filter { $0.lapses > 0 && !$0.excludedFromReview }
            .sorted { $0.lapses != $1.lapses ? $0.lapses > $1.lapses : $0.addedAt > $1.addedAt }
            .prefix(limit)
            .map(\.id)
    }
}
