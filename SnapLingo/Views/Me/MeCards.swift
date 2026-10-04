//
//  MeCards.swift
//  SnapLingo
//
//  「我的」页：水平、足迹两张白卡片；设置、账号、数据是系统列表的分组。
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

// MARK: - 我的水平

struct LevelCard: View {
    var settings: UserSettings
    var onRetest: () -> Void

    var body: some View {
        let level = settings.level
        MeCard {
            HStack(alignment: .firstTextBaseline) {
                Text("我的水平")
                    .font(.headline.weight(.heavy))
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button(action: onRetest) {
                    Label("重新测一次", systemImage: "arrow.clockwise")
                        .font(.footnote.weight(.bold))
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
                .font(.subheadline)
                .foregroundStyle(Theme.homeInk.opacity(0.75))
                .padding(.top, 4)

            if let next = level.next {
                let progress = CEFRLevel.progressWithinLevel(score: settings.levelScore)
                HStack {
                    Text("离「\(next.displayName)」还差一点")
                        .font(.caption.weight(.semibold))
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
                    .font(.caption.weight(.semibold))
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
                .font(.headline.weight(.heavy))
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
                    .foregroundStyle(Theme.brand)
                Text("连续 \(streak) 天")
                    .fontWeight(.semibold)
                Text("· 最长 \(longest) 天")
                    .foregroundStyle(Theme.homeMuted)
            }
            .font(.subheadline)
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
                        .font(.footnote.weight(.semibold))
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

/// 设置分组：系统列表的样式（和 iPhone 设置 App 一致），放在 MeView 的 List 里
struct SettingsCard: View {
    @Bindable var settings: UserSettings

    @Environment(\.modelContext) private var context
    @AppStorage(HomeTheme.storageKey) private var themeRaw = HomeTheme.sky.rawValue
    @State private var notificationsDenied = false

    var body: some View {
        Section {
            Picker(selection: $settings.newWordsPerDay) {
                ForEach(StudyPace.dailyOptions, id: \.self) { count in
                    Text("\(count) 个").tag(count)
                }
            } label: {
                Label("每天学新词", systemImage: "plus")
            }
            Picker(selection: $settings.maxReviewsPerDay) {
                ForEach([30, 50, 100, 200, 500], id: \.self) { count in
                    Text("\(count) 个").tag(count)
                }
            } label: {
                Label("每天最多复习", systemImage: "arrow.2.squarepath")
            }
            Toggle(isOn: Binding(
                get: { settings.reminderEnabled },
                set: { enabled in Task { await setReminder(enabled) } }
            )) {
                Label {
                    Text("每日提醒")
                    if notificationsDenied {
                        Text("通知权限已关闭，请在系统设置里允许")
                    }
                } icon: {
                    Image(systemName: "bell")
                }
            }
            if settings.reminderEnabled {
                DatePicker(selection: $settings.reminderTime, displayedComponents: .hourAndMinute) {
                    Label("提醒时间", systemImage: "clock")
                }
            }
            // 绑到 accent 而不是 accentRaw：旧版本存的 en-NZ 等值会被映射成现有选项，不会显示成空白
            Picker(selection: Binding(
                get: { settings.accent },
                set: { settings.accent = $0 }
            )) {
                ForEach(SpeechAccent.allCases) { accent in
                    Text(accent.title).tag(accent)
                }
            } label: {
                Label("口音", systemImage: "waveform")
            }
            Button {
                SpeechService.shared.accent = settings.accent
                SpeechService.shared.speak("Could I get a flat white, please?")
            } label: {
                Label("试听一句", systemImage: "speaker.wave.2")
            }
            .foregroundStyle(Theme.homeInk)
            // 界面语言跟随 iOS，这里只是跳到 iPhone 设置里 Magpie 那一页
            Button {
                InterfaceLanguage.openSystemSettings()
            } label: {
                LabeledContent {
                    HStack(spacing: 6) {
                        Text(verbatim: InterfaceLanguage.current.endonym)
                        // 跳出 App 到系统设置：用斜箭头
                        Image(systemName: "arrow.up.forward")
                            .font(.footnote.weight(.semibold))
                    }
                } label: {
                    Label {
                        Text("界面语言")
                        Text("在 iPhone 设置里更改")
                            .foregroundStyle(.secondary)
                    } icon: {
                        Image(systemName: "character.bubble")
                    }
                }
            }
            .foregroundStyle(Theme.homeInk)
            VStack(alignment: .leading, spacing: 10) {
                Label("主题色", systemImage: "paintpalette")
                ThemePicker(selection: $themeRaw)
            }
            .padding(.vertical, 4)
        } header: {
            Text("设置")
        }
        .onChange(of: settings.newWordsPerDay) { try? context.save(); StudyReminder.refresh(context: context) }
        .onChange(of: settings.maxReviewsPerDay) { try? context.save() }
        .onChange(of: settings.reminderHour) { try? context.save(); StudyReminder.refresh(context: context) }
        .onChange(of: settings.reminderMinute) { try? context.save(); StudyReminder.refresh(context: context) }
        .onChange(of: settings.accentRaw) {
            SpeechService.shared.accent = settings.accent
            try? context.save()
        }
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
        Section {
            Button(action: onEditName) {
                LabeledContent {
                    Text(settings.nickname)
                        .lineLimit(1)
                } label: {
                    Label("昵称", systemImage: "pencil")
                }
            }
            .foregroundStyle(Theme.homeInk)
            Button("退出登录", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                confirmingSignOut = true
            }
        } header: {
            Text("账号")
        } footer: {
            if !settings.appleEmail.isEmpty {
                Text(verbatim: "Apple ID · \(AppleAccount.maskedEmail(settings.appleEmail))")
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
    @State private var showingConsent = false
    @AppStorage(AIConsent.storageKey) private var consentRaw = AIConsent.State.undecided.rawValue

    var body: some View {
        Section {
            // 打开时先看一遍说明再同意；关掉立刻生效
            Toggle(isOn: Binding(
                get: { consentRaw == AIConsent.State.granted.rawValue },
                set: { on in
                    if on { showingConsent = true } else { consentRaw = AIConsent.State.declined.rawValue }
                }
            )) {
                Label {
                    Text("AI 挑词和释义")
                    Text("识别出的文字会发给 Anthropic 的 Claude")
                } icon: {
                    Image(systemName: "sparkles")
                }
            }
            ShareLink(item: WordExportFile(rows: WordExport.rows(from: words)), preview: SharePreview(Text("Magpie 单词"))) {
                Label {
                    Text("导出单词")
                    Text("表格文件，可以导入 Anki")
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
            .foregroundStyle(Theme.homeInk)
            .disabled(words.isEmpty)
            #if DEBUG
            Button("导入示例数据", systemImage: "wand.and.stars") {
                DemoData.seed(into: context)
            }
            .foregroundStyle(Theme.homeInk)
            #endif
            Button("清空所有数据", systemImage: "trash", role: .destructive) {
                confirmingWipe = true
            }
        } header: {
            Text("数据")
        } footer: {
            Text("照片和单词只存在这台手机上。")
        }
        .sheet(isPresented: $showingConsent) {
            AIConsentSheet()
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
        HStack(spacing: 4) {
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
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
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
