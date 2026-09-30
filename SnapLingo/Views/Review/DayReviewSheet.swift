//
//  DayReviewSheet.swift
//  SnapLingo
//
//  点日期后弹出的半屏页：那天的照片、地点、遇见的词，和「复习这一天」。
//

import SwiftUI
import SwiftData

/// sheet(item:) 需要 Identifiable
struct PickedDay: Identifiable {
    var date: Date
    var id: Date { date }
}

struct DayReviewSheet: View {
    var day: Date
    var onStudy: () -> Void
    var onOpenScan: (Scan) -> Void
    var onOpenWord: (VocabWord) -> Void

    @Query(sort: \Scan.createdAt) private var allScans: [Scan]

    private var scans: [Scan] {
        allScans.filter { Calendar.current.isDate($0.createdAt, inSameDayAs: day) }
    }

    private var words: [VocabWord] {
        var seen = Set<UUID>()
        return scans.flatMap(\.words)
            .sorted { $0.addedAt < $1.addedAt }
            .filter { seen.insert($0.id).inserted }
    }

    var body: some View {
        let words = words
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header(wordCount: words.count)

                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(scans) { scan in
                            Button { onOpenScan(scan) } label: {
                                ScanThumbnail(scan: scan)
                                    .frame(width: 124, height: 100)
                                    .clipShape(.rect(cornerRadius: 14, style: .continuous))
                            }
                            .buttonStyle(.pressable)
                            .accessibilityLabel("打开场景：\(scan.displayTitle)")
                        }
                    }
                }
                .scrollIndicators(.hidden)

                FlowLayout(spacing: 16) {
                    ForEach(scans) { scan in
                        Label(scan.displayTitle, systemImage: scan.scene.symbol)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.homeInk)
                            .labelStyle(PlaceLabelStyle())
                    }
                }

                if !words.isEmpty {
                    Text("那天遇见的词")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.homeMuted)
                        .padding(.top, 4)
                    FlowLayout(spacing: 8) {
                        ForEach(Array(words.prefix(12).enumerated()), id: \.element.id) { index, word in
                            Button { onOpenWord(word) } label: {
                                Text(word.word)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(Theme.homeInk)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(chipFill(index), in: .capsule)
                                    .overlay(Capsule().strokeBorder(Theme.homeInk.opacity(0.06)))
                            }
                            .buttonStyle(.pressable)
                        }
                    }
                }

                Button(action: onStudy) {
                    HStack(spacing: 10) {
                        Text("复习这一天")
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.cream)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Theme.homeInk, in: .capsule)
                }
                .buttonStyle(.pressable)
                .disabled(words.isEmpty)
                .padding(.top, 8)

                Text(footnote(words))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.homeMuted)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(Theme.sheet)
    }

    private func header(wordCount: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(HomeDates.dateText(for: day))
                .font(.brand(28))
            Text(HomeDates.weekday(for: day))
                .font(.system(size: 14))
                .foregroundStyle(Theme.homeMuted)
            Spacer(minLength: 8)
            Text("\(scans.count) 个场景 · \(wordCount) 个词")
                .font(.system(size: 13))
                .foregroundStyle(Theme.homeMuted)
        }
        .foregroundStyle(Theme.homeInk)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private func chipFill(_ index: Int) -> Color {
        [Theme.sheet, Theme.placeChip, Theme.sheet, Theme.marker.opacity(0.55)][index % 4]
    }

    /// 说清楚哪些词会记入复习、哪些只是再看一遍
    private func footnote(_ words: [VocabWord]) -> String {
        let today = Calendar.current.startOfDay(for: Date())
        let active = words.filter { !$0.excludedFromReview }
        let counted = active.filter { $0.isStudyable(today: today) }.count
        let practice = active.count - counted
        if active.isEmpty { return String(localized: "这天的词都标成已掌握了") }
        if counted == 0 { return String(localized: "这些词都还没到复习时间，这次只是再看一遍，不打乱复习安排") }
        if practice == 0 { return String(localized: "\(counted) 个词会按复习安排记录") }
        return String(localized: "\(counted) 个到期或新词会记入复习，另外 \(practice) 个只是再看一遍")
    }
}

/// 图标用浅灰，文字用墨色
private struct PlaceLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) {
            configuration.icon.foregroundStyle(Theme.homeMuted)
            configuration.title
        }
    }
}
