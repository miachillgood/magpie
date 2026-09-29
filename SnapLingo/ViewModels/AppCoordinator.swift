//
//  AppCoordinator.swift
//  SnapLingo
//

import SwiftUI

enum AppTab: Hashable {
    /// 照片墙（首页）
    case home
    case review
    case words
    case me
}

/// 学习会话的范围
enum StudyScope: Hashable {
    /// 今日计划；extraNew 为额外多学的新词数
    case today(extraNew: Int)
    /// 只学某一个场景的词
    case scan(UUID)
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
    /// 跳到词库时预选的筛选
    var wordsFilter: WordsFilter = .all

    func startScan() {
        showingScan = true
    }

    func startStudy(_ scope: StudyScope = .today(extraNew: 0)) {
        studyRequest = StudyRequest(scope: scope)
    }

    func showWords(_ filter: WordsFilter) {
        wordsFilter = filter
        selectedTab = .words
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
        case .all:      "全部"
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
