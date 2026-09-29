//
//  CollectionModels.swift
//  SnapLingo
//

import Foundation
import SwiftData

enum AccountProvider: String, Codable, CaseIterable {
    case apple
    case guest
    case phone
    case email
    case social

    var displayName: String {
        switch self {
        case .apple: return "Apple"
        case .guest: return "历史本地账号"
        case .phone: return "手机号"
        case .email: return "邮箱"
        case .social: return "社交账号"
        }
    }
}

enum CollectionVisibility: String, Codable, CaseIterable {
    case `private`
    case `public`

    var displayName: String {
        switch self {
        case .private: return "私密"
        case .public: return "公开"
        }
    }
}

enum CollectionStatus: String, Codable, CaseIterable {
    case draft
    case published
    case archived

    var displayName: String {
        switch self {
        case .draft: return "草稿"
        case .published: return "已发布"
        case .archived: return "已归档"
        }
    }
}

enum CollectionModerationStatus: String, Codable, CaseIterable {
    case normal
    case reported
    case hidden
}

@Model
final class UserAccount {
    @Attribute(.unique) var userID: String
    var primaryProviderRaw: String
    var providerUserID: String
    var email: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        userID: String,
        primaryProvider: AccountProvider,
        providerUserID: String,
        email: String? = nil
    ) {
        self.userID = userID
        self.primaryProviderRaw = primaryProvider.rawValue
        self.providerUserID = providerUserID
        self.email = email
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var primaryProvider: AccountProvider {
        get { AccountProvider(rawValue: primaryProviderRaw) ?? .guest }
        set { primaryProviderRaw = newValue.rawValue }
    }
}

@Model
final class CreatorProfile {
    @Attribute(.unique) var userID: String
    var displayName: String
    var bio: String
    var region: String
    var persona: String
    var createdAt: Date
    var updatedAt: Date

