//
//  Doodles.swift
//  SnapLingo
//
//  手绘感的小装饰：箭头、闪光线、荧光笔、手写标签。只用在首页这类“有情绪”的地方。
//

import SwiftUI

/// 往右上方勾起的手画箭头（48 × 54 的比例）
struct HandArrow: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 48, sy = rect.height / 54
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * sx, y: y * sy) }
        var path = Path()
        path.move(to: p(4, 48))
        path.addCurve(to: p(38, 10), control1: p(20, 50), control2: p(36, 40))
        path.move(to: p(30, 16))
        path.addLine(to: p(38, 8))
        path.addLine(to: p(44, 18))
        return path
    }
}

/// 三笔闪光线（30 × 30 的比例）
struct SparkleLines: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 30, sy = rect.height / 30
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * sx, y: y * sy) }
        var path = Path()
        path.move(to: p(8, 26)); path.addLine(to: p(3, 17))
        path.move(to: p(15, 21)); path.addLine(to: p(15, 5))
        path.move(to: p(22, 24)); path.addLine(to: p(28, 16))
        return path
    }
}

/// 荧光笔划过的底色：四个角不一样圆，微微倾斜，出现时从左往右划开
struct MarkerHighlight: View {
    var drawn: Bool
    var color: Color = Theme.marker

    var body: some View {
        UnevenRoundedRectangle(topLeadingRadius: 14, bottomLeadingRadius: 22, bottomTrailingRadius: 16, topTrailingRadius: 20, style: .continuous)
            .fill(color)
            .rotationEffect(.degrees(-1.5))
            .scaleEffect(x: drawn ? 1 : 0.001, anchor: .leading)
    }
}

/// 手写标签（如 Nice find!），出现时像被写出来一样从左往右露出
struct HandwrittenLabel: View {
    var text: String
    var size: CGFloat
    var revealed: Bool

    var body: some View {
        Text(text)
            .font(.handwriting(size))
            .foregroundStyle(Theme.homeInk)
            .fixedSize()
            .mask(alignment: .leading) {
                Rectangle().scaleEffect(x: revealed ? 1 : 0.001, anchor: .leading)
            }
            .rotationEffect(.degrees(-8))
            .accessibilityHidden(true)
    }
}

/// 黄色手写小标签：今天那组照片上的 New!
struct NewTag: View {
    var body: some View {
        Text("New!")
            .font(.handwriting(22))
            .foregroundStyle(Theme.homeInk)
            .padding(.horizontal, 12)
            .padding(.top, 2)
            .padding(.bottom, 4)
            .background(Theme.marker, in: .rect(cornerRadius: 9, style: .continuous))
            .rotationEffect(.degrees(-8))
            .softShadow(0.8)
            .accessibilityHidden(true)
    }
}
