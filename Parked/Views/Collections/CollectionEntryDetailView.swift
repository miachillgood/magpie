//
//  CollectionEntryDetailView.swift
//  SnapLingo
//

import SwiftUI
import SwiftData

struct PublicWordStudyView: View {
    let entryID: UUID

    @Query private var entries: [WordCollectionEntry]
    @Query private var collections: [WordCollection]
    @Query private var creators: [CreatorProfile]
    @Query(sort: \VocabWord.addedAt, order: .reverse) private var allWords: [VocabWord]
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthManager.self) private var authManager
    @State private var showsMeaning = false
    @State private var errorMessage: String?

    private var currentUserID: String? { authManager.currentUserID }
    private var entry: WordCollectionEntry? { entries.first { $0.id == entryID } }
    private var collection: WordCollection? {
        guard let entry else { return nil }
        return collections.first { $0.id == entry.collectionID }
    }
    private var creator: CreatorProfile? {
        guard let collection else { return nil }
        return creators.first { $0.userID == collection.ownerUserID }
    }
    private var isInPersonalLibrary: Bool {
        guard let entry, let currentUserID else { return false }
        return allWords.owned(by: currentUserID).contains { $0.normalizedForm == entry.normalizedForm }
    }

    var body: some View {
        Group {
            if let entry {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        wordCard(entry)
                        actionCard(entry)

                        if !entry.exampleSentence.isEmpty {
                            studyInfoCard(title: "例句") {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(entry.exampleSentence)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                    if !entry.exampleSentenceChinese.isEmpty {
                                        Text(entry.exampleSentenceChinese)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }

                        if !entry.sceneNote.isEmpty {
                            studyInfoCard(title: "场景说明") {
                                Text(entry.sceneNote)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                            }
                        }

                        if let collection {
                            sourceCard(collection)
                        }
                    }
                    .padding(16)
                }
                .background(Color(.systemGroupedBackground))
            } else {
                ContentUnavailableView("词条不存在", systemImage: "book.closed")
            }
        }
        .navigationTitle(entry?.word ?? "单词")
        .navigationBarTitleDisplayMode(.inline)
        .alert("操作失败", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("好") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func wordCard(_ entry: WordCollectionEntry) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            if let data = entry.sourceImageThumbnail {
                ScanThumbnailView(data: data)
                    .frame(maxWidth: .infinity)
                    .frame(height: 210)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text(entry.word)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                HStack(spacing: 8) {
                    metaBadge(entry.sceneTag.rawValue, color: .orange)
                    metaBadge(entry.categoryName, color: .blue)
                    if isInPersonalLibrary {
                        metaBadge("已在词库", color: .green)
                    }
                }

                if showsMeaning || isInPersonalLibrary {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(entry.chineseExplanation)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.primary)

                        if let creator {
                            Text("来自 \(creator.displayName) 的场景词书")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Button {
                        showsMeaning = true
                    } label: {
                        HStack {
                            Text("显示释义")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.caption.weight(.bold))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(18)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 22))
    }

    private func actionCard(_ entry: WordCollectionEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("加入我的词库")
                .font(.headline)

            if isInPersonalLibrary {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("这个词已经在你的长期词库里了。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                Button {
                    addToLibrary(entry)
                } label: {
                    HStack {
                        Text("加入我的词库")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Image(systemName: "plus.circle.fill")
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                Text("只加入这个单词，不会把整本词书一起导入。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 22))
    }

    private func sourceCard(_ collection: WordCollection) -> some View {
        let sourcePageTitle = entry?.sourcePageTitle.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return studyInfoCard(title: "来源词书") {
            NavigationLink {
                CollectionDetailView(collectionID: collection.id)
            } label: {
                HStack(spacing: 12) {
                    CollectionCoverThumbnail(data: collection.coverImage)
                        .frame(width: 56, height: 56)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(collection.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)

                        if let creator {
                            Text(creator.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 8) {
                            if !collection.region.isEmpty {
                                miniMeta(collection.region)
                            }
                            if !collection.persona.isEmpty {
                                miniMeta(collection.persona)
                            }
                        }
                    }

                    Spacer()
                }
                .padding(.vertical, 2)
            }
            .buttonStyle(.plain)

            if !sourcePageTitle.isEmpty {
                infoRow(title: "来源页面", value: sourcePageTitle)
            }
        }
    }

    private func studyInfoCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content()
        }
        .padding(18)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 22))
    }

    private func addToLibrary(_ entry: WordCollectionEntry) {
        do {
            try CollectionStore.addEntryToPersonalLibraryIfNeeded(
                entry: entry,
                userID: currentUserID,
                context: modelContext
            )
            if let currentUserID {
                try CollectionStore.refreshCollectionProgress(
                    collectionID: entry.collectionID,
                    userID: currentUserID,
                    context: modelContext
                )
            }
            try modelContext.save()
            showsMeaning = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.primary)
        }
        .font(.subheadline)
    }

    private func metaBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.12), in: Capsule())
            .foregroundStyle(color)
    }

    private func miniMeta(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(.tertiarySystemBackground), in: Capsule())
            .foregroundStyle(.secondary)
    }
}

struct CollectionEntryDetailView: View {
    let entryID: UUID

    var body: some View {
        PublicWordStudyView(entryID: entryID)
    }
}
