//
//  MonthCalendarView.swift
//  SnapLingo
//
//  整月日历：拍过东西的日子直接用那天的照片当格子，复习过的日子下面有个小点。
//  点有照片的日子，和复习页的日期圆点一样弹出「这一天」。
//

import SwiftUI
import SwiftData

struct MonthCalendarView: View {
    @State var month: Date
    var onPick: (Date) -> Void

    @Query(sort: \Scan.createdAt) private var scans: [Scan]
    @Query(sort: \ReviewLog.reviewedAt) private var logs: [ReviewLog]

    private let calendar = Calendar.current

    private var days: [ReviewDay] {
        ReviewDays.month(
            containing: month,
            captures: scans.map { CaptureRecord(date: $0.createdAt, wordIDs: Set($0.words.map(\.id))) },
            reviewDates: logs.map(\.reviewedAt)
        )
    }

    private var isCurrentMonth: Bool {
        calendar.isDate(month, equalTo: Date(), toGranularity: .month)
    }

    var body: some View {
        let days = days
        ScrollView {
            VStack(spacing: 18) {
                grid(days)
                stats(days)
                Text("点有照片的日子，复习那一天的词")
                    .font(.caption)
                    .foregroundStyle(Theme.homeMuted)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .background(Theme.cream.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("上个月", systemImage: "chevron.left") { shift(-1) }
                Button("下个月", systemImage: "chevron.right") { shift(1) }
                    .disabled(isCurrentMonth)
            }
        }
        .sensoryFeedback(.selection, trigger: month)
    }

    private var title: String {
        month.formatted(.dateTime.year().month(.wide))
    }

    private func shift(_ value: Int) {
        guard let next = calendar.date(byAdding: .month, value: value, to: month) else { return }
        withAnimation(.snappy) { month = next }
    }

    // MARK: - 月历

    private func grid(_ days: [ReviewDay]) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
        // 星期名跟随语言（日 一 二… / S M T…），从这个地区的一周第一天开始排
        let weekdays = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        let symbols = Array(weekdays[first...] + weekdays[..<first])
        let blanks = ReviewDays.leadingBlanks(forMonthContaining: month, calendar: calendar)
        return VStack(spacing: 12) {
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(Array(symbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption)
                        .foregroundStyle(Theme.homeMuted)
                }
            }
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(0..<blanks, id: \.self) { _ in Color.clear.frame(height: 42) }
                ForEach(days) { day in
                    cell(day)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 18)
        .background(Theme.sheet, in: .rect(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
    }

    @ViewBuilder
    private func cell(_ day: ReviewDay) -> some View {
        let number = calendar.component(.day, from: day.date)
        let isToday = calendar.isDateInToday(day.date)
        let isFuture = day.date > Date()
        if day.hasCaptures, let scan = scans.first(where: { calendar.isDate($0.createdAt, inSameDayAs: day.date) }) {
            Button { onPick(day.date) } label: {
                ScanThumbnail(scan: scan)
                    .frame(width: 42, height: 42)
                    .clipShape(.rect(cornerRadius: 12, style: .continuous))
                    .overlay(alignment: .bottomLeading) {
                        Text("\(number)")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(Theme.homeInk)
                            .padding(.horizontal, 4)
                            .background(Theme.sheet.opacity(0.9), in: .rect(cornerRadius: 6))
                            .padding(3)
                    }
                    .overlay {
                        if isToday {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Theme.shutterRing, lineWidth: 2.5)
                        }
                    }
            }
            .buttonStyle(.pressable)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("\(HomeDates.dateText(for: day.date))，拍了 \(day.scanCount) 个场景，\(day.wordCount) 个词")
        } else {
            VStack(spacing: 4) {
                Text("\(number)")
                    .font(.system(size: 14, weight: day.reviewed || isToday ? .semibold : .regular))
                    .foregroundStyle(isFuture ? Theme.homeMuted.opacity(0.5) : (day.reviewed || isToday ? Theme.homeInk : Theme.homeMuted))
                Circle()
                    .fill(day.reviewed ? Theme.homeInk.opacity(0.28) : .clear)
                    .frame(width: 5, height: 5)
            }
            .frame(width: 42, height: 42)
            .background {
                if isToday { Circle().stroke(Theme.shutterRing, lineWidth: 2).frame(width: 34, height: 34) }
            }
            .frame(maxWidth: .infinity)
            .accessibilityLabel(day.reviewed ? String(localized: "\(HomeDates.dateText(for: day.date))，复习过") : HomeDates.dateText(for: day.date))
        }
    }

    // MARK: - 这个月

    private func stats(_ days: [ReviewDay]) -> some View {
        HStack(spacing: 10) {
            stat(days.filter(\.hasCaptures).count, "天拍了东西")
            stat(days.reduce(0) { $0 + $1.wordCount }, "个新词")
            stat(days.filter(\.reviewed).count, "天复习过")
        }
    }

    private func stat(_ value: Int, _ label: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(.brand(28))
                .foregroundStyle(Theme.homeInk)
                .contentTransition(.numericText())
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.homeMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.sheet, in: .rect(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
