//
//  SessionCompleteView.swift
//  SnapLingo
//

import SwiftUI
import SwiftData

/// 学完一轮的结算页：手写的 Nice! + 撒彩纸的喜鹊，今天完成了多少词，新学 / 复习 / 重练三格
struct SessionCompleteView: View {
    let session: StudySession
    /// 今天还有要学的词：再开一轮今日计划
    var onContinue: () -> Void
    /// 今天的计划学完了、还有新词在排队：多学 5 个
    var onMore: () -> Void
    var onDone: () -> Void

    @Query private var words: [VocabWord]
    @Query(sort: \ReviewLog.reviewedAt) private var logs: [ReviewLog]
    @Query(sort: \UserSettings.createdAt) private var settingsRows: [UserSettings]
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var celebrate = 0
    @State private var appeared = false
    /// 这一屏里刚回答过「节奏合适吗？」，显示调整后的结果
    @State private var paceAnswered = false

    private var plan: DailyPlan {
        guard let settings = settingsRows.first else { return .empty }
        return StudyStore.plan(settings: settings, words: words, logs: logs)
    }

    private var backlog: Int { words.filter { $0.state == .new && !$0.excludedFromReview }.count }

    /// 今天点过“不会”的词（同一个词只算一次）
    private var relearnedToday: Int {
        Set(logs.filter { Calendar.current.isDateInToday($0.reviewedAt) && $0.rating == .again }.map(\.wordID)).count
    }

    /// 第一次有新词因为每日上限在排队时，问一次节奏（只在今日计划里问）
    private var showsPaceCheck: Bool {
        guard let settings = settingsRows.first, case .today = session.scope else { return false }
        return paceAnswered || StudyPace.shouldAsk(plan: plan, backlog: backlog, asked: settings.paceCheckDone)
    }

    /// 主按钮：还有要学的就继续，计划学完了还有新词就多学几个，都没有就不放
    private var primary: (title: LocalizedStringKey, action: () -> Void)? {
        if plan.hasWork { return ("继续复习", onContinue) }
        if backlog > 0 { return ("再学 5 个新词", onMore) }
        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: Spacing.md)

