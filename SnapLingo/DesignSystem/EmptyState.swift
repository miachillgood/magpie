//
//  EmptyState.swift
//  SnapLingo
//

import SwiftUI

/// 带 emoji 插画的空状态
struct IllustratedEmptyState: View {
    var emoji: String
    var color: Color
    var title: String
    var message: String
    var buttonTitle: String?
    var action: (() -> Void)?

    @State private var bounce = false

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            Text(emoji)
                .font(.system(size: 64))
                .frame(width: 140, height: 140)
                .background(color, in: .circle)
                .scaleEffect(bounce ? 1.04 : 0.98)
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { bounce = true }
                }
            VStack(spacing: Spacing.xs) {
                Text(title)
                    .font(.title2.weight(.heavy))
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            if let buttonTitle, let action {
                PrimaryButton(title: buttonTitle, symbol: "camera.fill", action: action)
                    .padding(.horizontal, Spacing.xl)
            }
            Spacer()
            Spacer()
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity)
    }
}
