//
//  LibraryViewModel.swift
//  SnapLingo
//

import SwiftUI

// MARK: - 枚举

enum LibrarySortOrder: String, CaseIterable {
    case addedDate    = "添加时间"
    case nextReview   = "复习时间"
    case alphabetical = "字母顺序"
}

enum LibraryBrowseMode: String, CaseIterable {
    case byCategory = "按场景"
    case byDate     = "按日期"
}

enum MasteryFilter: String, CaseIterable {
    case all        = "全部"
    case due        = "待复习"
    case mastered   = "已掌握"
    case unfamiliar = "生疏"   // repetitions == 0，从未答对过
}

// MARK: - ScanSession（供 DayDetailSheet 用）

struct ScanSession: Identifiable {
    let id: UUID
    let date: Date
    let thumbnail: Data?
    let wordCount: Int
    let categoryName: String
    let words: [VocabWord]
}

// MARK: - 日期摘要（按日期浏览用）

struct DaySummary: Identifiable {
    let id: Date        // startOfDay
    let wordCount: Int
}

// MARK: - ViewModel

@Observable
final class LibraryViewModel {
    var searchText   = ""
    var browseMode   = LibraryBrowseMode.byCategory
    var selectedCategory: String? = nil
    var selectedDate: Date? = nil
    var masteryFilter = MasteryFilter.all
    var sortOrder    = LibrarySortOrder.addedDate

    // MARK: - 过滤

    func filtered(_ words: [VocabWord]) -> [VocabWord] {
        var result = words

        // 搜索
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            result = result.filter {
                $0.word.lowercased().contains(q) || $0.chineseExplanation.contains(q)
            }
        }

        // 场景 / 日期 主过滤
        switch browseMode {
        case .byCategory:
            if let cat = selectedCategory {
                result = result.filter { $0.categoryName == cat }
            }
        case .byDate:
            if let date = selectedDate {
                let cal = Calendar.current
                result = result.filter { cal.isDate($0.addedAt, inSameDayAs: date) }
            }
        }

        // 掌握程度过滤
        switch masteryFilter {
        case .all:        break
        case .due:        result = result.filter { $0.isDueForReview }
        case .mastered:   result = result.filter { $0.isMastered }
        case .unfamiliar: result = result.filter { $0.repetitions == 0 && !$0.isMastered }
        }

        // 排序
        switch sortOrder {
        case .addedDate:    result.sort { $0.addedAt > $1.addedAt }
        case .nextReview:   result.sort { $0.nextReviewDate < $1.nextReviewDate }
        case .alphabetical: result.sort { $0.word.lowercased() < $1.word.lowercased() }
        }

        return result
    }

    // MARK: - 场景分类列表

    func allCategories(from words: [VocabWord]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for word in words.sorted(by: { $0.addedAt < $1.addedAt }) {
            if seen.insert(word.categoryName).inserted { result.append(word.categoryName) }
        }
        return result
    }

    // MARK: - 日期摘要列表（按日期浏览用）

    func daySummaries(from words: [VocabWord]) -> [DaySummary] {
        let cal = Calendar.current
        var counts: [Date: Int] = [:]
        for word in words {
            let day = cal.startOfDay(for: word.addedAt)
            counts[day, default: 0] += 1
        }
        return counts.map { DaySummary(id: $0.key, wordCount: $0.value) }
            .sorted { $0.id > $1.id }
    }

    // MARK: - 某天的扫描会话（DayDetailSheet 用）

    func sessions(on date: Date, from words: [VocabWord]) -> [ScanSession] {
        let cal = Calendar.current
        let dayWords = words.filter { cal.isDate($0.addedAt, inSameDayAs: date) }
        var groups: [UUID: [VocabWord]] = [:]
        for word in dayWords { groups[word.scanSessionID, default: []].append(word) }
        return groups.map { id, ws in
            let sorted = ws.sorted { $0.addedAt < $1.addedAt }
            return ScanSession(
                id: id, date: sorted.first?.addedAt ?? date,
                thumbnail: sorted.first?.sourceImageThumbnail,
                wordCount: ws.count,
                categoryName: sorted.first?.categoryName ?? "通用",
                words: sorted
            )
        }.sorted { $0.date < $1.date }
    }

    // MARK: - 辅助

    func dueCount(_ words: [VocabWord]) -> Int {
        words.filter(\.isDueForReview).count
    }

    /// 切换浏览模式时重置对应的选中状态
    func switchBrowseMode(_ mode: LibraryBrowseMode) {
        browseMode = mode
        selectedCategory = nil
        selectedDate = nil
    }
}