            // 和介绍页一样，手写字所有语言都用英文
            Text(verbatim: plan.doneToday > 0 ? "Nice!" : "All clear!")
                .font(.custom("ChalkboardSE-Bold", size: 46))
                .foregroundStyle(Theme.homeInk)
                .rotationEffect(.degrees(-5))
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : -12)
                .animation(motion(.spring(response: 0.5, dampingFraction: 0.6), delay: 0.05), value: appeared)
                .accessibilityAddTraits(.isHeader)

            Image("CelebrateMagpie")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: showsPaceCheck ? 170 : 260)
                .scaleEffect(appeared ? 1 : 0.5, anchor: .bottom)
                .rotationEffect(.degrees(appeared ? 0 : -12), anchor: .bottom)
                .opacity(appeared ? 1 : 0)
                .animation(motion(.spring(response: 0.6, dampingFraction: 0.5), delay: 0.15), value: appeared)
                .padding(.top, Spacing.sm)
                .accessibilityHidden(true)

            VStack(spacing: 2) {
                if plan.doneToday > 0 {
                    Text("今天完成了")
                        .font(.headline.weight(.bold))
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(appeared ? plan.doneToday : 0, format: .number)
                            .font(.system(size: 52, weight: .heavy, design: .rounded))
                            .contentTransition(.numericText())
                            .animation(motion(.smooth(duration: 0.8), delay: 0.35), value: appeared)
                        // 英文等语言要分单复数（1 word / 8 words），数字单独显示，所以按数量选两条字符串
                        Group {
                            if plan.doneToday == 1 {
                                Text("session.wordsUnit.one", comment: "Unit after the big number 1 on the session complete page (1 word)")
                            } else {
                                Text("session.wordsUnit.other", comment: "Unit after the big number on the session complete page when it isn't 1 (8 words)")
                            }
                        }
                        .font(.title3.weight(.bold))
                    }
                } else {
                    Text("今天没有要学的词")
                        .font(.title3.weight(.bold))
                }
            }
            .foregroundStyle(Theme.homeInk)
            .padding(.top, Spacing.sm)
            .modifier(Entrance(appeared: appeared, delay: 0.3, reduceMotion: reduceMotion))

            if plan.doneToday > 0 {
                HStack(spacing: Spacing.sm) {
                    tile(plan.newDone, label: "新学", color: Color(UIColor(hex: 0x4A8FD8)))
                    tile(plan.reviewsDone, label: "复习", color: Color(UIColor(hex: 0xF0A12E)))
                    tile(relearnedToday, label: "重练", color: Color(UIColor(hex: 0xE05A4E)))
                }
                .padding(.top, Spacing.lg)
                .modifier(Entrance(appeared: appeared, delay: 0.45, reduceMotion: reduceMotion))
            }

            if showsPaceCheck, let settings = settingsRows.first {
                PaceCheckCard(settings: settings, newDone: plan.newDone, backlog: backlog, answered: paceAnswered) { step in
                    answerPace(settings: settings, step: step)
                }
                .padding(.top, Spacing.md)
                .modifier(Entrance(appeared: appeared, delay: 0.55, reduceMotion: reduceMotion))
            }

            Spacer(minLength: Spacing.md)

            VStack(spacing: Spacing.sm) {
                if let primary {
                    PrimaryButton(title: primary.title, action: primary.action)
                    SecondaryButton(title: "回到首页", action: onDone)
                } else {
                    PrimaryButton(title: "回到首页", action: onDone)
                }
            }
            .modifier(Entrance(appeared: appeared, delay: 0.6, reduceMotion: reduceMotion))
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.md)
        .sensoryFeedback(.success, trigger: celebrate)
        .onAppear {
            celebrate += 1
            appeared = true
        }
    }

    private func answerPace(settings: UserSettings, step: Int) {
        withAnimation(.snappy) {
            settings.newWordsPerDay = StudyPace.adjusted(settings.newWordsPerDay, by: step)
            settings.paceCheckDone = true
            paceAnswered = true
        }
        try? context.save()
        StudyReminder.refresh(context: context)
    }

    private func motion(_ animation: Animation, delay: Double) -> Animation? {
        reduceMotion ? nil : animation.delay(delay)
    }

    private func tile(_ value: Int, label: LocalizedStringKey, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value, format: .number)
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.homeInk.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.md + 2)
        .background(Theme.card, in: .rect(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
        .accessibilityElement(children: .combine)
    }
}

/// 「节奏合适吗？」：少一点 / 刚好 / 多一点，往下或往上挪一档；答完换成一句结果
private struct PaceCheckCard: View {
    let settings: UserSettings
    var newDone: Int
    var backlog: Int
    var answered: Bool
    var onAnswer: (Int) -> Void

    var body: some View {
        VStack(spacing: Spacing.sm) {
            if answered {
                Text("以后每天 \(settings.newWordsPerDay) 个新词，可以在复习页上改")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.homeMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 4) {
                    Text("节奏合适吗？")
                        .font(.headline.weight(.heavy))
                    Text("今天的 \(newDone) 个新词学完了，还有 \(backlog) 个在排队。")
                        .font(.subheadline)
                        .foregroundStyle(Theme.homeMuted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: Spacing.xs) {
                    choice("少一点", step: -1)
                    choice("刚好", step: 0)
                    choice("多一点", step: 1)
                }
            }
        }
        .foregroundStyle(Theme.homeInk)
        .frame(maxWidth: .infinity)
        .padding(Spacing.md)
        .background(Theme.sheet, in: .rect(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
    }

    private func choice(_ title: LocalizedStringKey, step: Int) -> some View {
        Button { onAnswer(step) } label: {
            Text(title)
                .font(.subheadline.weight(.heavy))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(step == 0 ? Theme.homeInk : Theme.insetFill, in: .capsule)
                .foregroundStyle(step == 0 ? Theme.cream : Theme.homeInk)
        }
        .buttonStyle(.pressable)
    }
}
