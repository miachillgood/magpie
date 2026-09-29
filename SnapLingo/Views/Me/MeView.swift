//
//  MeView.swift
//  SnapLingo
//

import SwiftUI
import SwiftData

struct MeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \UserSettings.createdAt) private var settingsRows: [UserSettings]
    @Query private var words: [VocabWord]
    @Query private var scans: [Scan]
    @Query(sort: \ReviewLog.reviewedAt) private var logs: [ReviewLog]
    @State private var showingLevelTest = false
    @State private var notificationsDenied = false
    #if DEBUG
    @State private var confirmingReset = false
    #endif

    var body: some View {
        NavigationStack {
            Group {
                if let settings = settingsRows.first {
                    form(settings)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("我的")
            .appTabBar()
        }
    }

    private func form(_ settings: UserSettings) -> some View {
        @Bindable var settings = settings
        let activity = Dictionary(grouping: logs) { Calendar.current.startOfDay(for: $0.reviewedAt) }
            .mapValues(\.count)

        return Form {
            // 水平
            Section {
                LevelCard(settings: settings) { showingLevelTest = true }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            // 统计
            Section {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: Spacing.sm), GridItem(.flexible(), spacing: Spacing.sm)], spacing: Spacing.sm) {
                    StatTile(value: DailyPlanner.streak(events: logs), label: "连续天数", emoji: "🔥", color: Pastel.peach)
                    StatTile(value: words.count, label: "单词", emoji: "📚", color: Pastel.butter)
                    StatTile(value: scans.count, label: "场景", emoji: "📸", color: Pastel.sky)
                    StatTile(value: words.filter { $0.state == .mastered }.count, label: "已掌握", emoji: "🏅", color: Pastel.mint)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            } header: {
                header("学习记录")
            }

            Section {
                ActivityHeatmapView(activity: activity)
                    .padding(.vertical, Spacing.xs)
            }

            // 每日计划
            Section {
                Picker(selection: $settings.newWordsPerDay) {
                    ForEach([5, 10, 15, 20, 30], id: \.self) { count in
                        Text("\(count) 个").tag(count)
                    }
                } label: {
                    row("✨", Pastel.peach, "每天学新词")
                }
                Picker(selection: $settings.maxReviewsPerDay) {
                    ForEach([30, 50, 100, 200, 500], id: \.self) { count in
                        Text("\(count) 个").tag(count)
                    }
                } label: {
                    row("🔁", Pastel.lavender, "每天最多复习")
                }
            } header: {
                header("每日计划")
            } footer: {
                Text("到期的复习优先；新词从最近拍的场景开始安排。")
            }

            // 提醒
            Section {
                Toggle(isOn: Binding(
                    get: { settings.reminderEnabled },
                    set: { enabled in Task { await setReminder(enabled, settings: settings) } }
                )) {
                    row("🔔", Pastel.butter, "每日提醒")
                }
                if settings.reminderEnabled {
                    DatePicker(selection: $settings.reminderTime, displayedComponents: .hourAndMinute) {
                        row("⏰", Pastel.sky, "提醒时间")
                    }
                }
            } header: {
                header("提醒")
            } footer: {
                if notificationsDenied {
                    Text("通知权限已关闭，请在“设置”中允许 SnapLingo 发送通知。")
                }
            }
            .onChange(of: settings.reminderHour) { StudyReminder.refresh(context: context) }
            .onChange(of: settings.reminderMinute) { StudyReminder.refresh(context: context) }

            // 发音
            Section {
                Picker(selection: $settings.accentRaw) {
                    ForEach(SpeechAccent.allCases) { accent in
                        Text(accent.title).tag(accent.rawValue)
                    }
                } label: {
                    row("🗣️", Pastel.mint, "口音")
                }
                Button {
                    SpeechService.shared.accent = settings.accent
                    SpeechService.shared.speak("Could I get a flat white, please?")
                } label: {
                    row("🔊", Pastel.pink, "试听一句")
                }
                .foregroundStyle(Theme.ink)
            } header: {
                header("发音")
            }
            .onChange(of: settings.accentRaw) { SpeechService.shared.accent = settings.accent }

            Section {
                LabeledContent {
                    Text(Bundle.main.appVersion)
                } label: {
                    row("ℹ️", Pastel.mist, "版本")
                }
                Text("SnapLingo 把你在国外生活中看到的英文变成每天几分钟的复习。照片和单词只保存在这台设备上。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                header("关于")
            }

            #if DEBUG
            Section {
                Button {
                    DemoData.seed(into: context)
                } label: {
                    row("🪄", Pastel.lavender, "导入示例数据")
                }
                .foregroundStyle(Theme.ink)
                Button(role: .destructive) {
                    confirmingReset = true
                } label: {
                    row("🗑️", Pastel.pink, "清空所有数据")
                }
                .confirmationDialog("清空所有场景、单词和学习记录？", isPresented: $confirmingReset, titleVisibility: .visible) {
                    Button("清空", role: .destructive) { DemoData.wipe(context) }
                }
            } header: {
                header("开发")
            }
            #endif
        }
        .scrollContentBackground(.hidden)
        .background(PaperBackground())
        .sheet(isPresented: $showingLevelTest) {
            NavigationStack {
                LevelTestView { score in
                    settings.levelScore = score
                    settings.assessmentCompleted = true
                    try? context.save()
                    showingLevelTest = false
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { showingLevelTest = false }
                    }
                }
            }
        }
        .onChange(of: settings.newWordsPerDay) { try? context.save(); StudyReminder.refresh(context: context) }
        .onChange(of: settings.maxReviewsPerDay) { try? context.save() }
    }

    private func row(_ emoji: String, _ color: Color, _ title: String) -> some View {
        HStack(spacing: Spacing.sm) {
            EmojiTile(emoji: emoji, color: color, size: 32)
            Text(title)
                .font(.body.weight(.medium))
        }
    }

    private func header(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.heavy))
            .foregroundStyle(Theme.ink.opacity(0.6))
            .textCase(nil)
    }

    private func setReminder(_ enabled: Bool, settings: UserSettings) async {
        if enabled {
            let granted = await NotificationService.requestAuthorization()
            notificationsDenied = !granted
            settings.reminderEnabled = granted
        } else {
            settings.reminderEnabled = false
        }
        try? context.save()
        StudyReminder.refresh(context: context)
    }
}

