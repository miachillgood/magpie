//
//  StickerCollage.swift
//  SnapLingo
//

import SwiftUI

/// 一张倾斜的咖啡馆菜单照片，贴着从菜单上挑出来的单词
struct StickerCollage: View {
    @State private var float = false

    var body: some View {
        ZStack {
            Image("WelcomeMenu")
                .resizable()
                .scaledToFill()
                .frame(width: 196, height: 276)
                .clipShape(.rect(cornerRadius: 18, style: .continuous))
                .padding(6)
                .background(Theme.card, in: .rect(cornerRadius: 24, style: .continuous))
                .softShadow(1.2)
                .rotationEffect(.degrees(-4))
                .offset(y: float ? -6 : 2)

            // 左右贴边摆放：英文释义较长时也不会被屏幕裁掉
            sticker(word: "flat white", gloss: String(localized: "馥芮白", comment: "Meaning of 'flat white' (a coffee)"), angle: -6, alignment: .leading, inset: 22, y: -44)
            sticker(word: "gluten free", gloss: String(localized: "无麸质", comment: "Meaning of 'gluten free' on a menu"), angle: 5, alignment: .trailing, inset: 18, y: 18)
            sticker(word: "allergies", gloss: String(localized: "过敏", comment: "Meaning of 'allergies' on a menu"), angle: -3, alignment: .leading, inset: 40, y: 112)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { float = true }
        }
        .accessibilityHidden(true)
    }

    private func sticker(word: String, gloss: String, angle: Double, alignment: Alignment, inset: CGFloat, y: CGFloat) -> some View {
        WordSticker(word: word, gloss: gloss)
            .rotationEffect(.degrees(angle))
            .padding(alignment == .leading ? .leading : .trailing, inset)
            .frame(maxWidth: .infinity, alignment: alignment)
            .offset(y: y)
    }
}
