//
//  BooksView.swift
//  SnapLingo
//

import SwiftUI
import SwiftData

private enum CollectionShelfTab: String, CaseIterable {
    case mine = "我的词书"
    case subscribed = "学习中的词书"
}

struct BooksView: View {
    @Query private var collections: [WordCollection]
    @Query private var entries: [WordCollectionEntry]
    @Query private var progresses: [UserCollectionProgress]
    @Query private var subscriptions: [CollectionSubscription]
    @Query private var creators: [CreatorProfile]
    @Environment(AuthManager.self) private var authManager
    @State private var shelfTab = CollectionShelfTab.mine
    @State private var showingCreateSheet = false

    private var currentUserID: String? { authManager.currentUserID }

    private var summaries: [CollectionDeckSummary] {
        CollectionPresentation.summaries(
            collections: collections,
            entries: entries,
            progresses: progresses.owned(by: currentUserID),
            subscriptions: subscriptions.owned(by: currentUserID),
            creators: creators,
            currentUserID: currentUserID
        )
    }

    private var mySummaries: [CollectionDeckSummary] {
        summaries
            .filter { $0.collection.ownerUserID == currentUserID }
            .sorted { lhs, rhs in
                if lhs.collection.isDefaultPersonal != rhs.collection.isDefaultPersonal {
                    return lhs.collection.isDefaultPersonal && !rhs.collection.isDefaultPersonal
                }
                return lhs.collection.updatedAt > rhs.collection.updatedAt
            }
    }

