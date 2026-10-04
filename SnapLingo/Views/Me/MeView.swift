//
//  MeView.swift
//  SnapLingo
//
//  「我的」：头像和昵称、可选的 Apple 登录、水平、足迹、设置、账号、数据。
//  系统导航栏 + 分组列表；顶部保留主题色斑点底纹和头像、水平、足迹三张卡片。
//

import AuthenticationServices
import SwiftData
import SwiftUI

struct MeView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \UserSettings.createdAt) private var settingsRows: [UserSettings]
    @Query private var words: [VocabWord]
    @Query(sort: \Scan.createdAt) private var scans: [Scan]
    @Query(sort: \ReviewLog.reviewedAt) private var logs: [ReviewLog]

    @State private var showingLevelTest = false
    @State private var showingAvatarPicker = false
    @State private var editingNickname = false
    @State private var nicknameDraft = ""
    @State private var signInError: String?

    var body: some View {
        NavigationStack {
            Group {
                if let settings = settingsRows.first {
                    content(settings)
                } else {
                    ProgressView()
                }
            }
            .background(Theme.mist.ignoresSafeArea())
        }
        // 图标、选择器、关闭按钮用墨色，和首页一致（系统默认会用橙色主色）
        .tint(Theme.homeInk)
    }

    private func content(_ settings: UserSettings) -> some View {
        // 系统分组列表：设置、账号、数据和 iPhone 设置 App 一样；上面三张卡片保留自己的样式
        List {
            Section {
                ProfileHeader(
                    settings: settings,
                    onAvatar: { showingAvatarPicker = true },
                    onName: {
                        nicknameDraft = settings.nickname
                        editingNickname = true
                    },
                    onSignIn: { result in signIn(result, settings: settings) }
                )
                LevelCard(settings: settings) { showingLevelTest = true }
                    .padding(.top, 10)
                FootprintCard(
                    days: MeStats.daysSinceFirst(scans.map(\.createdAt)),
                    scenes: scans.count,
                    words: words.count,
                    streak: DailyPlanner.streak(events: logs),
                    longest: DailyPlanner.longestStreak(events: logs)
                )
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 14, trailing: 0))
            .listRowSeparator(.hidden)

            SettingsCard(settings: settings)

            if settings.isSignedIn {
                AccountCard(settings: settings) {
                    nicknameDraft = settings.nickname
                    editingNickname = true
                }
            }

            DataCard(words: words)

            Section {
                Text("Magpie \(Bundle.main.shortVersion) · 把生活里遇见的英文变成每天几分钟的复习")
                    .font(.footnote)
                    .foregroundStyle(Theme.homeMuted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(alignment: .top) { ThemeWash().ignoresSafeArea() }
        .navigationTitle("我的")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .close) { dismiss() }
            }
        }
        .sheet(isPresented: $showingAvatarPicker) {
            AvatarPickerSheet(settings: settings)
                .presentationDetents([.height(360)])
                .presentationDragIndicator(.visible)
        }
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
        .alert("昵称", isPresented: $editingNickname) {
            TextField("给自己起个名字", text: $nicknameDraft)
            Button("取消", role: .cancel) {}
            Button("保存") {
                settings.nickname = nicknameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                try? context.save()
            }
        }
        .alert("登录没有成功", isPresented: Binding(get: { signInError != nil }, set: { if !$0 { signInError = nil } })) {
            Button("好", role: .cancel) {}
        } message: {
            Text(signInError ?? "")
        }
    }

    private func signIn(_ result: Result<ASAuthorization, Error>, settings: UserSettings) {
        if case .failed(let message) = AppleAccount.handle(result, settings: settings, context: context) {
            signInError = message
        }
    }
}

extension Bundle {
    var appVersion: String {
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(shortVersion) (\(build))"
    }

    var shortVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}
