//
//  PhotoStack.swift
//  SnapLingo
//
//  首页顶部那一叠歪着的照片。位置按 390pt 宽的设计稿给出，再按屏幕宽度等比缩放。
//

import SwiftUI

struct PhotoStack: View {
    enum Style {
        /// 一叠：主图在左、另外两张往右错开（刚拍完 / 有待复习）
        case pile
        /// 扇形摊开四张（本周回顾）
        case fan
        /// 最上面是一个虚线空位（今天还没拍）
        case emptySlot
    }

    var photos: [Scan]
    var style: Style
    var label: String
    /// 设计稿（390pt 宽）到当前屏幕的缩放
    var scale: CGFloat
    var appeared: Bool
    /// 系统开了“减弱动态效果”时为 false
    var animated = true

    /// 设计稿坐标系里的高度
    static let designHeight: CGFloat = 172

    private struct Slot {
        var x, y, w, h, rotation: CGFloat
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(placed.enumerated()), id: \.offset) { index, item in
                Group {
                    if let scan = item.scan {
                        PolaroidPhoto(scan: scan, scale: scale, border: style == .fan ? 5 : 6)
                    } else {
                        EmptyPhotoSlot(scale: scale)
                    }
                }
                .frame(width: item.slot.w * scale, height: item.slot.h * scale)
                .rotationEffect(.degrees(appeared ? item.slot.rotation : item.slot.rotation + 10))
                .scaleEffect(appeared ? 1 : 0.9)
                .offset(x: item.slot.x * scale, y: item.slot.y * scale + (appeared ? 0 : 30))
                .opacity(appeared ? 1 : 0)
                .animation(animated ? .spring(response: 0.62, dampingFraction: 0.68).delay(0.08 * Double(index)) : nil, value: appeared)
            }

        }
        .frame(width: 390 * scale, height: Self.designHeight * scale, alignment: .topLeading)
        .overlay(alignment: .topTrailing) {
            // 手写标签靠右放，长一点的（Still remember?）也不会超出屏幕
            HStack(alignment: .top, spacing: 0) {
                SparkleLines()
                    .trim(from: 0, to: appeared ? 1 : 0)
                    .stroke(Theme.sparkle, style: StrokeStyle(lineWidth: 3 * scale, lineCap: .round))
                    .frame(width: 30 * scale, height: 30 * scale)
                    .offset(y: -10 * scale)
                    .animation(animated ? .easeOut(duration: 0.4).delay(0.75) : nil, value: appeared)
                    .accessibilityHidden(true)
                VStack(alignment: .trailing, spacing: 0) {
                    HandwrittenLabel(text: label, size: 25 * scale, revealed: appeared)
                        .animation(animated ? .easeOut(duration: 0.7).delay(0.8) : nil, value: appeared)
                    Squiggle()
                        .trim(from: 0, to: appeared ? 1 : 0)
                        .stroke(Theme.sparkle, style: StrokeStyle(lineWidth: 2.5 * scale, lineCap: .round))
                        .frame(width: 70 * scale, height: 7 * scale)
                        .rotationEffect(.degrees(-8))
                        .padding(.trailing, 6 * scale)
                        .animation(animated ? .easeOut(duration: 0.5).delay(1.3) : nil, value: appeared)
                        .accessibilityHidden(true)
                }
            }
            .padding(.trailing, labelTrailing * scale)
            .offset(y: labelTop * scale)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    // MARK: - 摆放

    /// 按绘制顺序（先画的在下面）
    private var placed: [(scan: Scan?, slot: Slot)] {
        switch style {
        case .pile:
            let main = Slot(x: 64, y: 26, w: 138, h: 128, rotation: -8)
            let middle = Slot(x: 176, y: 34, w: 106, h: 112, rotation: 4)
            let right = Slot(x: 250, y: 58, w: 102, h: 106, rotation: 9)
            switch photos.count {
            case 0: return [(nil, main)]
            case 1: return [(photos[0], main)]
            case 2: return [(photos[1], middle), (photos[0], main)]
            default: return [(photos[1], middle), (photos[2], right), (photos[0], main)]
            }
        case .fan:
            let slots = [
                Slot(x: 40, y: 60, w: 92, h: 100, rotation: -12),
                Slot(x: 104, y: 40, w: 94, h: 106, rotation: -4),
                Slot(x: 180, y: 36, w: 94, h: 106, rotation: 4),
                Slot(x: 254, y: 54, w: 92, h: 100, rotation: 12)
            ]
            let shown = Array(photos.prefix(4))
            // 张数不够时用中间的位置，保持居中
            let start = shown.count >= 3 ? 0 : 1
            return shown.enumerated().map { index, scan in (scan, slots[min(start + index, 3)]) }
        case .emptySlot:
            let behind = [
                Slot(x: 178, y: 38, w: 104, h: 114, rotation: 6),
                Slot(x: 242, y: 56, w: 96, h: 108, rotation: 10)
            ]
            let photosBehind = photos.prefix(2).enumerated().map { index, scan in (Optional(scan), behind[index]) }
            return photosBehind + [(nil, Slot(x: 62, y: 22, w: 140, h: 132, rotation: -6))]
        }
    }

    /// 手写标签离右边和顶部的距离（设计稿坐标）
    private var labelTrailing: CGFloat { style == .fan ? 28 : 22 }
    private var labelTop: CGFloat { style == .fan ? 0 : -4 }

    private var accessibilityText: String {
        let titles = photos.prefix(3).map(\.displayTitle)
        return titles.isEmpty ? label : titles.joined(separator: "，")
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
            .shadow(color: .black.opacity(0.16), radius: 12 * scale, y: 9 * scale)
    }
}

/// 虚线空位：今天的第一张
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