    private var subscribedSummaries: [CollectionDeckSummary] {
        summaries
            .filter { $0.isSubscribed && $0.collection.ownerUserID != currentUserID }
            .sorted { $0.collection.updatedAt > $1.collection.updatedAt }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("词书", selection: $shelfTab) {
                        ForEach(CollectionShelfTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if shelfTab == .mine {
                    Section {
                        Button {
                            showingCreateSheet = true
                        } label: {
                            Label("新建词书", systemImage: "plus.circle.fill")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }

                if displayedSummaries.isEmpty {
                    Section {
                        ContentUnavailableView(
                            shelfTab == .mine ? "还没有词书" : "还没有加入学习的词书",
                            systemImage: shelfTab == .mine ? "books.vertical" : "bookmark",
                            description: Text(shelfTab == .mine ? "先建一本自己的场景词书。" : "去发现页加入一些公开词书。")
                        )
                    }
                } else {
                    Section {
                        ForEach(displayedSummaries) { summary in
                            NavigationLink {
                                CollectionDetailView(collectionID: summary.collection.id)
                            } label: {
                                CollectionSummaryRow(summary: summary, showsOwner: shelfTab == .subscribed)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("词书")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showingCreateSheet) {
            NavigationStack {
                WordCollectionEditorView(collection: nil, ownerUserID: currentUserID)
            }
        }
    }

    private var displayedSummaries: [CollectionDeckSummary] {
        shelfTab == .mine ? mySummaries : subscribedSummaries
    }
}

struct CollectionDetailView: View {
    let collectionID: UUID

    @Query private var collections: [WordCollection]
    @Query private var entries: [WordCollectionEntry]
    @Query private var progresses: [UserCollectionProgress]
    @Query private var subscriptions: [CollectionSubscription]
    @Query private var creators: [CreatorProfile]
    @Query(sort: \VocabWord.addedAt, order: .reverse) private var allWords: [VocabWord]
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthManager.self) private var authManager
    @State private var showingEditor = false
    @State private var showingArchiveConfirmation = false
    @State private var errorMessage: String?

    private var currentUserID: String? { authManager.currentUserID }
    private var collection: WordCollection? { collections.first { $0.id == collectionID } }
    private var creator: CreatorProfile? { creators.first { $0.userID == collection?.ownerUserID } }
    private var collectionEntries: [WordCollectionEntry] {
        CollectionPresentation.entries(for: collectionID, in: entries)
    }
    private var progress: UserCollectionProgress? {
        progresses.owned(by: currentUserID).first { $0.collectionID == collectionID }
    }
    private var creatorPublicCollectionCount: Int {
        guard let collection else { return 0 }
        return collections.filter { $0.ownerUserID == collection.ownerUserID && $0.isDiscoverable }.count
    }
    private var isOwner: Bool {
        collection?.ownerUserID == currentUserID
    }
    private var isSubscribed: Bool {
        subscriptions.owned(by: currentUserID).contains { $0.collectionID == collectionID }
    }
    private var userWords: [VocabWord] { allWords.owned(by: currentUserID) }

    var body: some View {
        List {
            if let collection {
                Section {
                    CollectionHeaderCard(
                        summary: CollectionDeckSummary(
                            collection: collection,
                            creator: creator,
                            progress: progress,
                            entryCount: collectionEntries.count,
                            dueCount: progress?.dueEntryCount ?? 0,
                            completionRate: progress?.completionRate ?? 0,
                            isSubscribed: isSubscribed
                        ),
                        showsOwner: !isOwner
                    )
                    .padding(.vertical, 4)

                    if collection.isDiscoverable, let creator {
                        NavigationLink {
                            CreatorProfileView(creatorUserID: creator.userID)
                        } label: {
                            CreatorSummaryCard(
                                creator: creator,
                                publicCollectionCount: creatorPublicCollectionCount
                            )
                            .padding(.top, 6)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section {
                    if isOwner {
                        ownerActions(collection)
                    } else {
                        subscriberActions(collection)
                    }
                }

                Section("单词") {
                    ForEach(collectionEntries) { entry in
                        NavigationLink {
                            PublicWordStudyView(entryID: entry.id)
                        } label: {
                            CollectionEntryRow(
                                entry: entry,
                                isInPersonalLibrary: userWords.contains { $0.normalizedForm == entry.normalizedForm }
                            )
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(collection?.title ?? "词书")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isOwner, collection?.status != .archived {
                ToolbarItem(placement: .primaryAction) {
                    Button("编辑") {
                        showingEditor = true
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            NavigationStack {
                WordCollectionEditorView(collection: collection, ownerUserID: currentUserID)
            }
        }
        .confirmationDialog("归档这本词书？", isPresented: $showingArchiveConfirmation) {
            Button("归档", role: .destructive) {
                archiveCollection()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("归档后它不会再出现在你的主列表里，但词条和学习记录会保留。")
        }
        .alert("操作失败", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("好") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @ViewBuilder
    private func ownerActions(_ collection: WordCollection) -> some View {
        if !collectionEntries.isEmpty {
            NavigationLink {
                CollectionReviewView(
                    title: collection.title,
                    collectionID: collection.id,
                    entries: collectionEntries
                )
            } label: {
                actionRow(title: "开始学习", value: "\(progress?.dueEntryCount ?? 0) 待复习", accent: .accentColor)
            }
        }

        Button {
            togglePublish(collection)
        } label: {
            actionRow(
                title: collection.visibility == .public ? "取消公开" : "公开发布",
                value: collection.visibility.displayName,
                accent: .orange
            )
        }
        .buttonStyle(.plain)

        Button {
            showingEditor = true
        } label: {
            actionRow(title: "编辑词书", value: "修改资料", accent: .blue)
        }
        .buttonStyle(.plain)

        if !collection.isDefaultPersonal {
            Button(role: .destructive) {
                showingArchiveConfirmation = true
            } label: {
                actionRow(title: "归档词书", value: collection.status.displayName, accent: .red)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func subscriberActions(_ collection: WordCollection) -> some View {
        Button {
            toggleSubscription(collection)
        } label: {
            actionRow(
                title: isSubscribed ? "移出学习" : "加入学习",
                value: isSubscribed ? "已在学习" : "公开词书",
                accent: isSubscribed ? .red : .accentColor
            )
        }
        .buttonStyle(.plain)

        if isSubscribed {
            NavigationLink {
                CollectionReviewView(
                    title: collection.title,
                    collectionID: collection.id,
                    entries: collectionEntries
                )
            } label: {
                actionRow(title: "开始学习", value: "\(progress?.dueEntryCount ?? 0) 待复习", accent: .green)
            }
        }
    }

    private func actionRow(title: String, value: String, accent: Color) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.primary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundStyle(accent)
        }
    }

    private func togglePublish(_ collection: WordCollection) {
        if collection.visibility == .public {
            CollectionStore.makePrivate(collection)
        } else {
            CollectionStore.publish(collection)
        }
        try? modelContext.save()
    }

    private func archiveCollection() {
        guard let collection else { return }
        CollectionStore.archive(collection)
        try? modelContext.save()
    }

    private func toggleSubscription(_ collection: WordCollection) {
        do {
            if isSubscribed {
                try CollectionStore.unsubscribe(
                    userID: currentUserID,
                    collectionID: collection.id,
                    context: modelContext
                )
            } else {
                try CollectionStore.subscribe(
                    userID: currentUserID,
                    collection: collection,
                    context: modelContext
                )
            }
            try modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct WordCollectionEditorView: View {
    let collection: WordCollection?
    let ownerUserID: String?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var title: String
    @State private var subtitle: String
    @State private var summaryText: String
    @State private var region: String
    @State private var persona: String
    @State private var visibility: CollectionVisibility
    @State private var selectedTags: Set<String>

    init(collection: WordCollection?, ownerUserID: String?) {
        self.collection = collection
        self.ownerUserID = ownerUserID
        _title = State(initialValue: collection?.title ?? "")
        _subtitle = State(initialValue: collection?.subtitle ?? "")
        _summaryText = State(initialValue: collection?.summaryText ?? "")
        _region = State(initialValue: collection?.region ?? "")
        _persona = State(initialValue: collection?.persona ?? "")
        _visibility = State(initialValue: collection?.visibility ?? .private)
        _selectedTags = State(initialValue: Set(collection?.sceneTags ?? []))
    }

    var body: some View {
        Form {
            Section("基本信息") {
                TextField("标题", text: $title)
                TextField("副标题", text: $subtitle)
                TextField("简介", text: $summaryText, axis: .vertical)
                    .lineLimit(3...6)
            }

            Section("身份与场景") {
                TextField("地区", text: $region)
                TextField("身份 / 职业", text: $persona)
                FlowLayout(spacing: 8) {
                    ForEach(SceneTag.allCases, id: \.self) { tag in
                        Button {
                            toggle(tag.rawValue)
                        } label: {
                            Text(tag.rawValue)
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(
                                    selectedTags.contains(tag.rawValue)
                                    ? Color.accentColor
                                    : Color(.secondarySystemBackground),
                                    in: Capsule()
                                )
                                .foregroundStyle(selectedTags.contains(tag.rawValue) ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("发布") {
                Picker("可见性", selection: $visibility) {
                    Text("私密").tag(CollectionVisibility.private)
                    Text("公开").tag(CollectionVisibility.public)
                }
            }
        }
        .navigationTitle(collection == nil ? "新建词书" : "编辑词书")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    saveCollection()
                }
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func toggle(_ tag: String) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
    }

    private func saveCollection() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let ownerUserID, !trimmedTitle.isEmpty else { return }

        let target = collection ?? WordCollection(ownerUserID: ownerUserID, title: trimmedTitle)
        if collection == nil {
            modelContext.insert(target)
        }

        target.title = trimmedTitle
        target.subtitle = subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        target.summaryText = summaryText.trimmingCharacters(in: .whitespacesAndNewlines)
        target.region = region.trimmingCharacters(in: .whitespacesAndNewlines)
        target.persona = persona.trimmingCharacters(in: .whitespacesAndNewlines)
        target.sceneTags = Array(selectedTags).sorted()
        target.visibility = visibility
        target.status = visibility == .public ? .published : .draft
        target.publishedAt = visibility == .public ? (target.publishedAt ?? Date()) : nil
        target.updatedAt = Date()
        target.contentRevision += 1

        try? modelContext.save()
        dismiss()
    }
}

private struct CollectionSummaryRow: View {
    let summary: CollectionDeckSummary
    let showsOwner: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
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

                    if showsOwner {
                        Text(summary.authorName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }

            HStack(spacing: 8) {
                badge(summary.collection.visibility.displayName, color: summary.collection.visibility == .public ? .green : .secondary)
                badge(summary.collection.status.displayName, color: .orange)
                badge("\(summary.entryCount) 词", color: .blue)
                if summary.isSubscribed {
                    badge("学习中", color: .green)
                }
                if summary.dueCount > 0 {
                    badge("\(summary.dueCount) 待复习", color: .red)
                }
            }
        }
        .padding(.vertical, 6)
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

private struct CollectionHeaderCard: View {
    let summary: CollectionDeckSummary
    let showsOwner: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                CollectionCoverThumbnail(data: summary.collection.coverImage)
                    .frame(width: 72, height: 72)

                VStack(alignment: .leading, spacing: 6) {
                    Text(summary.title)
                        .font(.title3.bold())

                    if !summary.subtitle.isEmpty {
                        Text(summary.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if showsOwner {
                        Text(summary.authorName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }

            if !summary.collection.summaryText.isEmpty {
                Text(summary.collection.summaryText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                if !summary.collection.region.isEmpty {
                    metaBadge(summary.collection.region)
                }
                if !summary.collection.persona.isEmpty {
                    metaBadge(summary.collection.persona)
                }
                ForEach(summary.collection.sceneTags.prefix(2), id: \.self) { tag in
                    metaBadge(tag)
                }
            }

            HStack(spacing: 12) {
                stat(title: "单词", value: "\(summary.entryCount)")
                stat(title: "待复习", value: "\(summary.dueCount)")
                stat(title: "进度", value: "\(Int(summary.completionRate * 100))%")
            }
        }
    }

    private func metaBadge(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(.secondarySystemBackground), in: Capsule())
    }

    private func stat(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct CollectionEntryRow: View {
    let entry: WordCollectionEntry
    let isInPersonalLibrary: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.word)
                        .font(.headline)
                    Text(entry.chineseExplanation)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isInPersonalLibrary {
                    Text("已在词库")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    Text("学习")
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                }
            }

            if !entry.exampleSentence.isEmpty {
                Text(entry.exampleSentence)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

struct CollectionCoverThumbnail: View {
    let data: Data?

    var body: some View {
        Group {
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    LinearGradient(
                        colors: [Color.orange, Color.accentColor],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: "books.vertical.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
