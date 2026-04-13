//
//  WordChipView.swift
//  SnapLingo
//

import SwiftUI

struct WordChipView: View {
    let word: String
    let isSelected: Bool
    let likelyKnown: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                }
                Text(word)
                    .font(.subheadline.weight(isSelected ? .semibold : .regular))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(backgroundColor)
            .foregroundStyle(foregroundColor)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(borderColor, lineWidth: isSelected ? 0 : 1.5)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    private var backgroundColor: Color {
        if isSelected { return .accentColor }
        if likelyKnown { return Color(.systemFill) }
        return Color(.secondarySystemBackground)
    }

    private var foregroundColor: Color {
        isSelected ? .white : .primary
    }

    private var borderColor: Color {
        likelyKnown ? .clear : .accentColor.opacity(0.4)
    }
}

#Preview {
    HStack {
        WordChipView(word: "prescription", isSelected: true, likelyKnown: false, onTap: {})
        WordChipView(word: "organic", isSelected: false, likelyKnown: false, onTap: {})
        WordChipView(word: "the", isSelected: false, likelyKnown: true, onTap: {})
    }
    .padding()
}
