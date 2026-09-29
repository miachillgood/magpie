//
//  CollectionPresentation.swift
//  SnapLingo
//

import Foundation

enum DiscoverSceneCategory: String, CaseIterable, Identifiable {
    case all = "全部"
    case restaurant = "餐厅"
    case housing = "租房"
    case campus = "校园"
    case shopping = "购物"
    case medical = "医疗"
    case signage = "标识"
    case general = "通用"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .restaurant: return "fork.knife"
        case .housing: return "house"
        case .campus: return "graduationcap"
        case .shopping: return "cart"
        case .medical: return "cross.case"
        case .signage: return "signpost.right"
        case .general: return "text.bubble"
        }
    }

    func matches(_ collection: WordCollection) -> Bool {
        guard self != .all else { return true }

        let searchableText = [
            collection.title,
            collection.subtitle,
            collection.summaryText,
            collection.persona,
            collection.region
        ]
        .joined(separator: " ")
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()

        let normalizedTags = Set(
            collection.sceneTags.map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            }
        )

        if keywords.contains(where: normalizedTags.contains) {
            return true
        }

        return keywords.contains { searchableText.contains($0) }
    }

    private var keywords: [String] {
        switch self {
        case .all:
            return []
        case .restaurant:
            return ["餐厅", "菜单", "点单", "waiter", "restaurant", "menu"]
        case .housing:
            return ["租房", "租屋", "看房", "房屋", "租约", "tenancy", "bond", "housing"]
        case .campus:
            return ["校园", "学校", "学生", "作业", "选课", "enrolment", "deadline", "campus"]
        case .shopping:
            return ["购物", "超市", "商店", "supermarket", "shopping", "store"]
        case .medical:
            return ["医疗", "医院", "药房", "medical", "clinic", "health"]
        case .signage:
            return ["标识", "路牌", "指示", "signage", "sign", "notice"]
        case .general:
            return ["通用", "general", "日常", "生活"]
        }
    }
}

struct CollectionDeckSummary: Identifiable {
    let collection: WordCollection
    let creator: CreatorProfile?
    let progress: UserCollectionProgress?
    let entryCount: Int
    let dueCount: Int
    let completionRate: Double
    let isSubscribed: Bool

    var id: UUID { collection.id }
    var title: String { collection.title }
    var subtitle: String { collection.subtitle }
    var authorName: String { creator?.displayName ?? "匿名作者" }
    var sceneLabels: [String] { collection.sceneTags.isEmpty ? [DiscoverSceneCategory.general.rawValue] : collection.sceneTags }
}

enum CollectionPresentation {
    static func summaries(
        collections: [WordCollection],
        entries: [WordCollectionEntry],
        progresses: [UserCollectionProgress],
        subscriptions: [CollectionSubscription],
        creators: [CreatorProfile],
        currentUserID: String?
    ) -> [CollectionDeckSummary] {
        let progressByCollection = Dictionary(uniqueKeysWithValues: progresses.map { ($0.collectionID, $0) })
        let creatorByUser = Dictionary(uniqueKeysWithValues: creators.map { ($0.userID, $0) })
        let entryCountByCollection = Dictionary(grouping: entries.filter { !$0.isArchived }, by: \.collectionID)
            .mapValues(\.count)
        let subscribedIDs = Set(subscriptions.filter(\.isActive).map(\.collectionID))

        return collections.map { collection in
            let progress = currentUserID == nil ? nil : progressByCollection[collection.id]
            return CollectionDeckSummary(
                collection: collection,
                creator: creatorByUser[collection.ownerUserID],
                progress: progress,
                entryCount: entryCountByCollection[collection.id] ?? 0,
                dueCount: progress?.dueEntryCount ?? 0,
                completionRate: progress?.completionRate ?? 0,
                isSubscribed: subscribedIDs.contains(collection.id)
            )
        }
    }

    static func entries(
        for collectionID: UUID,
        in entries: [WordCollectionEntry]
    ) -> [WordCollectionEntry] {
        entries
            .filter { $0.collectionID == collectionID && !$0.isArchived }
            .sorted {
                if $0.displayOrder == $1.displayOrder {
                    return $0.createdAt < $1.createdAt
                }
                return $0.displayOrder < $1.displayOrder
            }
    }
}
