//
//  WatchBridge.swift
//  SnapLingo
//
//  手机这一头的手表同步（数据格式见 Shared/WatchSync.swift）：
//  - 今天的计划一变（StudyReminder.refresh 里调用）就把卡片发给手表
//  - 收到手表上的评分，用和手机复习同一套逻辑记下（ReviewApplier），再把新的计划发回去
//

import Foundation
import SwiftData
import WatchConnectivity

final class WatchBridge: NSObject, WCSessionDelegate {
    static let shared = WatchBridge()

    private var container: ModelContainer?
    private var lastSent: WatchSnapshot?

    private var session: WCSession? { WCSession.isSupported() ? .default : nil }

    /// App 启动时调用
    func start(container: ModelContainer) {
        self.container = container
        guard let session else { return }
        session.delegate = self
        session.activate()
    }

    /// 发送今天的卡片；没配对手表、没装手表 App、内容没变时什么都不做
    func push(plan: DailyPlan, words: [VocabWord], accent: String, now: Date = Date()) {
        guard let session, session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else { return }
        let snapshot = Self.snapshot(plan: plan, words: words, accent: accent, now: now)
        guard snapshot != lastSent, let data = WatchSync.encode(snapshot) else { return }
        do {
            try session.updateApplicationContext([WatchSync.snapshotKey: data])
            lastSent = snapshot
        } catch {
            #if DEBUG
            print("WatchBridge push failed:", error)
            #endif
        }
    }

    /// 先复习到期的，再学新词；和手机上开始复习时的顺序一样
    static func snapshot(plan: DailyPlan, words: [VocabWord], accent: String, now: Date = Date(), calendar: Calendar = .current) -> WatchSnapshot {
        let byID = Dictionary(words.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let newIDs = Set(plan.newIDs)
        let cards = (plan.reviewIDs + plan.newIDs).prefix(WatchSync.maxCards).compactMap { id -> WatchCard? in
            guard let word = byID[id] else { return nil }
            return WatchCard(
                id: word.id,
                word: word.word,
                phonetic: word.phonetic,
                meaning: word.gloss.isEmpty ? word.explanation : word.gloss,
                example: word.exampleSentence,
                exampleTranslation: word.exampleTranslation,
                isNew: newIDs.contains(id)
            )
        }
        return WatchSnapshot(day: calendar.startOfDay(for: now), cards: Array(cards), accent: accent)
    }

    private func receive(_ rating: WatchRating) {
        guard let context = container?.mainContext else { return }
        if ReviewApplier.apply(rating, context: context) {
            StudyReminder.refresh(context: context)
        }
    }

    private func refresh() {
        guard let context = container?.mainContext else { return }
        lastSent = nil
        StudyReminder.refresh(context: context)
    }

    // MARK: - WCSessionDelegate

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in self.refresh() }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    /// 换了一块手表：重新激活
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    /// 刚装上手表 App、或者换了配对：补发一次
    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in self.refresh() }
    }

    /// 手表评分：手机在旁边时直接送到（message），不在旁边时系统排队送到（userInfo）
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let rating = WatchSync.decode(WatchRating.self, from: message[WatchSync.ratingKey] as? Data) else { return }
        Task { @MainActor in self.receive(rating) }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let rating = WatchSync.decode(WatchRating.self, from: userInfo[WatchSync.ratingKey] as? Data) else { return }
        Task { @MainActor in self.receive(rating) }
    }
}
