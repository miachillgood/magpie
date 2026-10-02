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
        container = Self.makeContainer()
        Typography.configureNavigationBar()
        #if DEBUG
        DemoData.applyLaunchArguments(to: container.mainContext)
        #endif
        SpacedRepetitionMigration.run(context: container.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(Theme.brand)
                .modelContainer(container)
                .environment(coordinator)
        }
    }

    static let schema = Schema([
        Scan.self,
        VocabWord.self,
        ReviewLog.self,
        UserSettings.self,
        WordFamiliarity.self
    ])

    /// 新版数据库使用独立文件，旧版（重新设计前）的数据库直接移除
    private static func makeContainer() -> ModelContainer {
        let directory = URL.applicationSupportDirectory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        removeStore(at: directory.appending(path: "default.store"))

        let url = directory.appending(path: "SnapLingo-v2.store")
        let configuration = ModelConfiguration("SnapLingo-v2", schema: schema, url: url)
        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            // 结构不兼容时删库重建一次（开发阶段数据可清空）
            print("ModelContainer 打开失败，重建数据库：\(error)")
            removeStore(at: url)
            do {
                return try ModelContainer(for: schema, configurations: configuration)
            } catch {
                fatalError("ModelContainer 无法创建：\(error)")
            }
        }
    }

    private static func removeStore(at url: URL) {
        for suffix in ["", "-shm", "-wal"] {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + suffix))
        }
    }
}
