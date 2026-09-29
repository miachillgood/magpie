//
//  CollectionStore.swift
//  SnapLingo
//

import Foundation
import SwiftData

enum CollectionStore {
    static let defaultCollectionTitle = "我的词库"
    private static let demoOwnerPrefix = "demo."

    static func bootstrap(
        ownerUserID: String?,
        displayName: String?,
        email: String?,
        context: ModelContext
    ) throws {
        try installDemoCatalogIfNeeded(context: context)

        guard let ownerUserID else { return }

        try ensureAccount(
            userID: ownerUserID,
            displayName: displayName ?? "SnapLingo 用户",
            email: email,
            provider: inferredProvider(for: ownerUserID),
            context: context
        )

        let defaultCollection = try ensureDefaultCollection(ownerUserID: ownerUserID, context: context)
        try ensureLastUsedCollection(ownerUserID: ownerUserID, fallbackCollectionID: defaultCollection.id, context: context)
        try migrateLegacyWords(ownerUserID: ownerUserID, defaultCollectionID: defaultCollection.id, context: context)
        try refreshProgressForAllCollections(ownerUserID: ownerUserID, context: context)
    }

    static func ensureDefaultCollection(ownerUserID: String, context: ModelContext) throws -> WordCollection {
        let collections = try context.fetch(FetchDescriptor<WordCollection>())
        if let existing = collections.first(where: { $0.ownerUserID == ownerUserID && $0.isDefaultPersonal }) {
            return existing
        }

        let collection = WordCollection(
            ownerUserID: ownerUserID,
            title: defaultCollectionTitle,
            subtitle: "个人词库",
            summaryText: "自动收纳你保存进个人学习系统的单词。",
            visibility: .private,
            status: .draft,
            isDefaultPersonal: true
        )
        context.insert(collection)
        return collection
    }

    static func recommendedCollectionID(
        ownerUserID: String?,
        settings: AppSettings?,
        collections: [WordCollection]
    ) -> UUID? {
        guard let ownerUserID else { return nil }

        if let preferred = settings?.lastUsedCollectionID,
           collections.contains(where: { $0.ownerUserID == ownerUserID && $0.id == preferred && $0.status != .archived }) {
            return preferred
        }

        return collections.first(where: { $0.ownerUserID == ownerUserID && $0.isDefaultPersonal })?.id
            ?? collections.first(where: { $0.ownerUserID == ownerUserID && $0.status != .archived })?.id
    }

    static func setLastUsedCollection(
        collectionID: UUID,
        ownerUserID: String?,
        context: ModelContext
    ) throws {
        guard let ownerUserID,
              let settings = try LearningProfileStore.ensureSettings(ownerUserID: ownerUserID, context: context) else {
            return
        }
        settings.lastUsedCollectionID = collectionID
    }

    @discardableResult
    static func saveOwnedWordToCollection(
        collectionID: UUID,
        ownerUserID: String,
        word: String,
        chineseExplanation: String,
        exampleSentence: String,
        exampleSentenceChinese: String,
        sceneNote: String,
        sceneTag: SceneTag,
        categoryName: String,
        sourceImageThumbnail: Data?,
        sourcePageTitle: String,
        scanSessionID: UUID?,
        context: ModelContext
    ) throws -> WordCollectionEntry {
        let normalized = word.normalizedVocabularyForm
        let lexeme = try upsertLexeme(word: word, normalizedForm: normalized, context: context)
        let entryKey = WordCollectionEntry.scopedKey(collectionID: collectionID, normalizedForm: normalized)
        let entries = try context.fetch(FetchDescriptor<WordCollectionEntry>())
        let collections = try context.fetch(FetchDescriptor<WordCollection>())

        let entry: WordCollectionEntry
        if let existing = entries.first(where: { $0.scopedKey == entryKey }) {
            existing.word = word
            existing.lexemeID = lexeme.id
            existing.chineseExplanation = chineseExplanation
            existing.exampleSentence = exampleSentence
            existing.exampleSentenceChinese = exampleSentenceChinese
            existing.sceneNote = sceneNote
            existing.sceneTag = sceneTag
            existing.categoryName = categoryName
            existing.sourceImageThumbnail = sourceImageThumbnail ?? existing.sourceImageThumbnail
            existing.sourcePageTitle = sourcePageTitle
            existing.scanSessionID = scanSessionID ?? existing.scanSessionID
            existing.updatedAt = Date()
            existing.isArchived = false
            entry = existing
        } else {
            let order = entries.filter { $0.collectionID == collectionID }.count
            let created = WordCollectionEntry(
                collectionID: collectionID,
                ownerUserID: ownerUserID,
                lexemeID: lexeme.id,
                word: word,
                normalizedForm: normalized,
                chineseExplanation: chineseExplanation,
                exampleSentence: exampleSentence,
                exampleSentenceChinese: exampleSentenceChinese,
                sceneNote: sceneNote,
                sceneTag: sceneTag,
                categoryName: categoryName,
                sourceImageThumbnail: sourceImageThumbnail,
                sourcePageTitle: sourcePageTitle,
                scanSessionID: scanSessionID,
                displayOrder: order
            )
            context.insert(created)
            entry = created
        }

        _ = try ensureUserWordState(
            ownerUserID: ownerUserID,
            lexeme: lexeme,
            displayWord: word,
            context: context
        )

        if let collection = collections.first(where: { $0.id == collectionID }) {
            if collection.coverImage == nil {
                collection.coverImage = sourceImageThumbnail
            }
            bumpRevision(collection)
            try refreshCollectionProgress(collectionID: collectionID, userID: ownerUserID, context: context)
        }

        return entry
    }

