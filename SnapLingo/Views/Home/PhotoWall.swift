//
//  PhotoWall.swift
//  SnapLingo
//
//  首页顶部的照片墙：最近一次拍照那天的照片，排成稍微歪着的小方块。
//  尺寸按 390pt 宽的设计稿给出，再按屏幕宽度等比缩放。
//

import SwiftUI

struct PhotoWall: View {
    var photos: [Scan]
    var label: String
    /// 设计稿（390pt 宽）到当前屏幕的缩放
    var scale: CGFloat
    var appeared: Bool
    /// 系统开了“减弱动态效果”时为 false
    var animated = true
    var onOpen: (Scan) -> Void

    static let maxPhotos = 6
    private static let columns = 3
    private static let rotations: [Double] = [-3, 2, -1.5, 2.5, -2, 1.5]

    /// 标签那一行的设计稿高度
    private static let labelHeight: CGFloat = 34

    /// 设计稿坐标系里的高度：随张数变化（空位 / 1–2 张 / 一行 / 两行）
    static func designHeight(photoCount: Int) -> CGFloat {
        labelHeight + tileSize(photoCount).height * CGFloat(rows(photoCount)) + gap * CGFloat(rows(photoCount) - 1)
    }

    private static let gap: CGFloat = 12

    private static func rows(_ count: Int) -> Int {
        count <= columns ? 1 : 2
    }

    private static func tileSize(_ count: Int) -> CGSize {
        switch count {
        case 0, 1: CGSize(width: 170, height: 150)
        case 2: CGSize(width: 140, height: 130)
        default: CGSize(width: 96, height: 96)
        }
    }

    private var shown: [Scan] { Array(photos.prefix(Self.maxPhotos)) }
    private var hiddenCount: Int { max(0, photos.count - Self.maxPhotos) }

    var body: some View {
        VStack(spacing: 0) {
            label(for: label)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .frame(height: Self.labelHeight * scale, alignment: .bottom)
                .padding(.trailing, 26 * scale)

            if shown.isEmpty {
                EmptyPhotoSlot(scale: scale)
                    .frame(width: Self.tileSize(0).width * scale, height: Self.tileSize(0).height * scale)
                    .rotationEffect(.degrees(appeared ? -3 : 6))
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 30)
                    .animation(animated ? .spring(response: 0.62, dampingFraction: 0.68) : nil, value: appeared)
            } else {
                grid
            }
        }
        .frame(width: 390 * scale, height: Self.designHeight(photoCount: shown.count) * scale, alignment: .top)
    }

    private var grid: some View {
        let size = Self.tileSize(shown.count)
        let rows = stride(from: 0, to: shown.count, by: Self.columns).map { Array(shown[$0..<min($0 + Self.columns, shown.count)]) }
        return VStack(spacing: Self.gap * scale) {
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                HStack(spacing: Self.gap * scale) {
                    ForEach(Array(row.enumerated()), id: \.offset) { column, scan in
                        let index = rowIndex * Self.columns + column
                        tile(scan, index: index, isLast: index == shown.count - 1)
                            .frame(width: size.width * scale, height: size.height * scale)
                    }
                }
            }
        }
    }

    private func tile(_ scan: Scan, index: Int, isLast: Bool) -> some View {
        Button { onOpen(scan) } label: {
            PolaroidPhoto(scan: scan, scale: scale, border: shown.count > 2 ? 4 : 6)
                .overlay {
                    if isLast && hiddenCount > 0 {
                        RoundedRectangle(cornerRadius: 12 * scale, style: .continuous)
                            .fill(.black.opacity(0.45))
                            .padding(4 * scale)
                            .overlay {
                                Text(verbatim: "+\(hiddenCount)")
                                    .font(.brand(26 * scale))
                                    .foregroundStyle(.white)
                            }
                    }
                }
        }
        .buttonStyle(.pressable)
        .rotationEffect(.degrees(appeared ? Self.rotations[index % Self.rotations.count] : Self.rotations[index % Self.rotations.count] + 8))
        .scaleEffect(appeared ? 1 : 0.85)
        .offset(y: appeared ? 0 : 24)
        .opacity(appeared ? 1 : 0)
        .animation(animated ? .spring(response: 0.6, dampingFraction: 0.7).delay(0.06 * Double(index)) : nil, value: appeared)
        .accessibilityLabel(scan.displayTitle)
    }

    /// 右上角的手写标签 + 闪光线 + 波浪线
    private func label(for text: String) -> some View {
        HStack(alignment: .top, spacing: 0) {
            SparkleLines()
                .trim(from: 0, to: appeared ? 1 : 0)
                .stroke(Theme.sparkle, style: StrokeStyle(lineWidth: 3 * scale, lineCap: .round))
                .frame(width: 26 * scale, height: 26 * scale)
                .offset(y: -6 * scale)
                .animation(animated ? .easeOut(duration: 0.4).delay(0.75) : nil, value: appeared)
                .accessibilityHidden(true)
            VStack(alignment: .trailing, spacing: 0) {
                HandwrittenLabel(text: text, size: 24 * scale, revealed: appeared)
                    .animation(animated ? .easeOut(duration: 0.7).delay(0.8) : nil, value: appeared)
                Squiggle()
                    .trim(from: 0, to: appeared ? 1 : 0)
                    .stroke(Theme.sparkle, style: StrokeStyle(lineWidth: 2.5 * scale, lineCap: .round))
                    .frame(width: 64 * scale, height: 6 * scale)
                    .rotationEffect(.degrees(-8))
                    .padding(.trailing, 6 * scale)
                    .animation(animated ? .easeOut(duration: 0.5).delay(1.3) : nil, value: appeared)
                    .accessibilityHidden(true)
            }
        }
    }
}

// MARK: - 单张照片

/// 白边圆角照片，像随手拍的拍立得
struct PolaroidPhoto: View {
    var scan: Scan
    var scale: CGFloat
    var border: CGFloat = 7

    var body: some View {
        ScanThumbnail(scan: scan)
            .clipShape(.rect(cornerRadius: (16 - border + 2) * scale, style: .continuous))
            .padding(border * scale)
            .background(Theme.sheet, in: .rect(cornerRadius: 16 * scale, style: .continuous))
            .shadow(color: .black.opacity(0.14), radius: 10 * scale, y: 7 * scale)
    }
}

/// 虚线空位：第一张照片
private struct EmptyPhotoSlot: View {
    var scale: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: 16 * scale, style: .continuous)
            .fill(Theme.sheet.opacity(0.75))
            .overlay {
                RoundedRectangle(cornerRadius: 16 * scale, style: .continuous)
                    .strokeBorder(Theme.homeInk.opacity(0.22), style: StrokeStyle(lineWidth: 2.5, dash: [7, 6]))
            }
            .overlay {
                VStack(spacing: 8 * scale) {
                    Image(systemName: "camera")
                        .font(.system(size: 30 * scale, weight: .regular))
                    Text("今天的第一张")
                        .font(.system(size: 13 * scale, weight: .semibold))
                }
                .foregroundStyle(Theme.homeMuted)
            }
    }
}
