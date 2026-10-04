//
//  SceneContextMenu.swift
//  SnapLingo
//
//  长按场景照片：大图预览 + 学这些词 / 重命名 / 删除，和照片 App 的长按一样
//

import SwiftUI
import SwiftData

private struct SceneContextMenu: ViewModifier {
    let scan: Scan

    @Environment(\.modelContext) private var context
    @Environment(AppCoordinator.self) private var coordinator
    @State private var renaming = false
    @State private var titleDraft = ""
    @State private var confirmingDelete = false

    func body(content: Content) -> some View {
        content
            .contextMenu {
                if !scan.words.isEmpty {
                    Button("学这个场景的词", systemImage: "play") {
                        coordinator.startStudy(.scan(scan.id))
                    }
                }
                Button("重命名", systemImage: "pencil") {
                    titleDraft = scan.title
                    renaming = true
                }
                Divider()
                Button("删除场景", systemImage: "trash", role: .destructive) {
                    confirmingDelete = true
                }
            } preview: {
                ScenePreview(scan: scan)
            }
            .alert("重命名场景", isPresented: $renaming) {
                TextField("场景名称", text: $titleDraft)
                Button("取消", role: .cancel) {}
                Button("保存") {
                    scan.title = titleDraft
                    try? context.save()
                }
            }
            .confirmationDialog("删除这个场景？", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("删除场景", role: .destructive) {
                    withAnimation { WordLibrary.delete(scan, context: context) }
                }
            } message: {
                Text("照片会被删除；只在这个场景里出现过的词也会一起删除，其他场景里也有的词会保留。")
            }
    }
}

/// 长按时浮起来的大图：保持照片原比例，下面写场景名和词数
private struct ScenePreview: View {
    let scan: Scan

    var body: some View {
        let ratio = scan.imageAspectRatio > 0 ? scan.imageAspectRatio : 0.75
        VStack(alignment: .leading, spacing: 0) {
            ScanThumbnail(scan: scan)
                .aspectRatio(ratio, contentMode: .fit)
                .frame(width: 320)
            VStack(alignment: .leading, spacing: 2) {
                Text(scan.displayTitle)
                    .font(.headline)
                Text("\(scan.words.count) 个词")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
        }
        .frame(width: 320)
        .background(Theme.sheet)
    }
}

extension View {
    func sceneContextMenu(_ scan: Scan) -> some View {
        modifier(SceneContextMenu(scan: scan))
    }
}