    static func addEntryToPersonalLibraryIfNeeded(
        entry: WordCollectionEntry,
        userID: String?,
        context: ModelContext
    ) throws {
        guard let userID else { return }

        let words = try context.fetch(FetchDescriptor<VocabWord>())
        if words.contains(where: { $0.ownerUserID == userID && $0.normalizedForm == entry.normalizedForm }) {
            if let state = try existingUserWordState(userID: userID, normalizedForm: entry.normalizedForm, context: context),
               state.addedToPersonalLibraryAt == nil {
                state.addedToPersonalLibraryAt = Date()
                state.updatedAt = Date()
            }
            return
        }

        let vocab = VocabWord(
            word: entry.word,
            chineseExplanation: entry.chineseExplanation,
            exampleSentence: entry.exampleSentence,
            exampleSentenceChinese: entry.exampleSentenceChinese,
            sceneNote: entry.sceneNote,
            sceneTag: entry.sceneTag,
            scanSessionID: entry.scanSessionID ?? UUID(),
            categoryName: entry.categoryName,
            ownerUserID: userID
        )
        vocab.sourceImageThumbnail = entry.sourceImageThumbnail
        context.insert(vocab)

        if let state = try existingUserWordState(userID: userID, normalizedForm: entry.normalizedForm, context: context) {
            state.addedToPersonalLibraryAt = Date()
            state.updatedAt = Date()
        }
    }

    static func subscribe(
        userID: String?,
        collection: WordCollection,
        context: ModelContext
    ) throws {
        guard let userID, collection.ownerUserID != userID else { return }

        let subscriptions = try context.fetch(FetchDescriptor<CollectionSubscription>())
        let key = CollectionSubscription.subscriptionKey(userID: userID, collectionID: collection.id)
        if let existing = subscriptions.first(where: { $0.subscriptionKey == key }) {
            existing.isActive = true
            existing.lastSeenRevision = collection.contentRevision
            return
        }

        let subscription = CollectionSubscription(
            userID: userID,
            collectionID: collection.id,
            lastSeenRevision: collection.contentRevision
        )
        context.insert(subscription)
        try refreshCollectionProgress(collectionID: collection.id, userID: userID, context: context)
    }

    static func ensureUserWordState(
        for entry: WordCollectionEntry,
        userID: String,
        context: ModelContext
    ) throws -> UserWordState {
        let lexemes = try context.fetch(FetchDescriptor<Lexeme>())
        let lexeme: Lexeme
        if let existing = lexemes.first(where: { $0.id == entry.lexemeID }) {
            lexeme = existing
        } else {
            lexeme = try upsertLexeme(
                word: entry.word,
                normalizedForm: entry.normalizedForm,
                context: context
            )
        }

        return try ensureUserWordState(
            ownerUserID: userID,
            lexeme: lexeme,
            displayWord: entry.word,
            context: context
        )
    }

    static func unsubscribe(
        userID: String?,
        collectionID: UUID,
        context: ModelContext
    ) throws {
        guard let userID else { return }
        let subscriptions = try context.fetch(FetchDescriptor<CollectionSubscription>())
        if let existing = subscriptions.first(where: {
            $0.userID == userID && $0.collectionID == collectionID && $0.isActive
        }) {
            existing.isActive = false
        }
    }

