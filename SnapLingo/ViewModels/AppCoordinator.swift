//
//  AppCoordinator.swift
//  SnapLingo
//

import SwiftUI

// MARK: - Tab 枚举

enum AppTab {
    case home
    case library
    case review
    case profile
}

// MARK: - AppCoordinator

/// 全局导航状态持有者，通过 @Environment 注入到视图树
@Observable
final class AppCoordinator {
    var selectedTab: AppTab = .home
    var scanPath = NavigationPath()
    var libraryPath = NavigationPath()
    var showingScan = false   // 扫描流入口（fullScreenCover）
}
