//
//  CreatorProfileView.swift
//  SnapLingo
//

import SwiftUI
import SwiftData

struct CreatorProfileView: View {
    let creatorUserID: String

    @Query private var creators: [CreatorProfile]
    @Query private var collections: [WordCollection]
    @Query private var entries: [WordCollectionEntry]
    @Query private var progresses: [UserCollectionProgress]
    @Query private var subscriptions: [CollectionSubscription]
    @Environment(AuthManager.self) private var authManager

    private var currentUserID: String? { authManager.currentUserID }
    private var creator: CreatorProfile? { creators.first { $0.userID == creatorUserID } }
    private var publicCollections: [WordCollection] {
        collections
            .filter { $0.ownerUserID == creatorUserID && $0.isDiscoverable }
            .sorted { lhs, rhs in
                if lhs.isFeatured != rhs.isFeatured {
                    return lhs.isFeatured && !rhs.isFeatured
                }
                return lhs.updatedAt > rhs.updatedAt
            }
    }
    private var summaries: [CollectionDeckSummary] {
        CollectionPresentation.summaries(
            collections: publicCollections,
            entries: entries,
            progresses: progresses.owned(by: currentUserID),
            subscriptions: subscriptions.owned(by: currentUserID),
            creators: creators,
            currentUserID: currentUserID
        )
    }

    var body: some View {
        List {
            if let creator {
                Section {
                    CreatorSummaryCard(
                        creator: creator,
                        publicCollectionCount: summaries.count,
                        showsChevron: false
                    )
                    .padding(.vertical, 4)
                }

                Section("词书") {
                    if summaries.isEmpty {
                        Text("这个作者还没有公开词书。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(summaries) { summary in
                            NavigationLink {
                                CollectionDetailView(collectionID: summary.collection.id)
                            } label: {
                                CreatorCollectionRow(summary: summary)
                            }
                        }
                    }
                }
            } else {
                Section {
                    ContentUnavailableView("作者不存在", systemImage: "person.slash")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(creator?.displayName ?? "作者")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct CreatorSummaryCard: View {
    let creator: CreatorProfile
    let publicCollectionCount: Int
    var showsChevron = true

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(Color.accentColor)
            }
            .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 6) {
                Text(creator.displayName)
                    .font(.headline)
                    .foregroundStyle(.primary)

                HStack(spacing: 8) {
                    if !creator.region.isEmpty {
                        badge(creator.region, color: .blue)
                    }
                    if !creator.persona.isEmpty {
                        badge(creator.persona, color: .orange)
                    }
                    badge("\(publicCollectionCount) 本词书", color: .green)
                }

                if !creator.bio.isEmpty {
                    Text(creator.bio)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(color.opacity(0.12), in: Capsule())
            .foregroundStyle(color)
    }
}

private struct CreatorCollectionRow: View {
    let summary: CollectionDeckSummary

    var body: some View {
        HStack(spacing: 12) {
            CollectionCoverThumbnail(data: summary.collection.coverImage)
                .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 5) {
                Text(summary.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                if !summary.subtitle.isEmpty {
                    Text(summary.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    ForEach(summary.sceneLabels.prefix(2), id: \.self) { tag in
                        tagBadge(tag)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(summary.entryCount) 词")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if summary.isSubscribed {
                    Text("已在学习")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func tagBadge(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.orange.opacity(0.12), in: Capsule())
            .foregroundStyle(.orange)
    }
}
