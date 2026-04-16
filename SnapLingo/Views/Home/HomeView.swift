//
//  HomeView.swift
//  SnapLingo
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Query private var allWords: [VocabWord]
    @Query(sort: \ReviewSession.performedAt, order: .reverse) private var sessions: [ReviewSession]
    @Environment(AppCoordinator.self) private var coordinator

    // MARK: - 统计

    private var dueWords: [VocabWord] { allWords.filter(\.isDueForReview) }
    private var masteredCount: Int { allWords.filter(\.isMastered).count }

    private var todayReviewedCount: Int {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        return sessions.filter { $0.performedAt >= startOfDay }.count
    }

    private var streakDays: Int {
        guard !sessions.isEmpty else { return 0 }
        let cal = Calendar.current
        var day = cal.startOfDay(for: Date())
        var streak = 0
        // 检查今天是否有复习记录，没有则从昨天开始算
        let todayHasSession = sessions.contains { cal.isDate($0.performedAt, inSameDayAs: day) }
        if !todayHasSession {
            guard let yesterday = cal.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        while true {
            let hasSession = sessions.contains { cal.isDate($0.performedAt, inSameDayAs: day) }
            if hasSession {
                streak += 1
                guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
                day = prev
            } else {
                break
            }
        }
        return streak
    }

    // 最近 3 次扫描（按 scanSessionID 分组）
    private var recentScanSessions: [RecentSession] {
        var groups: [UUID: [VocabWord]] = [:]
        for word in allWords { groups[word.scanSessionID, default: []].append(word) }
        return groups.map { id, ws in
            let sorted = ws.sorted { $0.addedAt > $1.addedAt }
            return RecentSession(
                id: id,
                date: sorted.first?.addedAt ?? Date(),
                thumbnail: sorted.first?.sourceImageThumbnail,
                wordCount: ws.count,
                categoryName: sorted.first?.categoryName ?? "通用"
            )
        }
        .sorted { $0.date > $1.date }
        .prefix(3)
        .map { $0 }
    }

    var body: some View {
        @Bindable var coordinator = coordinator

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // MARK: 问候 + 今日状态
                    greetingSection

                    // MARK: 快捷操作
                    actionButtons

                    // MARK: 数据统计
                    statsRow

                    // MARK: 最近扫描
                    if !recentScanSessions.isEmpty {
                        recentScansSection
                    }

                    // MARK: 分类概览
                    if !allWords.isEmpty {
                        categorySection
                    }

                    Spacer(minLength: 20)
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .navigationTitle("SnapLingo")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - 问候区

    private var greetingSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(greetingText)
                .font(.title2.bold())

            if dueWords.isEmpty {
                Text("今天的复习都完成啦，继续加油！")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("有 **\(dueWords.count)** 个单词在等你复习")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 4)
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "早上好 ☀️"
        case 12..<18: return "下午好 👋"
        case 18..<22: return "晚上好 🌙"
        default:      return "夜深了 🌟"
        }
    }

    // MARK: - 快捷操作

    private var actionButtons: some View {
        HStack(spacing: 12) {
            // 开始复习
            Button {
                coordinator.selectedTab = .review
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .font(.title2)
                        Spacer()
                        if !dueWords.isEmpty {
                            Text("\(dueWords.count)")
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(.white.opacity(0.25), in: Capsule())
                        }
                    }
                    Text("开始复习")
                        .font(.headline)
                    Text(dueWords.isEmpty ? "今日已完成" : "\(dueWords.count) 词待复习")
                        .font(.caption)
                        .opacity(0.8)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(dueWords.isEmpty ? Color.green : Color.accentColor, in: RoundedRectangle(cornerRadius: 16))
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)

            // 扫描新词
            Button {
                coordinator.showingScan = true
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Image(systemName: "camera.viewfinder")
                        .font(.title2)
                    Text("扫描新词")
                        .font(.headline)
                    Text("拍照学词汇")
                        .font(.caption)
                        .opacity(0.8)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange, in: RoundedRectangle(cornerRadius: 16))
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 统计行

    private var statsRow: some View {
        HStack(spacing: 0) {
            statCell(value: "\(allWords.count)", label: "总词汇", icon: "book.closed", color: .blue)
            Divider().frame(height: 40)
            statCell(value: "\(dueWords.count)", label: "待复习", icon: "clock", color: .orange)
            Divider().frame(height: 40)
            statCell(value: "\(masteredCount)", label: "已掌握", icon: "checkmark.seal", color: .green)
            Divider().frame(height: 40)
            statCell(value: "\(streakDays)", label: "连续天", icon: "flame", color: .red)
        }
        .padding(.vertical, 16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func statCell(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(value)
                .font(.title2.bold())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 最近扫描

    private var recentScansSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("最近扫描")
                    .font(.headline)
                Spacer()
                Button("查看全部") {
                    coordinator.selectedTab = .library
                }
                .font(.subheadline)
            }

            HStack(spacing: 12) {
                ForEach(recentScanSessions) { session in
                    recentScanCard(session)
                }
                Spacer()
            }
        }
    }

    private func recentScanCard(_ session: RecentSession) -> some View {
        Button {
            coordinator.selectedTab = .library
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Group {
                    if let data = session.thumbnail, let img = UIImage(data: data) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color.secondary.opacity(0.15)
                            .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
                    }
                }
                .frame(width: 90, height: 90)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Text(session.categoryName)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                    .foregroundStyle(.primary)

                Text("\(session.wordCount) 词 · \(session.date.formatted(.relative(presentation: .named)))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 90)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 分类概览

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("分类概览")
                .font(.headline)

            let categories = categoryStats()
            ForEach(categories, id: \.name) { cat in
                categoryRow(cat)
            }
        }
    }

    private func categoryRow(_ cat: CategoryStat) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(cat.name)
                    .font(.subheadline.weight(.medium))
                Text("\(cat.total) 个词")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            // 掌握进度条
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(cat.masteredCount) 已掌握")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                ProgressView(value: cat.total > 0 ? Double(cat.masteredCount) / Double(cat.total) : 0)
                    .frame(width: 80)
                    .tint(.green)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func categoryStats() -> [CategoryStat] {
        var groups: [String: [VocabWord]] = [:]
        for word in allWords { groups[word.categoryName, default: []].append(word) }
        return groups.map { name, words in
            CategoryStat(
                name: name,
                total: words.count,
                dueCount: words.filter(\.isDueForReview).count,
                masteredCount: words.filter(\.isMastered).count
            )
        }
        .sorted { $0.total > $1.total }
    }
}

// MARK: - 辅助数据结构

private struct RecentSession: Identifiable {
    let id: UUID
    let date: Date
    let thumbnail: Data?
    let wordCount: Int
    let categoryName: String
}

private struct CategoryStat {
    let name: String
    let total: Int
    let dueCount: Int
    let masteredCount: Int
}
