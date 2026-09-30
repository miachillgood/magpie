//
//  MeCards.swift
//  SnapLingo
//
//  「我的」页的几张白卡片：我的水平、我的足迹、设置、账号、数据。
//

import SwiftData
import SwiftUI

// MARK: - 共用样式

/// 白色圆角卡片
private struct MeCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.sheet, in: .rect(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
    }
}

/// 卡片外面的分组标题（同复习页「按场景复习」）
private struct MeSectionTitle: View {
    var title: LocalizedStringKey
    var note: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(Theme.homeInk)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            if let note {
                Text(note)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.homeMuted)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 12)
    }
}

/// 设置行：淡蓝底的线条图标 + 标题 + 右边的控件
private struct SettingRow<Trailing: View>: View {
    var icon: String
    var title: LocalizedStringKey
    var subtitle: LocalizedStringKey?
    var danger = false
    var showsDivider = true
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(danger ? Theme.danger : Theme.homeInk)
                .frame(width: 34, height: 34)
                .background(danger ? Theme.danger.opacity(0.1) : Theme.placeChip, in: .rect(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(danger ? Theme.danger : Theme.homeInk)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.homeMuted)
                }
            }
            Spacer(minLength: 8)
            trailing
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            if showsDivider {
                Rectangle().fill(Theme.homeInk.opacity(0.07)).frame(height: 1).padding(.leading, 46)
            }
        }
        .contentShape(.rect)
    }
}

private struct Chevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.homeInk.opacity(0.25))
    }
}

// MARK: - 我的水平

struct LevelCard: View {
    var settings: UserSettings
    var onRetest: () -> Void

    var body: some View {
        let level = settings.level
        MeCard {
            HStack(alignment: .firstTextBaseline) {
                Text("我的水平")
                    .font(.system(size: 18, weight: .heavy))
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button(action: onRetest) {
                    Label("重新测一次", systemImage: "arrow.clockwise")
                        .font(.system(size: 13, weight: .bold))
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(Theme.homeInk)

            Text(level.displayName)
                .font(.system(size: 34, weight: .heavy))
                .foregroundStyle(Theme.homeInk)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 6)
                .background(alignment: .bottom) {
                    MarkerHighlight(drawn: true, cornerScale: 0.5)
                        .frame(height: 16)
                        .offset(y: -6)
                }
                .padding(.leading, -6)
                .padding(.top, 10)

            Text(level.summary)
                .font(.system(size: 14))
                .foregroundStyle(Theme.homeInk.opacity(0.75))
                .padding(.top, 4)

            if let next = level.next {
                let progress = CEFRLevel.progressWithinLevel(score: settings.levelScore)
                HStack {
                    Text("离「\(next.displayName)」还差一点")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Text(progress, format: .percent.precision(.fractionLength(0)))
                        .font(.brand(12))
                        .foregroundStyle(Theme.homeMuted)
                }
                .foregroundStyle(Theme.homeInk)
                .padding(.top, 16)
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.mist)
                        Capsule().fill(Theme.homeInk).frame(width: max(proxy.size.width * progress, 8))
                    }
                }
                .frame(height: 7)
                .padding(.top, 7)
            } else {
                Text("已经是最高等级了")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.homeMuted)
                    .padding(.top, 14)
            }
        }
    }
}

// MARK: - 我的足迹

struct FootprintCard: View {
    var days: Int
    var scenes: Int
    var words: Int
    var streak: Int
    var longest: Int

    var body: some View {
        MeCard {
            Text("我的足迹")
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(Theme.homeInk)
                .accessibilityAddTraits(.isHeader)
            HStack(alignment: .firstTextBaseline) {
                number(String(localized: "**\(days)** 天", comment: "Footprint: days since first photo; **N** is shown as a big number"))
                Spacer(minLength: 4)
                dot
                Spacer(minLength: 4)
                number(String(localized: "**\(scenes)** 个场景", comment: "Footprint: number of scenes; **N** is shown as a big number"))
                Spacer(minLength: 4)
                dot
                Spacer(minLength: 4)
                number(String(localized: "**\(words)** 个词", comment: "Footprint: number of words; **N** is shown as a big number"))
            }
            .padding(.top, 14)

            Divider().padding(.top, 14)

            HStack(spacing: 7) {
                Image(systemName: "flame")
                    .foregroundStyle(Color(hex: 0xF2A93B))
                Text("连续 \(streak) 天")
                    .fontWeight(.semibold)
                Text("· 最长 \(longest) 天")
                    .foregroundStyle(Theme.homeMuted)
            }
            .font(.system(size: 14))
            .foregroundStyle(Theme.homeInk)
            .padding(.top, 12)
        }
    }

