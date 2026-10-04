//
//  DayGroupSection.swift
//  SnapLingo
//
//  照片墙的一天：日期（9月29日 ··· 2 个场景 · 13 个词）+ 一排可以左右滑的照片，
//  每个场景是原图加上几张单词所在位置的小图，地点写在它自己的照片下面。
//  天与天之间用 DayDivider 隔开。
//

import SwiftUI

struct DayGroup: Identifiable {
    var day: Date
    var scans: [Scan]
    var id: Date { day }

    var wordCount: Int {
        Set(scans.flatMap { $0.words.map(\.id) }).count
    }
}

struct DayGroupSection: View {
    var group: DayGroup
    /// 第几天（决定空白处放哪张小贴纸）
    var index: Int
    /// 屏幕宽度
    var width: CGFloat
    var scale: CGFloat
    var sidePadding: CGFloat
    var zoom: Namespace.ID

    private var tileHeight: CGFloat { 104 * scale }
    private var photoWidth: CGFloat { tileHeight * 1.22 }
    private var cropWidth: CGFloat { tileHeight * 0.95 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
                .padding(.horizontal, sidePadding)

            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 18) {
                    ForEach(group.scans) { scan in
                        sceneColumn(scan)
                    }
                }
            }
            .contentMargins(.horizontal, sidePadding, for: .scrollContent)
            .scrollIndicators(.hidden)
            .overlay(alignment: .topLeading) { filler }
        }
    }

    /// 这一排照片没占满时，在右边空白处放一张淡淡的小贴纸
    @ViewBuilder
    private var filler: some View {
        let used = group.scans.reduce(CGFloat(0)) { total, scan in
            total + photoWidth + CGFloat(WordCrops.spots(for: scan).count) * (cropWidth + 8)
        } + CGFloat(max(group.scans.count - 1, 0)) * 18
        let start = sidePadding + used + 16
        let end = width - sidePadding
        if end - start > 70 {
            JournalStickerView(kind: JournalSticker.fillers[index % JournalSticker.fillers.count], scale: 1.1)
                .position(x: start + (end - start) * (index.isMultiple(of: 2) ? 0.55 : 0.4), y: tileHeight * (index.isMultiple(of: 2) ? 0.35 : 0.6))
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(HomeDates.dateText(for: group.day))
                .font(.brand(22))
                .foregroundStyle(Theme.homeInk)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            Text("\(group.scans.count) 个场景 · \(group.wordCount) 个词")
                .font(.footnote.weight(.medium))
                .foregroundStyle(Theme.homeMuted)
        }
    }

    // MARK: - 一个场景

    /// 原图 + 单词小图，下面是地点
    private func sceneColumn(_ scan: Scan) -> some View {
        let spots = WordCrops.spots(for: scan)
        let width = photoWidth + CGFloat(spots.count) * (cropWidth + 8)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                NavigationLink(value: scan) {
                    ScanThumbnail(scan: scan)
                        .frame(width: photoWidth, height: tileHeight)
                        .clipShape(.rect(cornerRadius: 14, style: .continuous))
                        .matchedTransitionSource(id: scan.id, in: zoom)
                }
                .buttonStyle(.pressable)
                .sceneContextMenu(scan)
                .accessibilityLabel("\(scan.displayTitle)，\(scan.words.count) 个词")

                ForEach(spots) { spot in
                    NavigationLink(value: spot.word) {
                        WordCropTile(scan: scan, spot: spot)
                            .frame(width: cropWidth, height: tileHeight)
                            .clipShape(.rect(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel("\(spot.word.word)，在照片里的位置")
                }
            }

            NavigationLink(value: scan) {
                HStack(spacing: 6) {
                    Image(systemName: "mappin")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.homeMuted)
                    Text(scan.displayTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.homeInk)
                        .lineLimit(1)
                }
                // 地点名可以比照片宽一点，太长再截断
                .frame(minWidth: 0, maxWidth: max(width, 220), alignment: .leading)
                .fixedSize(horizontal: width < 220, vertical: false)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
    }
}

/// 单词所在位置的小图：第一次显示时在后台裁出来，之后走缓存
private struct WordCropTile: View {
    var scan: Scan
    var spot: WordCrops.Spot
    @State private var image: UIImage?

    var body: some View {
        Rectangle()
            .fill(Theme.insetFill)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .transition(.opacity)
                }
            }
            .clipped()
            .task(id: spot.id) { await load() }
    }

    private func load() async {
        let key = "crop-\(scan.id)-\(spot.word.id)"
        if let cached = ImageCache.shared.cached(key) {
            image = cached
            return
        }
        guard let data = scan.imageData else { return }
        let rect = spot.rect
        let result = await Task.detached(priority: .utility) {
            WordCrops.crop(imageData: data, around: rect)
        }.value
        guard let result else { return }
        ImageCache.shared.store(result, for: key)
        withAnimation(.easeOut(duration: 0.25)) { image = result }
    }
}

// MARK: - 分隔

/// 天与天之间：一条虚线，中间一颗黄色小星；一端点缀一个很小的手帐贴纸，隔几条从左边缘露出半截纸胶带
struct DayDivider: View {
    var index: Int
    var sidePadding: CGFloat

    private var dashes: some View {
        Line()
            .stroke(Theme.homeInk.opacity(0.18), style: StrokeStyle(lineWidth: 1.2, dash: [3, 5]))
            .frame(height: 1)
    }

    var body: some View {
        HStack(spacing: 10) {
            dashes
            StarBurst()
                .stroke(Theme.sparkle, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: 16, height: 16)
            dashes
        }
        .overlay(alignment: index.isMultiple(of: 2) ? .trailing : .leading) {
            JournalStickerView(kind: JournalSticker.accents[index % JournalSticker.accents.count])
                .offset(x: index.isMultiple(of: 2) ? -18 : 28, y: -16)
        }
        .overlay(alignment: .leading) {
            if index % 3 == 1 {
                JournalStickerView(kind: JournalSticker.edgeTapes[(index / 3) % JournalSticker.edgeTapes.count])
                    .offset(x: -sidePadding - 8, y: 10)
            }
        }
        .padding(.horizontal, sidePadding)
        .padding(.vertical, 26)
        .accessibilityHidden(true)
    }
}

private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}
