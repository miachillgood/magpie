//
//  PlanRingView.swift
//  SnapLingo
//
//  仿“健身”圆环：外圈新词，内圈复习。
//

import SwiftUI

struct PlanRingView: View {
    var newProgress: Double
    var reviewProgress: Double
    var lineWidth: CGFloat = 14

    @State private var animatedNew: Double = 0
    @State private var animatedReview: Double = 0

    var body: some View {
        ZStack {
            ring(progress: animatedNew, color: Theme.newWords, inset: 0)
            ring(progress: animatedReview, color: Theme.reviews, inset: lineWidth + 4)
        }
        .padding(lineWidth / 2)
        .onAppear { animate() }
        .onChange(of: newProgress) { animate() }
        .onChange(of: reviewProgress) { animate() }
        .accessibilityElement()
        .accessibilityLabel("新词完成 \(Int(newProgress * 100))%，复习完成 \(Int(reviewProgress * 100))%")
    }

    private func animate() {
        withAnimation(.spring(response: 0.9, dampingFraction: 0.8)) {
            animatedNew = newProgress
            animatedReview = reviewProgress
        }
    }

    private func ring(progress: Double, color: Color, inset: CGFloat) -> some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(progress, 0.001))
                .stroke(
                    AngularGradient(colors: [color.opacity(0.75), color], center: .center, startAngle: .degrees(0), endAngle: .degrees(360 * max(progress, 0.01))),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .opacity(progress > 0 ? 1 : 0)
        }
        .padding(inset)
    }
}

#Preview {
    PlanRingView(newProgress: 0.6, reviewProgress: 0.3)
        .frame(width: 140, height: 140)
        .padding()
}
