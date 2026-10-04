//
//  SpotlightIndexer.swift
//  SnapLingo
//
//  把词库里的词放进 iPhone 的 Spotlight：下拉搜索英文或释义就能找到，点开直达单词详情
//

import CoreSpotlight
import UniformTypeIdentifiers

enum SpotlightIndexer {
    private static let domain = "words"

    /// 整体重建：词量不大（几百上千个），每次回到前台重建一次最简单可靠
    static func reindex(_ words: [VocabWord]) {
        let items = words.map { word in
            let attributes = CSSearchableItemAttributeSet(contentType: .text)
            attributes.title = word.word
            attributes.contentDescription = word.meaning
            attributes.keywords = [word.word, word.gloss]
            return CSSearchableItem(uniqueIdentifier: word.id.uuidString, domainIdentifier: domain, attributeSet: attributes)
        }
        let index = CSSearchableIndex.default()
        index.deleteSearchableItems(withDomainIdentifiers: [domain]) { _ in
            index.indexSearchableItems(items)
        }
    }

    /// Spotlight 点开时带回来的单词 id
    static func wordID(from activity: NSUserActivity) -> UUID? {
        guard activity.activityType == CSSearchableItemActionType,
              let id = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String else { return nil }
        return UUID(uuidString: id)
    }
}
