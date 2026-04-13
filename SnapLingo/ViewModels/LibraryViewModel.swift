//
//  LibraryViewModel.swift
//  SnapLingo
//

import SwiftUI

enum LibrarySortOrder: String, CaseIterable {
    case addedDate  = "添加时间"
    case nextReview = "复习时间"
    case alphabetical = "字母顺序"
}

// 扫描历史记录（按 scanSessionID 分组后的摘要）
struct ScanSession: Identifiable {
    let id: UUID            // scanSessionID
    let date: Date
    let thumbnail: Data?
    let wordCount: Int
}

@Observable
final class LibraryViewModel {
    var searchText = ""
    var selectedScene: SceneTag? = nil
    var selectedSessionID: UUID? = nil    // nil = 全部
    var sortOrder: LibrarySortOrder = .addedDate

    func filtered(_ words: [VocabWord]) -> [VocabWord] {
        var result = words

        // 扫描历史过滤
        if let sessionID = selectedSessionID {
            result = result.filter { $0.scanSessionID == sessionID }
        }

        // 搜索过滤
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            result = result.filter {
                $0.word.lowercased().contains(q) ||
                $0.chineseExplanation.contains(q)
            }
        }

        // 场景过滤
        if let scene = selectedScene {
            result = result.filter { $0.sceneTag == scene }
        }

        // 排序
        switch sortOrder {
        case .addedDate:
            result.sort { $0.addedAt > $1.addedAt }
        case .nextReview:
            result.sort { $0.nextReviewDate < $1.nextReviewDate }
        case .alphabetical:
            result.sort { $0.word.lowercased() < $1.word.lowercased() }
        }

        return result
    }

    /// 按 scanSessionID 分组，生成扫描历史列表（最新在前）
    func scanSessions(from words: [VocabWord]) -> [ScanSession] {
        var groups: [UUID: [VocabWord]] = [:]
        for word in words {
            groups[word.scanSessionID, default: []].append(word)
        }
        return groups.map { id, ws in
            let sorted = ws.sorted { $0.addedAt < $1.addedAt }
            return ScanSession(
                id: id,
                date: sorted.first?.addedAt ?? Date(),
                thumbnail: sorted.first?.sourceImageThumbnail,
                wordCount: ws.count
            )
        }
        .sorted { $0.date > $1.date }
    }

    func dueCount(_ words: [VocabWord]) -> Int {
        words.filter(\.isDueForReview).count
    }
}
