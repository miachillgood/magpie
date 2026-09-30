//
//  WordCrops.swift
//  SnapLingo
//
//  从场景原图里裁出已保存单词所在的那一小块。照片墙上排在原图后面，
//  让每一天的那一排照片更丰富，也能一眼看到词在哪里出现。
//

import UIKit

enum WordCrops {
    /// 一个能在照片里定位到的单词；rect 为归一化坐标（左上角为原点）
    struct Spot: Identifiable {
        let word: VocabWord
        let rect: CGRect
        var id: UUID { word.id }
    }

    private static var cache: [String: [Spot]] = [:]

    /// 这张照片里能定位到的已保存单词，按保存顺序，最多 limit 个
    static func spots(for scan: Scan, limit: Int = 3) -> [Spot] {
        let key = "\(scan.id)-\(scan.words.count)-\(limit)"
        if let cached = cache[key] { return cached }
        var result: [Spot] = []
        if !scan.tokens.isEmpty {
            let matcher = TokenMatcher(tokens: scan.tokens)
            for word in scan.words.sorted(by: { $0.addedAt < $1.addedAt }) {
                guard let group = matcher.occurrences(of: word.word).first, let first = group.first else { continue }
                let rect = group.dropFirst().reduce(first.rect) { $0.union($1.rect) }
                result.append(Spot(word: word, rect: rect))
                if result.count == limit { break }
            }
        }
        cache[key] = result
        return result
    }

    /// 以单词为中心裁一块接近方形的区域，缩到 maxPixel 以内（在后台线程调用）
    nonisolated static func crop(imageData: Data, around rect: CGRect, aspect: CGFloat = 0.95, maxPixel: CGFloat = 360) -> UIImage? {
        guard let cgImage = UIImage(data: imageData)?.cgImage else { return nil }
        let imageWidth = CGFloat(cgImage.width), imageHeight = CGFloat(cgImage.height)
        let word = CGRect(x: rect.minX * imageWidth, y: rect.minY * imageHeight, width: rect.width * imageWidth, height: rect.height * imageHeight)

        // 单词周围留出上下文：高度约为字高的 8 倍，至少占整张图的 22%
        var width = max(max(word.height * 8, imageHeight * 0.22) * aspect, word.width * 1.5)
        var height = width / aspect
        width = min(width, imageWidth)
        height = min(height, imageHeight)
        let x = min(max(0, word.midX - width / 2), imageWidth - width)
        let y = min(max(0, word.midY - height / 2), imageHeight - height)

        guard let cropped = cgImage.cropping(to: CGRect(x: x, y: y, width: width, height: height).integral) else { return nil }
        let scale = min(1, maxPixel / max(width, height))
        let size = CGSize(width: width * scale, height: height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIImage(cgImage: cropped).draw(in: CGRect(origin: .zero, size: size))
            // 在单词上划一道荧光笔，一眼看出这张小图说的是哪个词
            let marker = CGRect(
                x: (word.minX - x) * scale - 4,
                y: (word.minY - y) * scale - 2,
                width: word.width * scale + 8,
                height: word.height * scale + 4
            )
            context.cgContext.setBlendMode(.multiply)
            UIColor(red: 1, green: 0.886, blue: 0.478, alpha: 0.75).setFill()
            UIBezierPath(roundedRect: marker, cornerRadius: marker.height * 0.3).fill()
        }
    }
}
