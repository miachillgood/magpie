//
//  StudyStore.swift
//  SnapLingo
//

import Foundation
import SwiftData

/// 读取学习数据并生成计划的便捷入口
enum StudyStore {
    static func words(_ context: ModelContext) -> [VocabWord] {
        (try? context.fetch(FetchDescriptor<VocabWord>())) ?? []
    }

    static func logs(since date: Date? = nil, _ context: ModelContext) -> [ReviewLog] {
        var descriptor = FetchDescriptor<ReviewLog>(sortBy: [SortDescriptor(\.reviewedAt)])
        if let date {
            descriptor.predicate = #Predicate { $0.reviewedAt >= date }
        }
        return (try? context.fetch(descriptor)) ?? []
    }

    static func plan(settings: UserSettings, words: [VocabWord], logs: [ReviewLog], extraNew: Int = 0, now: Date = Date()) -> DailyPlan {
        DailyPlanner.plan(
            words: words,
            events: logs,
            newPerDay: settings.newWordsPerDay,
            maxReviews: settings.maxReviewsPerDay,
            extraNew: extraNew,
            now: now
        )
    }
}

/// 根据今天的计划刷新本地提醒，并把今天的卡片同步到手表。
/// 复习、加词、改目标之后都会调用这里，所以手表上的计划也跟着更新
enum StudyReminder {
    static func refresh(context: ModelContext) {
        let settings = UserSettings.current(in: context)
        let startOfToday = Calendar.current.startOfDay(for: Date())
        let words = StudyStore.words(context)
        let plan = StudyStore.plan(
            settings: settings,
            words: words,
            logs: StudyStore.logs(since: startOfToday, context)
        )
        WatchBridge.shared.push(plan: plan, words: words, accent: settings.accent.rawValue)

        guard settings.reminderEnabled else {
            NotificationService.reschedule(enabled: false, hour: 0, minute: 0, pendingCount: 0, completedToday: false)
            return
        }
        NotificationService.reschedule(
            enabled: true,
            hour: settings.reminderHour,
            minute: settings.reminderMinute,
            pendingCount: plan.remaining,
            completedToday: plan.isComplete
        )
    }
}

extension Scan {
    /// 这个场景里现在能学的词：已到期的、还没学的新词
    func studyCounts(today: Date = Calendar.current.startOfDay(for: Date())) -> (due: Int, new: Int) {
        var due = 0, new = 0
        for word in words where !word.excludedFromReview {
            if word.state == .new {
                new += 1
            } else if word.dueDate <= today {
                due += 1
            }
        }
        return (due, new)
    }
}
