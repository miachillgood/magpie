//
//  LibraryDestinations.swift
//  SnapLingo
//

import SwiftUI

extension View {
    /// 场景和单词详情页的统一导航目标
    func libraryDestinations(zoom: Namespace.ID) -> some View {
        self
            .navigationDestination(for: Scan.self) { scan in
                SceneDetailView(scan: scan)
                    .navigationTransition(.zoom(sourceID: scan.id, in: zoom))
            }
            .navigationDestination(for: VocabWord.self) { word in
                WordDetailView(word: word)
            }
    }
}