    /// “**12** 天”：数字大、单位小；各语言可以把单位放在数字前后
    private func number(_ phrase: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            ForEach(Array(HeadlinePiece.phrase(phrase).enumerated()), id: \.offset) { _, piece in
                if case .marker(let value) = piece {
                    Text(value)
                        .font(.brand(30))
                        .foregroundStyle(Theme.homeInk)
                        .contentTransition(.numericText())
                } else {
                    Text(piece.plainText)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.homeMuted)
                }
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .accessibilityElement(children: .combine)
    }

    private var dot: some View {
        Circle().fill(Theme.homeInk.opacity(0.2)).frame(width: 4, height: 4)
            .alignmentGuide(.firstTextBaseline) { $0[.bottom] + 8 }
    }
}

// MARK: - 设置

struct SettingsCard: View {
    @Bindable var settings: UserSettings
    var wordCount: Int

    @Environment(\.modelContext) private var context
    @AppStorage(HomeTheme.storageKey) private var themeRaw = HomeTheme.sky.rawValue
    @State private var notificationsDenied = false
    @State private var pendingLanguage: NativeLanguage?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            MeSectionTitle(title: "设置")
            MeCard(padding: 14) {
                SettingRow(icon: "plus", title: "每天学新词") {
                    Picker("每天学新词", selection: $settings.newWordsPerDay) {
                        ForEach([5, 10, 15, 20, 30], id: \.self) { count in
                            Text("\(count) 个").tag(count)
                        }
                    }
                    .labelsHidden()
                    .tint(Theme.homeMuted)
                }
                SettingRow(icon: "arrow.2.squarepath", title: "每天最多复习") {
                    Picker("每天最多复习", selection: $settings.maxReviewsPerDay) {
                        ForEach([30, 50, 100, 200, 500], id: \.self) { count in
                            Text("\(count) 个").tag(count)
                        }
                    }
                    .labelsHidden()
                    .tint(Theme.homeMuted)
                }
                SettingRow(
                    icon: "bell",
                    title: "每日提醒",
                    subtitle: notificationsDenied ? "通知权限已关闭，请在系统设置里允许" : nil
                ) {
                    Toggle("每日提醒", isOn: Binding(
                        get: { settings.reminderEnabled },
                        set: { enabled in Task { await setReminder(enabled) } }
                    ))
                    .labelsHidden()
                }
                if settings.reminderEnabled {
                    SettingRow(icon: "clock", title: "提醒时间") {
                        DatePicker("提醒时间", selection: $settings.reminderTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }
                }
                SettingRow(icon: "waveform", title: "口音") {
                    Picker("口音", selection: $settings.accentRaw) {
                        ForEach(SpeechAccent.allCases) { accent in
                            Text(accent.title).tag(accent.rawValue)
                        }
                    }
                    .labelsHidden()
                    .tint(Theme.homeMuted)
                }
                Button {
                    SpeechService.shared.accent = settings.accent
                    SpeechService.shared.speak("Could I get a flat white, please?")
                } label: {
                    SettingRow(icon: "speaker.wave.2", title: "试听一句") { Chevron() }
                }
                .buttonStyle(.plain)
                SettingRow(icon: "globe", title: "母语", subtitle: "单词释义和例句翻译用这种语言") {
                    Picker("母语", selection: Binding(
                        get: { settings.nativeLanguage },
                        set: { chooseLanguage($0) }
                    )) {
                        ForEach(NativeLanguage.allCases) { language in
                            Text(verbatim: language.endonym).tag(language)
                        }
                    }
                    .labelsHidden()
                    .tint(Theme.homeMuted)
                }
                SettingRow(icon: "paintpalette", title: "主题色", showsDivider: false) { EmptyView() }
                ThemePicker(selection: $themeRaw)
                    .padding(.top, 4)
            }
        }
        .onChange(of: settings.newWordsPerDay) { try? context.save(); StudyReminder.refresh(context: context) }
        .onChange(of: settings.maxReviewsPerDay) { try? context.save() }
        .onChange(of: settings.reminderHour) { try? context.save(); StudyReminder.refresh(context: context) }
        .onChange(of: settings.reminderMinute) { try? context.save(); StudyReminder.refresh(context: context) }
        .onChange(of: settings.accentRaw) {
            SpeechService.shared.accent = settings.accent
            try? context.save()
        }
        .confirmationDialog(
            Text("把已有的 \(wordCount) 个词换成\(pendingLanguage?.endonym ?? "")释义？", comment: "Confirm dialog after changing native language; the argument is a language name like Español"),
            isPresented: Binding(get: { pendingLanguage != nil }, set: { if !$0 { pendingLanguage = nil } }),
            titleVisibility: .visible
        ) {
            if let language = pendingLanguage {
                Button("全部换成\(language.endonym)") { applyLanguage(language, regenerate: true) }
                Button("只用于以后的新词") { applyLanguage(language, regenerate: false) }
            }
            Button("取消", role: .cancel) { pendingLanguage = nil }
        } message: {
            Text("需要联网重新生成，场景标题不会改，你可以自己重命名。")
        }
    }

    private func chooseLanguage(_ language: NativeLanguage) {
        guard language != settings.nativeLanguage else { return }
        if wordCount > 0 {
            pendingLanguage = language
        } else {
            applyLanguage(language, regenerate: false)
        }
    }

    private func applyLanguage(_ language: NativeLanguage, regenerate: Bool) {
        settings.nativeLanguage = language
        try? context.save()
        if regenerate { ExplanationQueue.shared.regenerateAll(context: context) }
        pendingLanguage = nil
    }

    private func setReminder(_ enabled: Bool) async {
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

// MARK: - 账号（登录后才显示）

struct AccountCard: View {
    var settings: UserSettings
    var onEditName: () -> Void

    @Environment(\.modelContext) private var context
    @State private var confirmingSignOut = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            MeSectionTitle(title: "账号", note: settings.appleEmail.isEmpty ? nil : "Apple ID · \(AppleAccount.maskedEmail(settings.appleEmail))")
            MeCard(padding: 14) {
                Button(action: onEditName) {
                    SettingRow(icon: "pencil", title: "昵称") {
                        HStack(spacing: 4) {
                            Text(settings.nickname)
                                .font(.system(size: 15))
                                .foregroundStyle(Theme.homeMuted)
                                .lineLimit(1)
                            Chevron()
                        }
                    }
                }
                .buttonStyle(.plain)
                Button { confirmingSignOut = true } label: {
                    SettingRow(icon: "rectangle.portrait.and.arrow.right", title: "退出登录", showsDivider: false) { EmptyView() }
                }
                .buttonStyle(.plain)
            }
        }
        .confirmationDialog("退出登录？", isPresented: $confirmingSignOut, titleVisibility: .visible) {
            Button("退出登录", role: .destructive) { AppleAccount.signOut(settings: settings, context: context) }
            Button("取消", role: .cancel) {}
        } message: {
            Text("场景、单词和学习记录都会留在这台手机上。")
        }
    }
}

