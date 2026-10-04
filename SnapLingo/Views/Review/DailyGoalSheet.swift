//
//  DailyGoalSheet.swift
//  SnapLingo
//
//  调每天新词目标的小面板：在复习页点「新词 0/10 ✎」打开。目标显示在哪里就在哪里改，
//  不用去「我的」里找。复习量由算法排（到期的全部复习），这里不让用户定。
//

import SwiftUI
import SwiftData

struct DailyGoalSheet: View {
    @Bindable var settings: UserSettings

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    /// 按内容高度定面板高度：字调大了也不会被截断
    @State private var contentHeight: CGFloat = 230

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("每天学几个新词")
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(Theme.homeInk)
                .accessibilityAddTraits(.isHeader)
            Text("到期的复习会先排，不算在里面")
                .font(.subheadline)
                .foregroundStyle(Theme.homeMuted)
                .padding(.top, 4)

            HStack(spacing: 8) {
                ForEach(StudyPace.dailyOptions, id: \.self) { count in
                    option(count)
                }
            }
            .padding(.top, 22)
            .sensoryFeedback(.selection, trigger: settings.newWordsPerDay)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, 28)
        .padding(.bottom, Spacing.lg)
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.cream.ignoresSafeArea())
        .presentationDetents([.height(contentHeight)])
        .presentationDragIndicator(.visible)
    }

    private func option(_ count: Int) -> some View {
        let selected = settings.newWordsPerDay == count
        return Button {
            pick(count)
        } label: {
            VStack(spacing: 2) {
                Text(verbatim: "\(count)")
                    .font(.brand(24))
                Text("约 \(StudyPace.minutes(forNewWords: count)) 分钟", comment: "Under a daily new-word goal option: about N minutes a day")
                    .font(.caption2.weight(.medium))
                    .opacity(0.7)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(selected ? Theme.cream : Theme.homeInk)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(selected ? Theme.homeInk : Theme.sheet, in: .rect(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Theme.homeInk.opacity(selected ? 0 : 0.06))
            )
        }
        .buttonStyle(.pressable)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    private func pick(_ count: Int) {
        withAnimation(.snappy(duration: 0.2)) { settings.newWordsPerDay = count }
        // 自己调过目标，结算页就不用再问「节奏合适吗？」
        settings.paceCheckDone = true
        try? context.save()
        StudyReminder.refresh(context: context)
        Task {
            try? await Task.sleep(for: .milliseconds(250))
            dismiss()
        }
    }
}
