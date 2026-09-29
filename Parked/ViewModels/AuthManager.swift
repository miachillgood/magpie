//
//  AuthManager.swift
//  SnapLingo
//

import AuthenticationServices
import Foundation
import Observation
import SwiftData

struct AuthSession: Codable, Equatable {
    let appleUserID: String
    let displayName: String
    let email: String?
}

@MainActor
@Observable
final class AuthManager {
    private let legacyGuestUserID = "guest.local.snaplingo"
    private let legacyGuestDisplayName = "本机试用"
    private(set) var currentSession: AuthSession?
    private(set) var isRestoringSession = true
    private(set) var isAuthenticating = false
    var lastErrorMessage: String?

    var currentUserID: String? {
        currentSession?.appleUserID
    }

    var fallbackDisplayName: String {
        "Apple 用户"
    }

    func restoreSession() async {
        guard isRestoringSession else { return }

        guard let storedSession = KeychainHelper.loadAuthSession() else {
            currentSession = nil
            isRestoringSession = false
            return
        }

        if isLegacyGuestUserID(storedSession.appleUserID) {
            KeychainHelper.deleteAuthSession()
            currentSession = nil
            isRestoringSession = false
            return
        }

        let validation = await credentialState(for: storedSession.appleUserID)
        switch validation {
        case .success(.authorized):
            currentSession = storedSession
        case .success:
            KeychainHelper.deleteAuthSession()
            currentSession = nil
        case .failure:
            // 开发环境或模拟器下 credentialState 可能不可用，此时保留本地登录态。
            currentSession = storedSession
        }

        isRestoringSession = false
    }

    func beginAuthentication() {
        isAuthenticating = true
        lastErrorMessage = nil
    }

    func clearError() {
        lastErrorMessage = nil
    }

    func handleAppleSignIn(result: Result<ASAuthorization, Error>, context: ModelContext) {
        isAuthenticating = false

        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                lastErrorMessage = "未能读取 Apple 登录凭据。"
                return
            }

            do {
                try applySession(from: credential, context: context)
            } catch {
                lastErrorMessage = friendlyMessage(for: error)
            }