    static func refreshCollectionProgress(
        collectionID: UUID,
        userID: String,
        context: ModelContext
    ) throws {
        let entries = try context.fetch(FetchDescriptor<WordCollectionEntry>())
            .filter { $0.collectionID == collectionID && !$0.isArchived }
        let states = try context.fetch(FetchDescriptor<UserWordState>())
            .filter { $0.userID == userID }

        let progressKey = UserCollectionProgress.scopedKey(userID: userID, collectionID: collectionID)
        let progressList = try context.fetch(FetchDescriptor<UserCollectionProgress>())
        let progress = progressList.first(where: { $0.scopedKey == progressKey })
            ?? {
                let created = UserCollectionProgress(userID: userID, collectionID: collectionID)
                context.insert(created)
                return created
            }()

        let stateByNormalized = Dictionary(uniqueKeysWithValues: states.map { ($0.normalizedForm, $0) })
        let matchedStates = entries.compactMap { stateByNormalized[$0.normalizedForm] }
        let learnedCount = matchedStates.filter { $0.repetitions > 0 || $0.addedToPersonalLibraryAt != nil }.count
        let masteredCount = matchedStates.filter(\.isMastered).count
        let dueCount = matchedStates.filter(\.isDueForReview).count
        let completion = entries.isEmpty ? 0 : Double(learnedCount) / Double(entries.count)

        progress.learnedEntryCount = learnedCount
        progress.masteredEntryCount = masteredCount
        progress.dueEntryCount = dueCount
        progress.completionRate = completion
        progress.lastStudiedAt = matchedStates.compactMap(\.lastReviewedAt).max()
    }

    static func refreshProgressForAllCollections(
        ownerUserID: String,
        context: ModelContext
    ) throws {
        let collections = try context.fetch(FetchDescriptor<WordCollection>())
        let subscriptions = try context.fetch(FetchDescriptor<CollectionSubscription>())

        let subscribedIDs = Set(
            subscriptions
                .filter { $0.userID == ownerUserID && $0.isActive }
                .map(\.collectionID)
        )
        let visibleCollectionIDs = Set(
            collections
                .filter { $0.ownerUserID == ownerUserID || subscribedIDs.contains($0.id) }
                .map(\.id)
        )

        for collectionID in visibleCollectionIDs {
            try refreshCollectionProgress(collectionID: collectionID, userID: ownerUserID, context: context)
        }
    }

    private static func migrateLegacyWords(
        ownerUserID: String,
        defaultCollectionID: UUID,
        context: ModelContext
    ) throws {
        let legacyWords = try context.fetch(FetchDescriptor<VocabWord>())
            .filter { $0.ownerUserID == ownerUserID }

        for word in legacyWords {
            let lexeme = try upsertLexeme(
                word: word.word,
                normalizedForm: word.normalizedForm,
                context: context
            )
            _ = try ensureUserWordState(
                ownerUserID: ownerUserID,
                lexeme: lexeme,
                displayWord: word.word,
                sourceWord: word,
                context: context
            )

            let existing = try context.fetch(FetchDescriptor<WordCollectionEntry>())
                .contains { $0.collectionID == defaultCollectionID && $0.normalizedForm == word.normalizedForm }
            if existing { continue }

            let entry = WordCollectionEntry(
                collectionID: defaultCollectionID,
                ownerUserID: ownerUserID,
                lexemeID: lexeme.id,
                word: word.word,
                normalizedForm: word.normalizedForm,
                chineseExplanation: word.chineseExplanation,
                exampleSentence: word.exampleSentence,
                exampleSentenceChinese: word.exampleSentenceChinese,
                sceneNote: word.sceneNote,
                sceneTag: word.sceneTag,
                categoryName: word.categoryName,
                sourceImageThumbnail: word.sourceImageThumbnail,
                sourcePageTitle: word.categoryName,
                scanSessionID: word.scanSessionID
            )
            context.insert(entry)
        }
    }

    private static func ensureAccount(
        userID: String,
        displayName: String,
        email: String?,
        provider: AccountProvider,
        context: ModelContext
    ) throws {
        let accounts = try context.fetch(FetchDescriptor<UserAccount>())
        if let existing = accounts.first(where: { $0.userID == userID }) {
            existing.primaryProvider = provider
            existing.providerUserID = userID
            existing.email = email ?? existing.email
            existing.updatedAt = Date()
        } else {
            context.insert(UserAccount(
                userID: userID,
                primaryProvider: provider,
                providerUserID: userID,
                email: email
            ))
        }

        let creators = try context.fetch(FetchDescriptor<CreatorProfile>())
        if let existing = creators.first(where: { $0.userID == userID }) {
            existing.displayName = displayName
            existing.updatedAt = Date()
        } else {
            context.insert(CreatorProfile(userID: userID, displayName: displayName))
        }
    }

