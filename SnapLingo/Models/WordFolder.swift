//
//  WordFolder.swift
//  SnapLingo
//
//  用户自己建的文件夹：起个名字、选个图标，把单词放进去。
//  只是引用已有的单词，复习进度还是单词自己的那一份；一个词可以在好几个文件夹里。
//

import Foundation
import SwiftData

@Model
final class WordFolder {
    var id: UUID = UUID()
    var name: String = ""
    var iconName: String = IconLibrary.defaultFolderIcon
    var createdAt: Date = Date()
    /// 最近一次往里放词的时间：拍完照默认勾上最近用过的文件夹
    var lastUsedAt: Date = Date()

    @Relationship(deleteRule: .nullify, inverse: \VocabWord.folders)
    var words: [VocabWord] = []

    init(name: String, iconName: String = IconLibrary.defaultFolderIcon, createdAt: Date = Date()) {
        self.id = UUID()
        self.name = name
        self.iconName = iconName
        self.createdAt = createdAt
        self.lastUsedAt = createdAt
    }
}