        case .failure(let error):
            let nsError = error as NSError
            if nsError.domain == ASAuthorizationError.errorDomain,
               nsError.code == ASAuthorizationError.canceled.rawValue {
                return
            }
            lastErrorMessage = friendlyMessage(for: error)
        }
    }

    func signOut() {
        KeychainHelper.deleteAuthSession()
        currentSession = nil
        lastErrorMessage = nil
    }

    func updateCurrentDisplayName(_ displayName: String) {
        guard let session = currentSession else { return }

        let updatedSession = AuthSession(
            appleUserID: session.appleUserID,
            displayName: displayName,
            email: session.email
        )
        currentSession = updatedSession
        KeychainHelper.saveAuthSession(updatedSession)
    }

    private func applySession(from credential: ASAuthorizationAppleIDCredential, context: ModelContext) throws {
        let appleUserID = credential.user
        let existingProfile = try fetchUserProfile(appleUserID: appleUserID, context: context)
        let guestProfile = try fetchUserProfile(appleUserID: legacyGuestUserID, context: context)
        let displayName = resolvedDisplayName(
            from: credential,
            existing: existingProfile,
            legacyGuestProfile: guestProfile
        )
        let email = credential.email ?? existingProfile?.email

        if let existingProfile {
            existingProfile.displayName = displayName
            existingProfile.email = email
            existingProfile.lastSignedInAt = Date()
        } else {
            context.insert(UserProfile(
                appleUserID: appleUserID,
                displayName: displayName,
                email: email
            ))
        }

        try migrateLegacyDataIfNeeded(to: appleUserID, context: context)
        try migrateLegacyGuestDataIfNeeded(to: appleUserID, context: context)
        _ = try LearningProfileStore.bootstrap(ownerUserID: appleUserID, context: context)
        try context.save()

        let session = AuthSession(
            appleUserID: appleUserID,
            displayName: displayName,
            email: email
        )
        KeychainHelper.saveAuthSession(session)
        currentSession = session
        isRestoringSession = false
    }

    private func resolvedDisplayName(
        from credential: ASAuthorizationAppleIDCredential,
        existing: UserProfile?,
        legacyGuestProfile: UserProfile?
    ) -> String {
        let parts = [credential.fullName?.givenName, credential.fullName?.familyName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if !parts.isEmpty {
            return parts.joined(separator: " ")
        }
        if let existingName = existing?.displayName, !existingName.isEmpty {
            return existingName
        }
        if let guestName = legacyGuestProfile?.displayName,
           !guestName.isEmpty,
           guestName != legacyGuestDisplayName {
            return guestName
        }
        if let email = credential.email, !email.isEmpty {
            return email
        }
        return "SnapLingo 用户"
    }

    private func fetchUserProfile(appleUserID: String, context: ModelContext) throws -> UserProfile? {
        let descriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate { profile in
                profile.appleUserID == appleUserID
            }
        )
        return try context.fetch(descriptor).first
    }

    private func migrateLegacyDataIfNeeded(to userID: String, context: ModelContext) throws {
        let legacyWords = try context.fetch(FetchDescriptor<VocabWord>(
            predicate: #Predicate { word in
                word.ownerUserID == nil
            }
        ))
        for word in legacyWords {
            word.ownerUserID = userID
        }

        let legacySessions = try context.fetch(FetchDescriptor<ReviewSession>(
            predicate: #Predicate { session in
                session.ownerUserID == nil
            }
        ))
        for session in legacySessions {
            session.ownerUserID = userID
        }

        let legacyFamiliarities = try context.fetch(FetchDescriptor<WordFamiliarity>(
            predicate: #Predicate { record in
                record.ownerUserID == nil
            }
        ))
        for record in legacyFamiliarities {
            record.ownerUserID = userID
            record.scopedKey = WordFamiliarity.scopedKey(
                ownerUserID: userID,
                normalizedForm: record.normalizedForm
            )
        }

        if try LearningProfileStore.fetchSettings(ownerUserID: userID, context: context) == nil {
            let legacySettings = try context.fetch(FetchDescriptor<AppSettings>(
                predicate: #Predicate { settings in
                    settings.ownerUserID == nil
                }
            ))
            legacySettings.first?.ownerUserID = userID
        }
    }

    private func migrateLegacyGuestDataIfNeeded(to userID: String, context: ModelContext) throws {
        guard userID != legacyGuestUserID else { return }

        try migrateGuestProfileIfNeeded(to: userID, context: context)
        let collectionIDRemap = try migrateGuestCollectionsIfNeeded(to: userID, context: context)
        try migrateGuestWordCollectionEntriesIfNeeded(to: userID, collectionIDRemap: collectionIDRemap, context: context)
        try migrateGuestSubscriptionsIfNeeded(to: userID, collectionIDRemap: collectionIDRemap, context: context)
        try migrateGuestProgressIfNeeded(to: userID, collectionIDRemap: collectionIDRemap, context: context)
        try migrateGuestWordStatesIfNeeded(to: userID, context: context)
        try migrateGuestFamiliaritiesIfNeeded(to: userID, context: context)
        try migrateGuestSettingsIfNeeded(to: userID, collectionIDRemap: collectionIDRemap, context: context)
        try migrateGuestWordsIfNeeded(to: userID, context: context)
        try migrateGuestReviewSessionsIfNeeded(to: userID, context: context)
        try migrateGuestCreatorProfileIfNeeded(to: userID, context: context)
        try removeGuestAccountsIfNeeded(context: context)
    }

    private func migrateGuestProfileIfNeeded(to userID: String, context: ModelContext) throws {
        guard let guestProfile = try fetchUserProfile(appleUserID: legacyGuestUserID, context: context) else {
            return
        }

        if let userProfile = try fetchUserProfile(appleUserID: userID, context: context),
           (userProfile.displayName.isEmpty || userProfile.displayName == "SnapLingo 用户"),
           guestProfile.displayName != legacyGuestDisplayName {
            userProfile.displayName = guestProfile.displayName
        }

        context.delete(guestProfile)
    }

    private func migrateGuestWordsIfNeeded(to userID: String, context: ModelContext) throws {
        let guestWords = try context.fetch(FetchDescriptor<VocabWord>()).filter { $0.ownerUserID == legacyGuestUserID }
        for word in guestWords {
            word.ownerUserID = userID
        }
    }

    private func migrateGuestReviewSessionsIfNeeded(to userID: String, context: ModelContext) throws {
        let guestSessions = try context.fetch(FetchDescriptor<ReviewSession>()).filter { $0.ownerUserID == legacyGuestUserID }
        for session in guestSessions {
            session.ownerUserID = userID
        }
    }

    private func migrateGuestFamiliaritiesIfNeeded(to userID: String, context: ModelContext) throws {
        let records = try context.fetch(FetchDescriptor<WordFamiliarity>())
        let guestRecords = records.filter { $0.ownerUserID == legacyGuestUserID }

        for record in guestRecords {
            if let existing = records.first(where: {
                $0 !== record && $0.ownerUserID == userID && $0.normalizedForm == record.normalizedForm
            }) {
                let totalConfidence =
                    (existing.confidence * Double(existing.evidenceCount)) +
                    (record.confidence * Double(record.evidenceCount))
                let totalEvidence = max(existing.evidenceCount + record.evidenceCount, 1)
                existing.evidenceCount = totalEvidence
                existing.confidence = totalConfidence / Double(totalEvidence)
                if record.updatedAt > existing.updatedAt {
                    existing.lastSource = record.lastSource
                }
                existing.updatedAt = max(existing.updatedAt, record.updatedAt)
                context.delete(record)
            } else {
                record.ownerUserID = userID
                record.scopedKey = WordFamiliarity.scopedKey(
                    ownerUserID: userID,
                    normalizedForm: record.normalizedForm
                )
            }
        }
    }

    private func migrateGuestSettingsIfNeeded(
        to userID: String,
        collectionIDRemap: [UUID: UUID],
        context: ModelContext
    ) throws {
        let settingsList = try context.fetch(FetchDescriptor<AppSettings>())
        guard let guestSettings = settingsList.first(where: { $0.ownerUserID == legacyGuestUserID }) else {
            return
        }

        let remappedCollectionID = guestSettings.lastUsedCollectionID.map { collectionIDRemap[$0] ?? $0 }

        if let userSettings = settingsList.first(where: { $0.ownerUserID == userID }) {
            if userSettings.lastUsedCollectionID == nil {
                userSettings.lastUsedCollectionID = remappedCollectionID
            }
            if userSettings.dailyReviewGoal == 20 && guestSettings.dailyReviewGoal != 20 {
                userSettings.dailyReviewGoal = guestSettings.dailyReviewGoal
            }
            userSettings.apiKeyConfigured = userSettings.apiKeyConfigured || guestSettings.apiKeyConfigured
            userSettings.onboardingCompleted = userSettings.onboardingCompleted || guestSettings.onboardingCompleted
            userSettings.totalWordsLearned = max(userSettings.totalWordsLearned, guestSettings.totalWordsLearned)

            let shouldUseGuestAssessment =
                userSettings.lastAssessmentAt == nil &&
                guestSettings.assessmentCompleted
                || ((guestSettings.lastAssessmentAt ?? .distantPast) > (userSettings.lastAssessmentAt ?? .distantPast))

            if shouldUseGuestAssessment {
                LearningProfileStore.applyProficiencyScore(
                    guestSettings.proficiencyScore,
                    to: userSettings,
                    assessmentCompleted: guestSettings.assessmentCompleted,
                    lastAssessmentAt: guestSettings.lastAssessmentAt
                )
            }

            context.delete(guestSettings)
        } else {
            guestSettings.ownerUserID = userID
            guestSettings.lastUsedCollectionID = remappedCollectionID
        }
    }

    private func migrateGuestCollectionsIfNeeded(to userID: String, context: ModelContext) throws -> [UUID: UUID] {
        let collections = try context.fetch(FetchDescriptor<WordCollection>())
        let guestCollections = collections.filter { $0.ownerUserID == legacyGuestUserID }
        guard !guestCollections.isEmpty else { return [:] }

        let guestDefault = guestCollections.first(where: { $0.isDefaultPersonal })
        let userDefault = collections.first(where: { $0.ownerUserID == userID && $0.isDefaultPersonal })
        var collectionIDRemap: [UUID: UUID] = [:]

        if let guestDefault {
            if let userDefault {
                collectionIDRemap[guestDefault.id] = userDefault.id
                context.delete(guestDefault)
            } else {
                guestDefault.ownerUserID = userID
                collectionIDRemap[guestDefault.id] = guestDefault.id
            }
        }

        for collection in guestCollections where collection.id != guestDefault?.id {
            collection.ownerUserID = userID
            collectionIDRemap[collection.id] = collection.id
        }

        return collectionIDRemap
    }

    private func migrateGuestWordCollectionEntriesIfNeeded(
        to userID: String,
        collectionIDRemap: [UUID: UUID],
        context: ModelContext
    ) throws {
        let entries = try context.fetch(FetchDescriptor<WordCollectionEntry>())
        let guestEntries = entries.filter { $0.ownerUserID == legacyGuestUserID }

        for entry in guestEntries {
            let targetCollectionID = collectionIDRemap[entry.collectionID] ?? entry.collectionID
            if let existing = entries.first(where: {
                $0 !== entry && $0.collectionID == targetCollectionID && $0.normalizedForm == entry.normalizedForm
            }) {
                if existing.sourceImageThumbnail == nil {
                    existing.sourceImageThumbnail = entry.sourceImageThumbnail
                }
                if existing.updatedAt < entry.updatedAt {
                    existing.word = entry.word
                    existing.chineseExplanation = entry.chineseExplanation
                    existing.exampleSentence = entry.exampleSentence
                    existing.exampleSentenceChinese = entry.exampleSentenceChinese
                    existing.sceneNote = entry.sceneNote
                    existing.sceneTag = entry.sceneTag
                    existing.categoryName = entry.categoryName
                    existing.sourcePageTitle = entry.sourcePageTitle
                    existing.scanSessionID = entry.scanSessionID ?? existing.scanSessionID
                    existing.updatedAt = entry.updatedAt
                }
                context.delete(entry)
            } else {
                entry.ownerUserID = userID
                if entry.collectionID != targetCollectionID {
                    entry.collectionID = targetCollectionID
                    entry.scopedKey = WordCollectionEntry.scopedKey(
                        collectionID: targetCollectionID,
                        normalizedForm: entry.normalizedForm
                    )
                }
            }
        }
    }

    private func migrateGuestSubscriptionsIfNeeded(
        to userID: String,
        collectionIDRemap: [UUID: UUID],
        context: ModelContext
    ) throws {
        let subscriptions = try context.fetch(FetchDescriptor<CollectionSubscription>())
        let guestSubscriptions = subscriptions.filter { $0.userID == legacyGuestUserID }

        for subscription in guestSubscriptions {
            let targetCollectionID = collectionIDRemap[subscription.collectionID] ?? subscription.collectionID
            if let existing = subscriptions.first(where: {
                $0 !== subscription && $0.userID == userID && $0.collectionID == targetCollectionID
            }) {
                existing.lastSeenRevision = max(existing.lastSeenRevision, subscription.lastSeenRevision)
                existing.isActive = existing.isActive || subscription.isActive
                context.delete(subscription)
            } else {
                subscription.userID = userID
                subscription.collectionID = targetCollectionID
                subscription.subscriptionKey = CollectionSubscription.subscriptionKey(
                    userID: userID,
                    collectionID: targetCollectionID
                )
            }
        }
    }

    private func migrateGuestWordStatesIfNeeded(to userID: String, context: ModelContext) throws {
        let states = try context.fetch(FetchDescriptor<UserWordState>())
        let guestStates = states.filter { $0.userID == legacyGuestUserID }

        for state in guestStates {
            if let existing = states.first(where: {
                $0 !== state && $0.userID == userID && $0.normalizedForm == state.normalizedForm
            }) {
                let preferredState = state.updatedAt > existing.updatedAt ? state : existing
                existing.wordText = preferredState.wordText
                existing.confidence = max(existing.confidence, state.confidence)
                existing.evidenceCount = max(existing.evidenceCount, state.evidenceCount)
                existing.easeFactor = preferredState.easeFactor
                existing.interval = preferredState.interval
                existing.repetitions = preferredState.repetitions
                existing.nextReviewDate = preferredState.nextReviewDate
                existing.lastReviewedAt = latest(existing.lastReviewedAt, state.lastReviewedAt)
                existing.isMastered = existing.isMastered || state.isMastered
                existing.addedToPersonalLibraryAt = earliest(existing.addedToPersonalLibraryAt, state.addedToPersonalLibraryAt)
                existing.updatedAt = max(existing.updatedAt, state.updatedAt)
                context.delete(state)
            } else {
                state.userID = userID
                state.scopedKey = UserWordState.scopedKey(
                    userID: userID,
                    normalizedForm: state.normalizedForm
                )
            }
        }
    }

    private func migrateGuestProgressIfNeeded(
        to userID: String,
        collectionIDRemap: [UUID: UUID],
        context: ModelContext
    ) throws {
        let progressList = try context.fetch(FetchDescriptor<UserCollectionProgress>())
        let guestProgress = progressList.filter { $0.userID == legacyGuestUserID }

        for progress in guestProgress {
            let targetCollectionID = collectionIDRemap[progress.collectionID] ?? progress.collectionID
            if let existing = progressList.first(where: {
                $0 !== progress && $0.userID == userID && $0.collectionID == targetCollectionID
            }) {
                existing.startedAt = min(existing.startedAt, progress.startedAt)
                existing.lastStudiedAt = latest(existing.lastStudiedAt, progress.lastStudiedAt)
                existing.learnedEntryCount = max(existing.learnedEntryCount, progress.learnedEntryCount)
                existing.masteredEntryCount = max(existing.masteredEntryCount, progress.masteredEntryCount)
                existing.dueEntryCount = max(existing.dueEntryCount, progress.dueEntryCount)
                existing.completionRate = max(existing.completionRate, progress.completionRate)
                context.delete(progress)
            } else {
                progress.userID = userID
                progress.collectionID = targetCollectionID
                progress.scopedKey = UserCollectionProgress.scopedKey(
                    userID: userID,
                    collectionID: targetCollectionID
                )
            }
        }
    }

    private func migrateGuestCreatorProfileIfNeeded(to userID: String, context: ModelContext) throws {
        let creators = try context.fetch(FetchDescriptor<CreatorProfile>())
        guard let guestCreator = creators.first(where: { $0.userID == legacyGuestUserID }) else {
            return
        }

        if let existing = creators.first(where: { $0.userID == userID }) {
            if existing.bio.isEmpty { existing.bio = guestCreator.bio }
            if existing.region.isEmpty { existing.region = guestCreator.region }
            if existing.persona.isEmpty { existing.persona = guestCreator.persona }
            existing.updatedAt = max(existing.updatedAt, guestCreator.updatedAt)
            context.delete(guestCreator)
        } else {
            guestCreator.userID = userID
        }
    }

    private func removeGuestAccountsIfNeeded(context: ModelContext) throws {
        let accounts = try context.fetch(FetchDescriptor<UserAccount>())
        for account in accounts where account.userID == legacyGuestUserID {
            context.delete(account)
        }
    }

    private func credentialState(
        for userID: String
    ) async -> Result<ASAuthorizationAppleIDProvider.CredentialState, Error> {
        await withCheckedContinuation { continuation in
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: userID) { state, error in
                if let error {
                    continuation.resume(returning: .failure(error))
                } else {
                    continuation.resume(returning: .success(state))
                }
            }
        }
    }

    private func isLegacyGuestUserID(_ userID: String) -> Bool {
        userID == legacyGuestUserID
    }

    private func latest(_ lhs: Date?, _ rhs: Date?) -> Date? {
        switch (lhs, rhs) {
        case let (left?, right?):
            return max(left, right)
        case (nil, let right?):
            return right
        case (let left?, nil):
            return left
        case (nil, nil):
            return nil
        }
    }

    private func earliest(_ lhs: Date?, _ rhs: Date?) -> Date? {
        switch (lhs, rhs) {
        case let (left?, right?):
            return min(left, right)
        case (nil, let right?):
            return right
        case (let left?, nil):
            return left
        case (nil, nil):
            return nil
        }
    }

    private func friendlyMessage(for error: Error) -> String {
        let nsError = error as NSError

        switch classifiedAppleSignInIssue(for: nsError) {
        case .missingCapability:
            return "当前构建没有正确启用 Apple 登录能力，请检查签名配置，并确认目标已使用 SnapLingo.entitlements。"
        case .environment:
            return "模拟器或设备上的 Apple 账号状态暂时不可用。请改用真机，并检查系统设置中的 Apple 账号后再试。"
        case .none:
            break
        }

        if nsError.domain == ASAuthorizationError.errorDomain,
           let code = ASAuthorizationError.Code(rawValue: nsError.code) {
            switch code {
            case .failed:
                return "Apple 登录暂时没完成，请稍后重试。"
            case .invalidResponse:
                return "Apple 登录返回了无效结果，请重试一次。"
            case .notHandled:
                return "这次 Apple 登录没有完成，请重试。"
            case .unknown:
                return "Apple 登录返回了未知结果。请再试一次。"
            case .canceled:
                return "你取消了 Apple 登录。"
            case .notInteractive:
                return "当前环境暂时无法弹出 Apple 登录界面，请改用真机后再试。"
            case .matchedExcludedCredential:
                return "当前 Apple 账号暂时不可用，请换一个账号后再试。"
            case .credentialImport:
                return "Apple 登录凭据导入失败，请稍后重试。"
            default:
                return "Apple 登录失败，请稍后重试。"
            }
        }

        let message = nsError.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if message == "The operation couldn’t be completed." || message == "The operation could not be completed." {
            return "系统操作没有成功完成。请检查当前构建的 Apple 登录能力和设备上的 Apple 账号状态。"
        }

        return message
    }

    private func classifiedAppleSignInIssue(for error: NSError) -> AppleSignInIssue? {
        if let hasEntitlement = hasAppleSignInEntitlement(), !hasEntitlement {
            return .missingCapability
        }

        if error.domain == ASAuthorizationError.errorDomain,
           let code = ASAuthorizationError.Code(rawValue: error.code) {
            switch code {
            case .failed, .unknown, .notInteractive, .matchedExcludedCredential:
                return .environment
            case .invalidResponse, .notHandled, .canceled, .credentialImport:
                break
            default:
                break
            }
        }

        let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if message == "The operation couldn’t be completed." || message == "The operation could not be completed." {
            return isRunningOnSimulator ? .environment : nil
        }

        return nil
    }

    private func hasAppleSignInEntitlement() -> Bool? {
#if targetEnvironment(simulator)
        nil
#else
        guard let profileURL = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let profileData = try? Data(contentsOf: profileURL),
              let profileText = String(data: profileData, encoding: .ascii),
              let plistStart = profileText.range(of: "<?xml"),
              let plistEnd = profileText.range(of: "</plist>") else {
            return nil
        }

        let plistText = String(profileText[plistStart.lowerBound..<plistEnd.upperBound])
        guard let plistData = plistText.data(using: .utf8),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
              let entitlements = plist["Entitlements"] as? [String: Any] else {
            return nil
        }

        let value = entitlements["com.apple.developer.applesignin"]

        if let entries = value as? [String] {
            return entries.contains("Default")
        }

        if let entry = value as? String {
            return !entry.isEmpty
        }

        return true
#endif
    }

    private var isRunningOnSimulator: Bool {
#if targetEnvironment(simulator)
        true
#else
        false
#endif
    }
}

extension AuthManager {
    static var previewSignedIn: AuthManager {
        let manager = AuthManager()
        manager.currentSession = AuthSession(
            appleUserID: "preview-user",
            displayName: "预览用户",
            email: "preview@snaplingo.app"
        )
        manager.isRestoringSession = false
        return manager
    }
}

private enum AppleSignInIssue {
    case missingCapability
    case environment
}
