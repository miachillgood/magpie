//
//  ProfileView.swift
//  SnapLingo
//

import SwiftUI
import SwiftData

struct ProfileView: View {
    @Query private var settingsArray: [AppSettings]
    @Query private var allWords: [VocabWord]
    @Query(sort: \ReviewSession.performedAt, order: .reverse) private var sessions: [ReviewSession]
    @Environment(\.modelContext) private var modelContext

    private var settings: AppSettings? { settingsArray.first }

    private var masteredCount: Int { allWords.filter(\.isMastered).count }
    private var masteryRate: Double {
        allWords.isEmpty ? 0 : Double(masteredCount) / Double(allWords.count)
    }

    private var streakDays: Int {
        guard !sessions.isEmpty else { return 0 }
        let cal = Calendar.current
        var day = cal.startOfDay(for: Date())
        let todayHasSession = sessions.contains { cal.isDate($0.performedAt, inSameDayAs: day) }
        if !todayHasSession {
            guard let yesterday = cal.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        var streak = 0
        while sessions.contains(where: { cal.isDate($0.performedAt, inSameDayAs: day) }) {
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return streak
    }

    var body: some View {
        NavigationStack {
            List {
                // 头像 + 水平展示
                avatarSection

                // 水平选择
                levelPickerSection

                // 统计
                statsSection

                // 水平对筛词的影响说明
                levelGuideSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("我的档案")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - 头像区

    private var avatarSection: some View {
        Section {
            HStack(spacing: 16) {
                // 水平对应的 emoji 头像
                Text(levelEmoji)
                    .font(.system(size: 48))
                    .frame(width: 72, height: 72)
                    .background(Color.accentColor.opacity(0.1), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text("英语学习者")
                        .font(.title3.bold())
                    HStack(spacing: 6) {
                        Text(settings?.estimatedUserLevel.displayName ?? "未知水平")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(levelColor, in: Capsule())
                        Text("· \(allWords.count) 个词汇")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - 水平选择

    private var levelPickerSection: some View {
        Section {
            ForEach(UserLevel.allCases.filter { $0 != .unknown }, id: \.self) { level in
                Button {
                    updateLevel(level)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: levelIcon(level))
                            .font(.title3)
                            .foregroundStyle(levelColor(for: level))
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(level.displayName)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                            Text(levelDescription(level))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if settings?.estimatedUserLevel == level {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text("我的英语水平")
        } footer: {
            Text("水平影响 AI 为你筛选的词汇难度。你可以随时手动调整。")
                .font(.caption)
        }
    }

    // MARK: - 统计

    private var statsSection: some View {
        Section("学习统计") {
            statRow(icon: "book.closed.fill", color: .blue,
                    label: "累计词汇", value: "\(allWords.count) 个")
            statRow(icon: "checkmark.seal.fill", color: .green,
                    label: "已掌握", value: "\(masteredCount) 个（\(Int(masteryRate * 100))%）")
            statRow(icon: "flame.fill", color: .orange,
                    label: "连续学习", value: "\(streakDays) 天")
            statRow(icon: "clock.arrow.2.circlepath", color: .purple,
                    label: "累计复习", value: "\(sessions.count) 次")
        }
    }

    private func statRow(icon: String, color: Color, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
            Text(label)
                .foregroundStyle(.primary)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - 水平说明

    private var levelGuideSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                guideRow(level: "初级",
                         desc: "AI 会为你筛选日常高频词汇，难词较多，解释更详细")
                Divider()
                guideRow(level: "中级",
                         desc: "AI 筛选中等难度词汇，跳过极简单的基础词")
                Divider()
                guideRow(level: "高级",
                         desc: "AI 只保留专业词汇和生僻词，过滤大部分常见词")
            }
            .padding(.vertical, 4)
        } header: {
            Text("水平如何影响筛词")
        }
    }

    private func guideRow(level: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(level)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.accentColor.opacity(0.8), in: Capsule())
                .fixedSize()
            Text(desc)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - 辅助

    private func updateLevel(_ level: UserLevel) {
        if let s = settings {
            s.estimatedUserLevel = level
        } else {
            let s = AppSettings()
            s.estimatedUserLevel = level
            modelContext.insert(s)
        }
    }

    private var levelEmoji: String {
        switch settings?.estimatedUserLevel {
        case .beginner:     return "🌱"
        case .intermediate: return "📚"
        case .advanced:     return "🎓"
        default:            return "👋"
        }
    }

    private var levelColor: Color {
        levelColor(for: settings?.estimatedUserLevel ?? .unknown)
    }

    private func levelColor(for level: UserLevel) -> Color {
        switch level {
        case .unknown:      return .secondary
        case .beginner:     return .green
        case .intermediate: return .blue
        case .advanced:     return .purple
        }
    }

    private func levelIcon(_ level: UserLevel) -> String {
        switch level {
        case .unknown:      return "questionmark.circle"
        case .beginner:     return "leaf"
        case .intermediate: return "book.closed"
        case .advanced:     return "graduationcap"
        }
    }

    private func levelDescription(_ level: UserLevel) -> String {
        switch level {
        case .unknown:      return ""
        case .beginner:     return "CET-4 以下，日常常见词仍有不认识"
        case .intermediate: return "CET-4 至 CET-6，专业词汇需要学习"
        case .advanced:     return "CET-6 以上，只需学习专业/生僻词"
        }
    }
}
