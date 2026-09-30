//
//  MeView.swift
//  SnapLingo
//
//  「我的」：头像和昵称、可选的 Apple 登录、水平、足迹、设置、账号、数据。
//  视觉和复习页一致：顶部主题色斑点底纹，往下是浅灰底 + 白卡片。
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
        Group {
            if let settings = settingsRows.first {
                content(settings)
            } else {
                ProgressView()
            }
        }
        .background(Theme.mist.ignoresSafeArea())
    }

    private func content(_ settings: UserSettings) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                ProfileHeader(
                    settings: settings,
                    onAvatar: { showingAvatarPicker = true },
                    onName: {
                        nicknameDraft = settings.nickname
                        editingNickname = true
                    },
                    onSignIn: { result in signIn(result, settings: settings) }
                )
                .padding(.top, 14)

                LevelCard(settings: settings) { showingLevelTest = true }
                    .padding(.top, 24)

                FootprintCard(
                    days: MeStats.daysSinceFirst(scans.map(\.createdAt)),
                    scenes: scans.count,
                    words: words.count,
                    streak: DailyPlanner.streak(events: logs),
                    longest: DailyPlanner.longestStreak(events: logs)
                )
                .padding(.top, 14)

                SettingsCard(settings: settings, wordCount: words.count)
                    .padding(.top, 30)

                if settings.isSignedIn {
                    AccountCard(settings: settings) {
                        nicknameDraft = settings.nickname
                        editingNickname = true
                    }
                    .padding(.top, 30)
                }

                DataCard(words: words)
                    .padding(.top, 30)

                Text("SnapLingo \(Bundle.main.shortVersion) · 把生活里遇见的英文变成每天几分钟的复习")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.homeMuted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 28)
                    .padding(.bottom, 40)
            }
            .padding(.horizontal, 20)
            .background(alignment: .top) { ThemeWash().padding(.horizontal, -20) }
        }
        .scrollIndicators(.hidden)
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

    private var header: some View {
        HStack {
            Text("我的")
                .font(.system(size: 30, weight: .heavy))
                .foregroundStyle(Theme.homeInk)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.homeInk)
                    .frame(width: 42, height: 42)
                    .background(Theme.sheet, in: .circle)
                    .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("关闭")
        }
        .frame(height: 50)
        .padding(.top, 12)
        .padding(.horizontal, 4)
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
