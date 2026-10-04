//
//  AppCoordinator.swift
//  SnapLingo
//

import SwiftUI

enum AppTab: Hashable {
    /// 照片墙（首页）
    case home
    /// 复习（包含词库）
    case review
    /// 标签栏右边单独的圆形快门：点了打开相机，不会真的切过去
    case snap
}

/// 学习会话的范围
enum StudyScope: Hashable {
    /// 今日计划；extraNew 为额外多学的新词数
    case today(extraNew: Int)
    /// 只学某一个场景的词
    case scan(UUID)
    /// 某一天拍到的词（还没到期的也会过一遍，但不改变复习安排）
    case day(Date)
    /// 指定的几个词（比如「总是记不住的词」）；还没到期的同样只是再看一遍
    case words([UUID])
}

struct StudyRequest: Identifiable, Hashable {
    let id = UUID()
    let scope: StudyScope
}

/// 全局导航状态
@Observable
final class AppCoordinator {
    var selectedTab: AppTab = .home
    var showingScan = false
    /// 今天还有要学 / 要复习的词（底部“复习”图标上的小红点）
    var reviewPending = false
    var studyRequest: StudyRequest?
    /// 从 Spotlight 点开的单词：复习页收到后推入单词详情
    var openWordID: UUID?

    func startScan() {
        showingScan = true
    }

    func startStudy(_ scope: StudyScope = .today(extraNew: 0)) {
        studyRequest = StudyRequest(scope: scope)
    }
}

/// 词库筛选
enum WordsFilter: String, CaseIterable, Identifiable {
    case all
    case new
    case learning
    case mastered

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:      String(localized: "全部", comment: "Word filter: all words")
        case .new:      WordState.new.displayName
        case .learning: WordState.learning.displayName
        case .mastered: WordState.mastered.displayName
        }
    }

    func matches(_ word: VocabWord) -> Bool {
        switch self {
        case .all:      true
        case .new:      word.state == .new
        case .learning: word.state == .learning
        case .mastered: word.state == .mastered
        }
    }
}
