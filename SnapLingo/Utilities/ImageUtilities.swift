//
//  ImageUtilities.swift
//  SnapLingo
//

import UIKit

enum ImageUtilities {

    // MARK: - OCR 前预处理（限制最大边长 2048，防止内存压力）

    static func prepareForOCR(_ image: UIImage, maxDimension: CGFloat = 2048) -> UIImage {
        let size = image.size
        let maxSide = max(size.width, size.height)
        guard maxSide > maxDimension else { return image }

        let scale = maxDimension / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        return resize(image, to: newSize)
    }

    // MARK: - 生成缩略图（用于 VocabWord.sourceImageThumbnail 存储）

    static func thumbnail(from image: UIImage, size: CGSize = CGSize(width: 150, height: 150)) -> Data? {
        let thumb = resize(image, to: size, mode: .aspectFill)
        return thumb.jpegData(compressionQuality: 0.7)
    }

    // MARK: - 通用 resize

    static func resize(_ image: UIImage, to targetSize: CGSize, mode: ContentMode = .aspectFit) -> UIImage {
        let sourceSize = image.size
        let widthRatio  = targetSize.width  / sourceSize.width
        let heightRatio = targetSize.height / sourceSize.height

        let scale: CGFloat
        switch mode {
        case .aspectFit:  scale = min(widthRatio, heightRatio)
        case .aspectFill: scale = max(widthRatio, heightRatio)
        }

        let scaledSize = CGSize(
            width:  (sourceSize.width  * scale).rounded(),
            height: (sourceSize.height * scale).rounded()
        )

        // 居中裁切（aspectFill 时超出目标区域的部分裁掉）
        let origin = CGPoint(
            x: ((targetSize.width  - scaledSize.width)  / 2).rounded(),
            y: ((targetSize.height - scaledSize.height) / 2).rounded()
        )

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: origin, size: scaledSize))
        }
    }

    enum ContentMode { case aspectFit, aspectFill }
}
