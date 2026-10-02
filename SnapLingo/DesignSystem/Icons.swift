//
//  Icons.swift
//  SnapLingo
//
//  96 个手绘彩色小图标（Assets 里的 Icons 文件夹）：分类和文件夹都用它们。
//

import SwiftUI

enum IconLibrary {
    /// 全部图标，按图标表的顺序（吃喝 → 购物 → 出行 → 住家 → 学习工作 → 联络 → 健康运动 → 户外 → 娱乐）
    static let all: [String] = """
    coffee cutlery burger cake drink shop bag cart groceries market card tag
    signpost bus train car taxi bike plane suitcase globe map compass camera
    house building key homesign bed lamp sofa plant box washer pot broom
    laptop books book graduation notes idea chart presentation briefcase monitor phone headphones
    chat chats people mail call calendar clock bell pin document folder cloud
    health hospital stethoscope pill clipboard dumbbell sneaker bottle yoga lotus muscle soccer
    trees mountain sun waves tent campfire paw dog cat leaf sprout recycle
    masks music gamepad clapper palette gift party wine ticket beach snowflake umbrella
    """.split(whereSeparator: \.isWhitespace).map { "icon-\($0)" }

    /// 新建文件夹时默认的图标
    static let defaultFolderIcon = "icon-folder"
}

/// 一个彩色小图标，按给定边长显示
struct IconImage: View {
    var name: String
    var size: CGFloat

    var body: some View {
        Image(name)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