// MARK: - 数据

struct DataCard: View {
    var words: [VocabWord]

    @Environment(\.modelContext) private var context
    @State private var confirmingWipe = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            MeSectionTitle(title: "数据")
            MeCard(padding: 14) {
                SettingRow(icon: "lock", title: "照片和单词只存在这台手机上") { EmptyView() }
                ShareLink(item: WordExportFile(rows: WordExport.rows(from: words)), preview: SharePreview(Text("SnapLingo 单词"))) {
                    SettingRow(icon: "square.and.arrow.up", title: "导出单词", subtitle: "表格文件，可以导入 Anki") { Chevron() }
                }
                .buttonStyle(.plain)
                .disabled(words.isEmpty)
                #if DEBUG
                Button {
                    DemoData.seed(into: context)
                } label: {
                    SettingRow(icon: "wand.and.stars", title: "导入示例数据") { EmptyView() }
                }
                .buttonStyle(.plain)
                #endif
                Button { confirmingWipe = true } label: {
                    SettingRow(icon: "trash", title: "清空所有数据", danger: true, showsDivider: false) { EmptyView() }
                }
                .buttonStyle(.plain)
            }
        }
        .confirmationDialog("清空所有场景、单词和学习记录？", isPresented: $confirmingWipe, titleVisibility: .visible) {
            Button("清空", role: .destructive) { WordLibrary.wipeAll(context) }
            Button("取消", role: .cancel) {}
        } message: {
            Text("清空后不能恢复。头像、昵称和设置会保留。")
        }
    }
}

// MARK: - 主题色

/// 一排斑点小圆：点一下换首页和复习页顶部底纹的颜色
struct ThemePicker: View {
    @Binding var selection: String

    var body: some View {
        HStack(spacing: 0) {
            ForEach(HomeTheme.allCases) { theme in
                let selected = HomeTheme(storedValue: selection) == theme
                Button {
                    withAnimation(.snappy) { selection = theme.rawValue }
                } label: {
                    VStack(spacing: 6) {
                        SpeckleBackground(base: theme.base, areaPerSpeck: 30)
                            .frame(width: 38, height: 38)
                            .clipShape(.circle)
                            .overlay(Circle().strokeBorder(Theme.homeInk.opacity(0.08)))
                            .padding(3)
                            .overlay {
                                Circle().stroke(selected ? Theme.homeInk : .clear, lineWidth: 2)
                            }
                        Text(theme.title)
                            .font(.caption2.weight(selected ? .bold : .medium))
                            .foregroundStyle(selected ? Theme.homeInk : Theme.homeMuted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(theme.title)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}