    init(
        userID: String,
        displayName: String,
        bio: String = "",
        region: String = "",
        persona: String = ""
    ) {
        self.userID = userID
        self.displayName = displayName
        self.bio = bio
        self.region = region
        self.persona = persona
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

@Model
final class Lexeme {
    @Attribute(.unique) var normalizedForm: String
    var id: UUID
    var canonicalWord: String
    var createdAt: Date
    var updatedAt: Date

    init(word: String, normalizedForm: String) {
        self.id = UUID()
        self.canonicalWord = word
        self.normalizedForm = normalizedForm
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

@Model
final class WordCollection {
    var id: UUID
    var ownerUserID: String
    var title: String
    var subtitle: String
    var summaryText: String
    var region: String
    var persona: String
    var sceneTags: [String]
    var visibilityRaw: String
    var statusRaw: String
    var moderationStatusRaw: String
    var coverImage: Data?
    var contentRevision: Int
    var reportCount: Int
    var isFeatured: Bool
    var isDefaultPersonal: Bool
    var createdAt: Date
    var updatedAt: Date
    var publishedAt: Date?

    init(
        ownerUserID: String,
        title: String,
        subtitle: String = "",
        summaryText: String = "",
        region: String = "",
        persona: String = "",
        sceneTags: [String] = [],
        visibility: CollectionVisibility = .private,
        status: CollectionStatus = .draft,
        moderationStatus: CollectionModerationStatus = .normal,
        coverImage: Data? = nil,
        contentRevision: Int = 1,
        reportCount: Int = 0,
        isFeatured: Bool = false,
        isDefaultPersonal: Bool = false,
        publishedAt: Date? = nil
    ) {
        self.id = UUID()
        self.ownerUserID = ownerUserID
        self.title = title
        self.subtitle = subtitle
        self.summaryText = summaryText
        self.region = region
        self.persona = persona
        self.sceneTags = sceneTags
        self.visibilityRaw = visibility.rawValue
        self.statusRaw = status.rawValue
        self.moderationStatusRaw = moderationStatus.rawValue
        self.coverImage = coverImage
        self.contentRevision = contentRevision
        self.reportCount = reportCount
        self.isFeatured = isFeatured
        self.isDefaultPersonal = isDefaultPersonal
        self.createdAt = Date()
        self.updatedAt = Date()
        self.publishedAt = publishedAt
    }

    var visibility: CollectionVisibility {
        get { CollectionVisibility(rawValue: visibilityRaw) ?? .private }
        set { visibilityRaw = newValue.rawValue }
    }

    var status: CollectionStatus {
        get { CollectionStatus(rawValue: statusRaw) ?? .draft }
        set { statusRaw = newValue.rawValue }
    }

    var moderationStatus: CollectionModerationStatus {
        get { CollectionModerationStatus(rawValue: moderationStatusRaw) ?? .normal }
        set { moderationStatusRaw = newValue.rawValue }
    }

    var isDiscoverable: Bool {
        visibility == .public && status == .published && moderationStatus == .normal
    }
}

@Model
final class WordCollectionEntry {
    @Attribute(.unique) var scopedKey: String
    var id: UUID
    var collectionID: UUID
    var ownerUserID: String
    var lexemeID: UUID
    var word: String
    var normalizedForm: String
    var chineseExplanation: String
    var exampleSentence: String
    var exampleSentenceChinese: String
    var sceneNote: String
    var sceneTagRaw: String
    var categoryName: String
    var sourceImageThumbnail: Data?
    var sourcePageTitle: String
    var scanSessionID: UUID?
    var displayOrder: Int
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        collectionID: UUID,
        ownerUserID: String,
        lexemeID: UUID,
        word: String,
        normalizedForm: String,
        chineseExplanation: String,
        exampleSentence: String,
        exampleSentenceChinese: String,
        sceneNote: String,
        sceneTag: SceneTag,
        categoryName: String,
        sourceImageThumbnail: Data? = nil,
        sourcePageTitle: String = "",
        scanSessionID: UUID? = nil,
        displayOrder: Int = 0,
        isArchived: Bool = false
    ) {
        self.id = UUID()
        self.collectionID = collectionID
        self.ownerUserID = ownerUserID
        self.lexemeID = lexemeID
        self.word = word
        self.normalizedForm = normalizedForm
        self.scopedKey = WordCollectionEntry.scopedKey(collectionID: collectionID, normalizedForm: normalizedForm)
        self.chineseExplanation = chineseExplanation
        self.exampleSentence = exampleSentence
        self.exampleSentenceChinese = exampleSentenceChinese
        self.sceneNote = sceneNote
        self.sceneTagRaw = sceneTag.rawValue
        self.categoryName = categoryName
        self.sourceImageThumbnail = sourceImageThumbnail
        self.sourcePageTitle = sourcePageTitle
        self.scanSessionID = scanSessionID
        self.displayOrder = displayOrder
        self.isArchived = isArchived
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var sceneTag: SceneTag {
        get { SceneTag(rawValue: sceneTagRaw) ?? .general }
        set { sceneTagRaw = newValue.rawValue }
    }

    static func scopedKey(collectionID: UUID, normalizedForm: String) -> String {
        "\(collectionID.uuidString)::\(normalizedForm)"
    }
}

@Model
final class CollectionSubscription {
    @Attribute(.unique) var subscriptionKey: String
    var userID: String
    var collectionID: UUID
    var subscribedAt: Date
    var lastSeenRevision: Int
    var isActive: Bool

    init(
        userID: String,
        collectionID: UUID,
        lastSeenRevision: Int = 0,
        isActive: Bool = true
    ) {
        self.userID = userID
        self.collectionID = collectionID
        self.subscriptionKey = CollectionSubscription.subscriptionKey(userID: userID, collectionID: collectionID)
        self.subscribedAt = Date()
        self.lastSeenRevision = lastSeenRevision
        self.isActive = isActive
    }

    static func subscriptionKey(userID: String, collectionID: UUID) -> String {
        "\(userID)::\(collectionID.uuidString)"
    }
}

@Model
final class UserWordState {
    @Attribute(.unique) var scopedKey: String
    var userID: String
    var lexemeID: UUID
    var normalizedForm: String
    var wordText: String
    var confidence: Double
    var evidenceCount: Int
    var easeFactor: Double
    var interval: Int
    var repetitions: Int
    var nextReviewDate: Date
    var lastReviewedAt: Date?
    var isMastered: Bool
    var addedToPersonalLibraryAt: Date?
    var updatedAt: Date

    init(
        userID: String,
        lexemeID: UUID,
        normalizedForm: String,
        wordText: String,
        confidence: Double = 0.25,
        evidenceCount: Int = 1,
        easeFactor: Double = 2.5,
        interval: Int = 1,
        repetitions: Int = 0,
        nextReviewDate: Date = Date(),
        lastReviewedAt: Date? = nil,
        isMastered: Bool = false,
        addedToPersonalLibraryAt: Date? = nil
    ) {
        self.userID = userID
        self.lexemeID = lexemeID
        self.normalizedForm = normalizedForm
        self.wordText = wordText
        self.scopedKey = UserWordState.scopedKey(userID: userID, normalizedForm: normalizedForm)
        self.confidence = confidence
        self.evidenceCount = evidenceCount
        self.easeFactor = easeFactor
        self.interval = interval
        self.repetitions = repetitions
        self.nextReviewDate = nextReviewDate
        self.lastReviewedAt = lastReviewedAt
        self.isMastered = isMastered
        self.addedToPersonalLibraryAt = addedToPersonalLibraryAt
        self.updatedAt = Date()
    }

    var isDueForReview: Bool {
        !isMastered && nextReviewDate <= Date()
    }

    static func scopedKey(userID: String, normalizedForm: String) -> String {
        "\(userID)::\(normalizedForm)"
    }
}

@Model
final class UserCollectionProgress {
    @Attribute(.unique) var scopedKey: String
    var userID: String
    var collectionID: UUID
    var startedAt: Date
    var lastStudiedAt: Date?
    var learnedEntryCount: Int
    var masteredEntryCount: Int
    var dueEntryCount: Int
    var completionRate: Double

    init(
        userID: String,
        collectionID: UUID,
        startedAt: Date = Date(),
        lastStudiedAt: Date? = nil,
        learnedEntryCount: Int = 0,
        masteredEntryCount: Int = 0,
        dueEntryCount: Int = 0,
        completionRate: Double = 0
    ) {
        self.userID = userID
        self.collectionID = collectionID
        self.scopedKey = UserCollectionProgress.scopedKey(userID: userID, collectionID: collectionID)
        self.startedAt = startedAt
        self.lastStudiedAt = lastStudiedAt
        self.learnedEntryCount = learnedEntryCount
        self.masteredEntryCount = masteredEntryCount
        self.dueEntryCount = dueEntryCount
        self.completionRate = completionRate
    }

    static func scopedKey(userID: String, collectionID: UUID) -> String {
        "\(userID)::\(collectionID.uuidString)"
    }
}
