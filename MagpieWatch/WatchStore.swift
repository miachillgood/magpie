//
//  WatchStore.swift
//  MagpieWatch
//
//  手表这一头的同步：收手机发来的今天的卡片（存一份在手表上，手机不在身边也能复习），
//  评过的卡记在本地并发回手机。排期由手机算，手表不改任何复习安排。
//

import Foundation
import WatchConnectivity

@Observable
final class WatchStore: NSObject, WCSessionDelegate {
    static let shared = WatchStore()

    private(set) var snapshot: WatchSnapshot?
    /// 今天已经评过的卡：复习到一半退出，回来接着做；手机发来新计划前也不会重复出现
    private(set) var done: Set<UUID> = []

    private let defaults = UserDefaults.standard
    private static let snapshotKey = "watchSnapshot"
    private static let doneKey = "watchDone"
    private static let doneDayKey = "watchDoneDay"

    /// 今天还没评过的卡
    var remaining: [WatchCard] {
        guard let snapshot, snapshot.isCurrent() else { return [] }
        return snapshot.cards.filter { !done.contains($0.id) }
    }

    var hasTodaysPlan: Bool { snapshot?.isCurrent() == true }

    func start() {
        snapshot = WatchSync.decode(WatchSnapshot.self, from: defaults.data(forKey: Self.snapshotKey))
        loadDone()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// 评一张卡（只有每张卡第一次的评分会发回手机）
    func record(_ card: WatchCard, success: Bool, at date: Date = Date()) {
        resetDoneIfNewDay(date)
        done.insert(card.id)
        saveDone(day: date)
        let rating = WatchRating(id: UUID(), wordID: card.id, ratingRaw: success ? 4 : 0, reviewedAt: date)
        guard let data = WatchSync.encode(rating), WCSession.isSupported() else { return }
        let session = WCSession.default
        let payload = [WatchSync.ratingKey: data]
        // 手机在旁边：马上送到，手机上的进度立刻更新；
        // 不在旁边或没送到：交给系统排队，连上之后再送（同一条送到两次手机只记一次）
        guard session.isReachable else {
            session.transferUserInfo(payload)
            return
        }
        session.sendMessage(payload, replyHandler: nil) { _ in
            session.transferUserInfo(payload)
        }
    }

    private func apply(_ context: [String: Any]) {
        guard let data = context[WatchSync.snapshotKey] as? Data,
              let snapshot = WatchSync.decode(WatchSnapshot.self, from: data)
        else { return }
        self.snapshot = snapshot
        defaults.set(data, forKey: Self.snapshotKey)
        resetDoneIfNewDay(Date())
    }

    // MARK: - 本地记录

    private func loadDone() {
        let ids = defaults.stringArray(forKey: Self.doneKey) ?? []
        done = Set(ids.compactMap(UUID.init(uuidString:)))
        resetDoneIfNewDay(Date())
    }

    private func saveDone(day: Date) {
        defaults.set(done.map(\.uuidString), forKey: Self.doneKey)
        defaults.set(Calendar.current.startOfDay(for: day), forKey: Self.doneDayKey)
    }

    private func resetDoneIfNewDay(_ now: Date) {
        guard let day = defaults.object(forKey: Self.doneDayKey) as? Date,
              !Calendar.current.isDate(day, inSameDayAs: now)
        else { return }
        done = []
        saveDone(day: now)
    }

    // MARK: - WCSessionDelegate

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        guard let data = session.receivedApplicationContext[WatchSync.snapshotKey] as? Data else { return }
        Task { @MainActor in self.apply([WatchSync.snapshotKey: data]) }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let data = applicationContext[WatchSync.snapshotKey] as? Data else { return }
        Task { @MainActor in self.apply([WatchSync.snapshotKey: data]) }
    }
}