// MARK: - 水平卡片

private struct LevelCard: View {
    var settings: UserSettings
    var onRetest: () -> Void

    var body: some View {
        let level = settings.level
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.md) {
                Text(level.code)
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 84, height: 84)
                    .background(Theme.card.opacity(0.85), in: .rect(cornerRadius: Radius.card, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text("我的水平 · \(level.displayName)")
                        .font(.headline.weight(.heavy))
                    Text(level.summary)
                        .font(.subheadline)
                        .foregroundStyle(Theme.ink.opacity(0.65))
                }
            }
            if let next = level.next {
                VStack(alignment: .leading, spacing: 6) {
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Theme.card.opacity(0.7))
                            Capsule().fill(Theme.ink)
                                .frame(width: max(proxy.size.width * CEFRLevel.progressWithinLevel(score: settings.levelScore), 10))
                        }
                    }
                    .frame(height: 8)
                    Text("距离 \(next.code) 还差一点点，选词和复习时的表现会让等级慢慢提升")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.ink.opacity(0.6))
                }
            }
            Button(action: onRetest) {
                Label("重新测一次", systemImage: "arrow.clockwise")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Theme.card, in: .capsule)
            }
            .buttonStyle(.pressable)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [Pastel.lavender, Pastel.pink], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: .rect(cornerRadius: Radius.hero, style: .continuous)
        )
    }
}

extension Bundle {
    var appVersion: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
