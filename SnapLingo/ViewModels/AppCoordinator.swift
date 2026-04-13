//
//  AppCoordinator.swift
//  SnapLingo
//

import SwiftUI

// MARK: - Tab 枚举

enum AppTab {
    case scan
    case library
    case review
}

// MARK: - AppCoordinator

/// 全局导航状态持有者，通过 @Environment 注入到视图树
@Observable
final class AppCoordinator {
    var selectedTab: AppTab = .scan
    var scanPath = NavigationPath()
    var libraryPath = NavigationPath()
}