    private static func ensureLastUsedCollection(
        ownerUserID: String,
        fallbackCollectionID: UUID,
        context: ModelContext
    ) throws {
        guard let settings = try LearningProfileStore.ensureSettings(ownerUserID: ownerUserID, context: context) else {
            return
        }
        if settings.lastUsedCollectionID == nil {
            settings.lastUsedCollectionID = fallbackCollectionID
        }
    }

    private static func upsertLexeme(
        word: String,
        normalizedForm: String,
        context: ModelContext
    ) throws -> Lexeme {
        let lexemes = try context.fetch(FetchDescriptor<Lexeme>())
        if let existing = lexemes.first(where: { $0.normalizedForm == normalizedForm }) {
            existing.canonicalWord = word
            existing.updatedAt = Date()
            return existing
        }

        let lexeme = Lexeme(word: word, normalizedForm: normalizedForm)
        context.insert(lexeme)
        return lexeme
    }

    private static func ensureUserWordState(
        ownerUserID: String,
        lexeme: Lexeme,
        displayWord: String,
        sourceWord: VocabWord? = nil,
        context: ModelContext
    ) throws -> UserWordState {
        if let existing = try existingUserWordState(
            userID: ownerUserID,
            normalizedForm: lexeme.normalizedForm,
            context: context
        ) {
            if let sourceWord {
                existing.easeFactor = sourceWord.easeFactor
                existing.interval = sourceWord.interval
                existing.repetitions = sourceWord.repetitions
                existing.nextReviewDate = sourceWord.nextReviewDate
                existing.lastReviewedAt = sourceWord.lastReviewedAt
                existing.isMastered = sourceWord.isMastered
                existing.addedToPersonalLibraryAt = existing.addedToPersonalLibraryAt ?? sourceWord.addedAt
                existing.updatedAt = Date()
            }
            return existing
        }

        let familiarity = try context.fetch(FetchDescriptor<WordFamiliarity>())
            .first {
                $0.scopedKey == WordFamiliarity.scopedKey(
                    ownerUserID: ownerUserID,
                    normalizedForm: lexeme.normalizedForm
                )
            }

        let state = UserWordState(
            userID: ownerUserID,
            lexemeID: lexeme.id,
            normalizedForm: lexeme.normalizedForm,
            wordText: displayWord,
            confidence: familiarity?.confidence ?? 0.25,
            evidenceCount: familiarity?.evidenceCount ?? 1,
            easeFactor: sourceWord?.easeFactor ?? 2.5,
            interval: sourceWord?.interval ?? 1,
            repetitions: sourceWord?.repetitions ?? 0,
            nextReviewDate: sourceWord?.nextReviewDate ?? Date(),
            lastReviewedAt: sourceWord?.lastReviewedAt,
            isMastered: sourceWord?.isMastered ?? false,
            addedToPersonalLibraryAt: sourceWord?.addedAt
        )
        context.insert(state)
        return state
    }

    static func publish(_ collection: WordCollection) {
        collection.visibility = .public
        collection.status = .published
        collection.publishedAt = collection.publishedAt ?? Date()
        collection.updatedAt = Date()
        collection.contentRevision += 1
    }

    static func makePrivate(_ collection: WordCollection) {
        collection.visibility = .private
        collection.status = .draft
        collection.updatedAt = Date()
        collection.contentRevision += 1
    }

    static func archive(_ collection: WordCollection) {
        collection.status = .archived
        collection.updatedAt = Date()
        collection.contentRevision += 1
    }

    static func existingUserWordState(
        userID: String,
        normalizedForm: String,
        context: ModelContext
    ) throws -> UserWordState? {
        let stateKey = UserWordState.scopedKey(userID: userID, normalizedForm: normalizedForm)
        return try context.fetch(FetchDescriptor<UserWordState>())
            .first(where: { $0.scopedKey == stateKey })
    }

    private static func inferredProvider(for userID: String) -> AccountProvider {
        userID.hasPrefix("guest.") ? .guest : .apple
    }

    private static func bumpRevision(_ collection: WordCollection) {
        collection.contentRevision += 1
        collection.updatedAt = Date()
        if collection.visibility == .public && collection.status != .archived {
            collection.status = .published
            collection.publishedAt = collection.publishedAt ?? Date()
        }
    }

