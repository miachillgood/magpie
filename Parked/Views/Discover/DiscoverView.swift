//
//  DiscoverView.swift
//  SnapLingo
//

import SwiftUI
import SwiftData

struct DiscoverView: View {
    @Query private var collections: [WordCollection]
    @Query private var entries: [WordCollectionEntry]
    @Query private var progresses: [UserCollectionProgress]
    @Query private var subscriptions: [CollectionSubscription]
    @Query private var creators: [CreatorProfile]
    @Environment(AuthManager.self) private var authManager
    @State private var selectedScene = DiscoverSceneCategory.all

    private var currentUserID: String? { authManager.currentUserID }

    private var discoverSummaries: [CollectionDeckSummary] {
        CollectionPresentation.summaries(
            collections: collections.filter {
                $0.isDiscoverable && $0.ownerUserID != currentUserID
            },
            entries: entries,
            progresses: progresses.owned(by: currentUserID),
            subscriptions: subscriptions.owned(by: currentUserID),
            creators: creators,
            currentUserID: currentUserID
        )
        .sorted { lhs, rhs in
            if lhs.collection.isFeatured != rhs.collection.isFeatured {
                return lhs.collection.isFeatured && !rhs.collection.isFeatured
            }
            return lhs.collection.updatedAt > rhs.collection.updatedAt
        }
    }

    private var filteredSummaries: [CollectionDeckSummary] {
        discoverSummaries.filter { selectedScene.matches($0.collection) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(DiscoverSceneCategory.allCases) { category in
                                sceneChip(category)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)

                if discoverSummaries.isEmpty {
                    Section {
                        ContentUnavailableView(
                            "还没有公开词书",
                            systemImage: "globe",
                            description: Text("等你发布第一本词书，或者稍后再来看看。")
                        )
                    }
                } else if filteredSummaries.isEmpty {
                    Section {
                        ContentUnavailableView(
                            "这个场景还没有词书",
                            systemImage: selectedScene.iconName,
                            description: Text("换一个场景看看。")
                        )
                    }
                } else {
                    Section(selectedScene == .all ? "公开词书" : selectedScene.rawValue) {
                        ForEach(filteredSummaries) { summary in
                            NavigationLink {
                                CollectionDetailView(collectionID: summary.collection.id)
                            } label: {
                                DiscoverCollectionRow(summary: summary)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("发现")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private func sceneChip(_ category: DiscoverSceneCategory) -> some View {
        let isSelected = selectedScene == category

        return Button {
            selectedScene = category
        } label: {
            HStack(spacing: 6) {
                Image(systemName: category.iconName)
                    .font(.caption)
                Text(category.rawValue)
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                isSelected ? Color.accentColor : Color(.secondarySystemBackground),
                in: Capsule()
            )
            .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

private struct DiscoverCollectionRow: View {
    let summary: CollectionDeckSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                CollectionCoverThumbnail(data: summary.collection.coverImage)
                    .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    if !summary.subtitle.isEmpty {
                        Text(summary.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Text(summary.authorName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            HStack(spacing: 8) {
                ForEach(summary.sceneLabels.prefix(2), id: \.self) { tag in
                    badge(tag, color: .orange)
                }
                badge("\(summary.entryCount) 词")
                if !summary.collection.persona.isEmpty {
                    badge(summary.collection.persona, color: .accentColor)
                }
                if summary.isSubscribed {
                    badge("已在学习", color: .green)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func badge(_ text: String, color: Color = .accentColor) -> some View {
        Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(color.opacity(0.12), in: Capsule())
            .foregroundStyle(color)
    }
}
