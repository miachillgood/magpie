//
//  DayGroupSection.swift
//  SnapLingo
//
//  白色底板上的一天：标题（今天 9 月 28 日）+ 一排照片 + 地点和词数。
//

import SwiftUI

struct DayGroup: Identifiable {
    var day: Date
    var scans: [Scan]
    var id: Date { day }

    var wordCount: Int {
        Set(scans.flatMap { $0.words.map(\.id) }).count
    }

    /// “公交站 · 商场走廊”，超过两个地点时加“等”
    var caption: String {
        var titles: [String] = []
        for title in scans.map(\.displayTitle) where !titles.contains(title) {
            titles.append(title)
        }
        let shown = titles.prefix(2).joined(separator: " · ")
        return titles.count > 2 ? shown + " 等" : shown
    }
}

struct DayGroupSection: View {
    var group: DayGroup
    var scale: CGFloat
    var zoom: Namespace.ID

    private var isToday: Bool { Calendar.current.isDateInToday(group.day) }
    private var tileHeight: CGFloat { 100 * scale }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            photos
            VStack(alignment: .leading, spacing: 4) {
                Text(group.caption)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.homeInk)
                    .lineLimit(1)
                Text("\(group.wordCount) 个词 · \(group.scans.count) 个场景")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.homeMuted)
            }
        }
    }

    private var header: some View {
        let name = HomeDates.dayName(for: group.day)
        let date = HomeDates.dateText(for: group.day)
        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            if let name {
                Text(name)
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(Theme.homeInk)
                Text(date)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.homeMuted)
            } else {
                Text(date)
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(Theme.homeInk)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: - 照片

    /// 一天最多排三张；张数不同时宽度比例不同
    private var photos: some View {
        let shown = Array(group.scans.prefix(3))
        let weights: [CGFloat] = switch shown.count {
        case 1: [1]
        case 2: [1.25, 1]
        default: [1, 1.25, 1]
        }
        let hidden = group.scans.count - shown.count

        return GeometryReader { proxy in
            let gap: CGFloat = 8
            let usable = shown.count == 1 ? proxy.size.width * 0.62 : proxy.size.width - gap * CGFloat(shown.count - 1)
            let total = weights.reduce(0, +)
            HStack(spacing: gap) {
                ForEach(Array(shown.enumerated()), id: \.element.id) { index, scan in
                    NavigationLink(value: scan) {
                        tile(scan, lifted: isToday && index == 1, extra: index == shown.count - 1 ? hidden : 0)
                            .frame(width: usable * weights[index] / total, height: tileHeight)
                            .matchedTransitionSource(id: scan.id, in: zoom)
                            .overlay(alignment: .topTrailing) {
                                // 今天那组的最后一张贴一个 New!
                                if isToday && index == shown.count - 1 {
                                    NewTag().offset(x: 10, y: -16)
                                }
                            }
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel("\(scan.displayTitle)，\(scan.words.count) 个词")
                }
            }
        }
        .frame(height: tileHeight)
    }

    @ViewBuilder
    private func tile(_ scan: Scan, lifted: Bool, extra: Int) -> some View {
        let photo = ScanThumbnail(scan: scan)
            .overlay {
                if extra > 0 {
                    Color.black.opacity(0.35)
                    Text("+\(extra)")
                        .font(.brand(22))
                        .foregroundStyle(.white)
                }
            }
        if lifted {
            photo
                .clipShape(.rect(cornerRadius: 13, style: .continuous))
                .padding(4)
                .background(Theme.sheet, in: .rect(cornerRadius: 17, style: .continuous))
                .shadow(color: .black.opacity(0.16), radius: 10, y: 8)
                .rotationEffect(.degrees(3))
                .zIndex(1)
        } else {
            photo
                .clipShape(.rect(cornerRadius: 14, style: .continuous))
        }
    }
}