    private static func installDemoCatalogIfNeeded(context: ModelContext) throws {
        let collections = try context.fetch(FetchDescriptor<WordCollection>())
        if collections.contains(where: { $0.ownerUserID.hasPrefix(demoOwnerPrefix) }) {
            return
        }

        let creators = [
            (
                userID: "demo.nz.waiter",
                displayName: "NZ 菜单采词员",
                region: "新西兰",
                persona: "餐厅服务员",
                title: "新西兰餐厅菜单英语",
                subtitle: "常见菜单与点单词汇",
                summary: "围绕餐厅打工和日常点单，把最常见的菜单词和对话词放在一起。",
                sceneTags: [SceneTag.restaurant.rawValue, SceneTag.signage.rawValue],
                words: [
                    demoEntry("starter", "前菜", "Would you like a starter before your main?", "你想先来一份前菜吗？", "菜单里常见的前菜栏目。", sceneTag: .restaurant),
                    demoEntry("dine-in", "堂食", "This menu is for dine-in customers only.", "这份菜单仅供堂食顾客使用。", "门口和点单页常见。", sceneTag: .restaurant),
                    demoEntry("allergy", "过敏", "Please tell us if you have any allergy.", "如果你有过敏情况请告诉我们。", "服务员确认顾客忌口时常见。", sceneTag: .restaurant),
                    demoEntry("surcharge", "附加费", "A public holiday surcharge may apply.", "节假日可能会加收附加费。", "新西兰餐厅公告里很常见。", sceneTag: .signage)
                ]
            ),
            (
                userID: "demo.nz.student",
                displayName: "新西兰学生生活词书",
                region: "新西兰",
                persona: "学生",
                title: "学生租房与校园英语",
                subtitle: "看房、租房、学校邮件",
                summary: "把学生最常见的看房、租房、邮件沟通词放在一个词书里。",
                sceneTags: [SceneTag.housing.rawValue, SceneTag.campus.rawValue],
                words: [
                    demoEntry("bond", "押金", "The bond will be lodged after you sign the tenancy.", "签约后押金会被登记。", "新西兰租房文件里高频出现。", sceneTag: .housing),
                    demoEntry("tenancy", "租约", "Please read the tenancy agreement carefully.", "请仔细阅读租约。", "租房合同的核心词。", sceneTag: .housing),
                    demoEntry("deadline", "截止日期", "Submit the assignment before the deadline.", "请在截止日期前提交作业。", "学校邮件里高频。", sceneTag: .campus),
                    demoEntry("enrolment", "注册入学", "Your enrolment has been approved.", "你的注册入学已经通过。", "学校系统和邮件里很常见。", sceneTag: .campus)
                ]
            )
        ]

        for creator in creators {
            try ensureAccount(
                userID: creator.userID,
                displayName: creator.displayName,
                email: nil,
                provider: .social,
                context: context
            )

            if let profile = try context.fetch(FetchDescriptor<CreatorProfile>())
                .first(where: { $0.userID == creator.userID }) {
                profile.region = creator.region
                profile.persona = creator.persona
                profile.bio = creator.summary
            }

            let collection = WordCollection(
                ownerUserID: creator.userID,
                title: creator.title,
                subtitle: creator.subtitle,
                summaryText: creator.summary,
                region: creator.region,
                persona: creator.persona,
                sceneTags: creator.sceneTags,
                visibility: .public,
                status: .published,
                isFeatured: true,
                publishedAt: Date()
            )
            context.insert(collection)

            for (index, item) in creator.words.enumerated() {
                let lexeme = try upsertLexeme(
                    word: item.word,
                    normalizedForm: item.word.normalizedVocabularyForm,
                    context: context
                )
                let entry = WordCollectionEntry(
                    collectionID: collection.id,
                    ownerUserID: creator.userID,
                    lexemeID: lexeme.id,
                    word: item.word,
                    normalizedForm: item.word.normalizedVocabularyForm,
                    chineseExplanation: item.chineseExplanation,
                    exampleSentence: item.exampleSentence,
                    exampleSentenceChinese: item.exampleSentenceChinese,
                    sceneNote: item.sceneNote,
                    sceneTag: item.sceneTag,
                    categoryName: creator.title,
                    sourcePageTitle: creator.title,
                    displayOrder: index
                )
                context.insert(entry)
            }
        }
    }

    private static func demoEntry(
        _ word: String,
        _ chineseExplanation: String,
        _ exampleSentence: String,
        _ exampleSentenceChinese: String,
        _ sceneNote: String,
        sceneTag: SceneTag = .general
    ) -> DemoCollectionEntry {
        DemoCollectionEntry(
            word: word,
            chineseExplanation: chineseExplanation,
            exampleSentence: exampleSentence,
            exampleSentenceChinese: exampleSentenceChinese,
            sceneNote: sceneNote,
            sceneTag: sceneTag
        )
    }
}

private struct DemoCollectionEntry {
    let word: String
    let chineseExplanation: String
    let exampleSentence: String
    let exampleSentenceChinese: String
    let sceneNote: String
    let sceneTag: SceneTag
}
