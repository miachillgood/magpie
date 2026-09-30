//
//  StickerCollage.swift
//  SnapLingo
//

import SwiftUI

/// 几张倾斜的“场景贴纸”，用 emoji 和单词贴纸拼成插画
struct StickerCollage: View {
    @State private var float = false

    var body: some View {
        ZStack {
            sticker(emoji: "☕️", color: Pastel.peach, word: "flat white", gloss: String(localized: "馥芮白", comment: "Meaning of 'flat white' (a coffee)"))
                .rotationEffect(.degrees(-9))
                .offset(x: -104, y: 30)
            sticker(emoji: "🏠", color: Pastel.lavender, word: "bond", gloss: String(localized: "押金", comment: "Meaning of 'bond' (rental deposit)"))
                .rotationEffect(.degrees(8))
                .offset(x: 104, y: 18)
            sticker(emoji: "🛒", color: Pastel.mint, word: "receipt", gloss: String(localized: "收据", comment: "Meaning of 'receipt'"))
                .rotationEffect(.degrees(-2))
                .offset(y: float ? -40 : -32)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { float = true }
        }
        .accessibilityHidden(true)
    }

    private func sticker(emoji: String, color: Color, word: String, gloss: String) -> some View {
        Text(emoji)
            .font(.system(size: 58))
            .frame(width: 118, height: 118)
            .background(color, in: .rect(cornerRadius: 24, style: .continuous))
            .padding(6)
            .background(Theme.card, in: .rect(cornerRadius: 30, style: .continuous))
            .softShadow(1.2)
            .overlay(alignment: .bottom) {
                WordSticker(word: word, gloss: gloss)
                    .offset(y: 16)
            }
    }
}
