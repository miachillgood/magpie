//
//  WatchSync.swift
//  Shared（iPhone 和 Apple Watch 两个 target 都编译这个文件）
//
//  手表复习的数据怎么传：
//  - 手机 → 手表：今天要学的卡片（快照），每次计划变了就整份发过去（WatchConnectivity 的 applicationContext，只保留最新一份）
//  - 手表 → 手机：每评一张卡发一条评分（手机在旁边时 sendMessage 马上送到；不在旁边时 transferUserInfo 由系统排队，连上后再送到）
//  排期只在手机上算，手表只负责展示和记下评分。
//

import Foundation

nonisolated enum WatchSync {
    static let snapshotKey = "snapshot"
    static let ratingKey = "rating"
    /// 手表上「怎么说」挑中的一句话，交给手机加入复习
    static let phraseKey = "phrase"
    /// 手表一次最多带多少张卡（applicationContext 有大小限制，也没人会在手表上一次复习上百个）
    static let maxCards = 60

    static func encode<T: Encodable>(_ value: T) -> Data? {
        try? JSONEncoder().encode(value)
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data?) -> T? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}

/// 手表上的一张卡：只带显示要用的文字
nonisolated struct WatchCard: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var word: String
    var phonetic: String
    var meaning: String
    var example: String
    var exampleTranslation: String
    var isNew: Bool
}

/// 今天的复习计划
nonisolated struct WatchSnapshot: Codable, Hashable, Sendable {
    /// 是哪一天的计划（那天的 0 点）；过了这天手表就提示打开手机同步
    var day: Date
    var cards: [WatchCard]
    /// 发音口音：en-US / en-GB / en-AU
    var accent: String
    /// 用户在手机上同意了用 AI：手表上的「怎么说」才能联网问（旧版手机发来的没有这一项，当作没同意）
    var aiAllowed: Bool? = nil
    /// 母语的英文名（Simplified Chinese 等），写进手表「怎么说」的提示词
    var nativeName: String? = nil

    func isCurrent(now: Date = Date(), calendar: Calendar = .current) -> Bool {
        calendar.isDate(day, inSameDayAs: now)
    }
}

/// 手表上「怎么说」里加入复习的一句话。id 用来去重：同一条送到两次只加一次
nonisolated struct WatchPhrase: Codable, Hashable, Sendable {
    var id: UUID
    var phrasing: Phrasing
    var situation: String
}

/// 手表上的一次评分。id 也是手机上那条复习记录的 id，同一条送到两次只记一次
nonisolated struct WatchRating: Codable, Hashable, Sendable {
    var id: UUID
    var wordID: UUID
    /// ReviewRating 的 rawValue：0 不会 / 4 会 / 5 掌握（以后不再复习）
    var ratingRaw: Int
    var reviewedAt: Date
}
