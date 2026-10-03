//
//  ScanImageViews.swift
//  SnapLingo
//

import SwiftUI
import UIKit

/// 解码后的图片缓存，避免列表滚动时反复解码 JPEG
final class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()

    init() { cache.countLimit = 120 }

    func image(for key: String, data: Data?) -> UIImage? {
        if let cached = cache.object(forKey: key as NSString) { return cached }
        guard let data, let image = UIImage(data: data) else { return nil }
        cache.setObject(image, forKey: key as NSString)
        return image
    }

    func remove(_ key: String) {
        cache.removeObject(forKey: key as NSString)
    }

    func removeAll() {
        cache.removeAllObjects()
    }

    /// 已经处理好的图（比如裁出来的单词小图）
    func cached(_ key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func store(_ image: UIImage, for key: String) {
        cache.setObject(image, forKey: key as NSString)
    }
}

extension Scan {
    var thumbnailImage: UIImage? {
        ImageCache.shared.image(for: "thumb-\(id)", data: thumbnailData ?? imageData)
    }

    var fullImage: UIImage? {
        ImageCache.shared.image(for: "full-\(id)", data: imageData)
    }
}

// MARK: - 单词在照片上的锚点

struct WordAnchor: Identifiable {
    var id: UUID
    var word: String
    var gloss: String
    /// 归一化中心点（0...1，左上角为原点）
    var point: CGPoint
}

/// 计算“已保存单词在照片哪里”，按场景缓存
enum SceneAnchors {
    private static var cache: [String: [WordAnchor]] = [:]
    private static let fallback: [CGPoint] = [
        CGPoint(x: 0.32, y: 0.3), CGPoint(x: 0.68, y: 0.5), CGPoint(x: 0.38, y: 0.72), CGPoint(x: 0.7, y: 0.22)
    ]

    static func anchors(for scan: Scan) -> [WordAnchor] {
        let words = scan.words.sorted { $0.addedAt < $1.addedAt }
        let key = "\(scan.id)-\(words.count)"
        if let cached = cache[key] { return cached }

        let matcher = scan.tokens.isEmpty ? nil : TokenMatcher(tokens: scan.tokens)
        var result: [WordAnchor] = []
        for (index, word) in words.enumerated() {
            var point = fallback[index % fallback.count]
            if let group = matcher?.occurrences(of: word.word).first, let first = group.first {
                let rect = group.dropFirst().reduce(first.rect) { $0.union($1.rect) }
                point = CGPoint(x: rect.midX, y: rect.midY)
            } else if matcher != nil {
                continue
            }
            result.append(WordAnchor(id: word.id, word: word.word, gloss: word.gloss, point: point))
        }
        cache[key] = result
        return result
    }
}

// MARK: - 照片视图

/// 场景缩略图（填满容器）
struct ScanThumbnail: View {
    var scan: Scan?

    var body: some View {
        Rectangle()
            .fill(scan?.scene.pastel ?? Theme.insetFill)
            .overlay {
                if let image = scan?.thumbnailImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Text(scan?.scene.emoji ?? "📷")
                        .font(.largeTitle)
                }
            }
            .clipped()
    }
}

/// 照片 + 浮在单词位置上的单词贴纸
struct ScenePhotoWithStickers: View {
    var scan: Scan
    var maxStickers = 3
    var compact = true

    var body: some View {
        GeometryReader { proxy in
            let anchors = Array(SceneAnchors.anchors(for: scan).prefix(maxStickers))
            ZStack {
                ScanThumbnail(scan: scan)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                ForEach(Array(anchors.enumerated()), id: \.element.id) { index, anchor in
                    WordSticker(word: anchor.word, gloss: compact ? "" : anchor.gloss, compact: compact)
                        .rotationEffect(.degrees(index.isMultiple(of: 2) ? -3 : 3))
                        .position(position(for: anchor, index: index, in: proxy.size))
                }
            }
        }
    }

    /// 缩略图是按“填满”裁切的，锚点按同样比例换算，并保证贴纸不出界
    private func position(for anchor: WordAnchor, index: Int, in size: CGSize) -> CGPoint {
        let aspect = max(scan.imageAspectRatio, 0.1)
        let imageSize: CGSize
        if size.width / size.height > aspect {
            imageSize = CGSize(width: size.width, height: size.width / aspect)
        } else {
            imageSize = CGSize(width: size.height * aspect, height: size.height)
        }
        let offset = CGPoint(x: (size.width - imageSize.width) / 2, y: (size.height - imageSize.height) / 2)
        var x = offset.x + anchor.point.x * imageSize.width
        // 贴纸稍微在单词上方，不挡住原文
        var y = offset.y + anchor.point.y * imageSize.height - (compact ? 14 : 18)
        let marginX: CGFloat = compact ? 44 : 70
        let marginY: CGFloat = compact ? 16 : 22
        // 超出可见区域的锚点，按顺序排到可见区域里
        if y < marginY || y > size.height - marginY {
            y = size.height * (0.28 + 0.24 * CGFloat(index % 3))
        }
        x = min(max(x, marginX), size.width - marginX)
        y = min(max(y, marginY), size.height - marginY)
        return CGPoint(x: x, y: y)
    }
}

/// 场景卡片：马卡龙色底 + 照片（带单词贴纸）+ emoji 标题
struct SceneCard: View {
    var scan: Scan
    var photoHeight: CGFloat = 150
    var showsDate = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScenePhotoWithStickers(scan: scan, maxStickers: 2)
                .frame(height: photoHeight)
                .clipShape(.rect(cornerRadius: Radius.card - 6, style: .continuous))

            HStack(spacing: Spacing.xs) {
                IconImage(name: scan.scene.iconName, size: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text(scan.displayTitle)
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.ink.opacity(0.55))
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 2)
        }
        .padding(8)
        .background(scan.scene.pastel, in: .rect(cornerRadius: Radius.card, style: .continuous))
        .contentShape(.rect(cornerRadius: Radius.card, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        let count = String(localized: "\(scan.words.count) 个词")
        guard showsDate else { return count }
        return "\(scan.createdAt.formatted(.dateTime.month().day())) · \(count)"
    }
}
