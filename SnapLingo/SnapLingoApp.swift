//
//  SnapLingoApp.swift
//  SnapLingo
//
//  Created by Mia Miao on 13/04/2026.
//

import SwiftUI
import SwiftData

@main
struct SnapLingoApp: App {
    let container: ModelContainer
    @State private var coordinator = AppCoordinator()

    init() {
        do {
            let schema = Schema([VocabWord.self, ReviewSession.self, AppSettings.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            // 数据库损坏时删除重建
            print("ModelContainer 初始化失败，尝试重建: \(error)")
            do {
                let schema = Schema([VocabWord.self, ReviewSession.self, AppSettings.self])
                let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                container = try ModelContainer(for: schema, configurations: config)
            } catch {
                fatalError("ModelContainer 无法初始化: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .modelContainer(container)
                .environment(coordinator)
        }
    }
}
