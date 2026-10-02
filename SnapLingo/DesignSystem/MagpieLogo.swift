//
//  MagpieLogo.swift
//  SnapLingo
//
//  Magpie 的 logo（黄底喜鹊）和字标。图片是方形的，这里按 iOS 图标的圆角裁切。
//

import SwiftUI

struct MagpieLogo: View {
    var size: CGFloat

    var body: some View {
        Image("MagpieLogo")
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
            .clipShape(.rect(cornerRadius: size * 0.225, style: .continuous))
            .shadow(color: .black.opacity(0.14), radius: size * 0.12, y: size * 0.06)
            .accessibilityHidden(true)
    }
}

/// 左上角的字标：logo + Magpie
struct MagpieWordmark: View {
    var body: some View {
        HStack(spacing: 9) {
            MagpieLogo(size: 32)
            Text(verbatim: "Magpie")
                .font(.brand(22))
                .kerning(-0.4)
                .foregroundStyle(Theme.homeInk)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "Magpie"))
        .accessibilityAddTraits(.isHeader)
    }
}
