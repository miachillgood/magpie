//
//  MagpieWatchApp.swift
//  MagpieWatch
//
//  手表上复习今天的词：看单词 → 点一下翻面看意思 → 不会 / 会。
//  卡片由 iPhone 同步过来，评分传回 iPhone 后由手机重新排期。
//

import SwiftUI

@main
struct MagpieWatchApp: App {
    init() {
        WatchStore.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                WatchHomeView()
            }
            .tint(Color("AccentColor"))
        }
    }
}
