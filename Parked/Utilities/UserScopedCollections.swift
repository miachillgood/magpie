//
//  UserScopedCollections.swift
//  SnapLingo
//

import Foundation

extension Sequence where Element == VocabWord {
    func owned(by userID: String?) -> [VocabWord] {
        guard let userID else { return [] }
        return filter { $0.ownerUserID == userID }
    }
}

extension Sequence where Element == ReviewSession {
    func owned(by userID: String?) -> [ReviewSession] {
        guard let userID else { return [] }
        return filter { $0.ownerUserID == userID }
    }
}

extension Sequence where Element == AppSettings {
    func firstOwned(by userID: String?) -> AppSettings? {
        guard let userID else { return nil }
        return first { $0.ownerUserID == userID }
    }
}

extension Sequence where Element == WordFamiliarity {
    func owned(by userID: String?) -> [WordFamiliarity] {
        guard let userID else { return [] }
        return filter { $0.ownerUserID == userID }
    }
}

extension Sequence where Element == UserProfile {
    func firstOwned(by userID: String?) -> UserProfile? {
        guard let userID else { return nil }
        return first { $0.appleUserID == userID }
    }
}

extension Sequence where Element == WordCollection {
    func owned(by userID: String?) -> [WordCollection] {
        guard let userID else { return [] }
        return filter { $0.ownerUserID == userID }
    }
}

extension Sequence where Element == CollectionSubscription {
    func owned(by userID: String?) -> [CollectionSubscription] {
        guard let userID else { return [] }
        return filter { $0.userID == userID && $0.isActive }
    }
}

extension Sequence where Element == UserWordState {
    func owned(by userID: String?) -> [UserWordState] {
        guard let userID else { return [] }
        return filter { $0.userID == userID }
    }
}

extension Sequence where Element == UserCollectionProgress {
    func owned(by userID: String?) -> [UserCollectionProgress] {
        guard let userID else { return [] }
        return filter { $0.userID == userID }
    }
}

extension Sequence where Element == CreatorProfile {
    func firstOwned(by userID: String?) -> CreatorProfile? {
        guard let userID else { return nil }
        return first { $0.userID == userID }
    }
}
