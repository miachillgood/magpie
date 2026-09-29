//
//  ImageUtilities.swift
//  SnapLingo
//

import UIKit

enum ImageUtilities {

    /// 把照片转成方向为 .up、最长边不超过 maxDimension 的图，保证 OCR 坐标和显示一致
    static func normalized(_ image: UIImage, maxDimension: CGFloat = 2048) -> UIImage {
        let size = image.size
        let maxSide = max(size.width, size.height)
        let scale = maxSide > maxDimension ? maxDimension / maxSide : 1
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }

    static func jpeg(_ image: UIImage, maxDimension: CGFloat, quality: CGFloat) -> Data? {
        normalized(image, maxDimension: maxDimension).jpegData(compressionQuality: quality)
    }
}
