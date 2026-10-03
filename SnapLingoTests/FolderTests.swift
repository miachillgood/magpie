//
//  FolderTests.swift
//  SnapLingoTests
//

import Foundation
import SwiftData
import Testing
@testable import SnapLingo

@MainActor
struct CategoryTests {
    @Test func oldScenesFoldIntoTheNewCategories() {
        #expect(SceneType(key: "supermarket") == .shopping)
        #expect(SceneType(key: "legal") == .bank)
        #expect(SceneType(key: " Restaurant ") == .restaurant)
        #expect(SceneType(key: "tech") == .tech)
        #expect(SceneType(key: "something else") == .general)
    }

    @Test func twelveCategoriesEachWithAnIconThatExists() {
        #expect(SceneType.allCases.count == 12)
        for scene in SceneType.allCases {
            #expect(IconLibrary.all.contains(scene.iconName), "\(scene) 的图标不在图标表里")
        }
        #expect(IconLibrary.all.count == 96)
        #expect(Set(IconLibrary.all).count == 96)
    }

    @Test func oldScanReadsAsItsNewCategory() throws {
        let container = try ModelContainer(for: SnapLingoApp.schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let scan = Scan()
        scan.sceneRaw = "supermarket"
        container.mainContext.insert(scan)
        #expect(scan.scene == .shopping)
    }
}

@MainActor
struct FolderTests {
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(for: SnapLingoApp.schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return ModelContext(container)
    }

    @Test func aWordCanLiveInSeveralFoldersWithoutDuplicates() throws {
        let context = try makeContext()
        let word = VocabWord(word: "bond")
        context.insert(word)
        let work = WordLibrary.createFolder(name: " 打工 ", iconName: "icon-briefcase", context: context)
        let moving = WordLibrary.createFolder(name: "搬家", iconName: "icon-box", context: context)

        WordLibrary.add([word], to: work, context: context)
        WordLibrary.add([word], to: work, context: context)
        WordLibrary.add([word], to: moving, context: context)

        #expect(work.name == "打工")
        #expect(work.words.count == 1)
        #expect(Set(word.folders.map(\.id)) == [work.id, moving.id])
    }

    @Test func deletingAFolderKeepsTheWordsAndDeletingAWordEmptiesTheFolder() throws {
        let context = try makeContext()
        let keep = VocabWord(word: "tenancy")
        let gone = VocabWord(word: "bond")
        [keep, gone].forEach(context.insert)
        let folder = WordLibrary.createFolder(name: "租房", iconName: "icon-key", context: context)
        WordLibrary.add([keep, gone], to: folder, context: context)

        WordLibrary.delete(gone, context: context)
        #expect(folder.words.map(\.word) == ["tenancy"])

        WordLibrary.delete(folder, context: context)
        #expect(try context.fetch(FetchDescriptor<VocabWord>()).map(\.word) == ["tenancy"])
        #expect(keep.folders.isEmpty)
    }

    @Test func removeTakesOnlyThatWordOut() throws {
        let context = try makeContext()
        let a = VocabWord(word: "queue"), b = VocabWord(word: "receipt")
        [a, b].forEach(context.insert)
        let folder = WordLibrary.createFolder(name: "超市", iconName: "icon-cart", context: context)
        WordLibrary.add([a, b], to: folder, context: context)
        WordLibrary.remove(a, from: folder, context: context)
        #expect(folder.words.map(\.word) == ["receipt"])
        #expect(a.folders.isEmpty)
    }

    @Test func recentlyUsedFoldersComeFirst() throws {
        let context = try makeContext()
        let word = VocabWord(word: "fare")
        context.insert(word)
        let older = WordLibrary.createFolder(name: "A", iconName: "icon-bus", context: context)
        let newer = WordLibrary.createFolder(name: "B", iconName: "icon-train", context: context)
        WordLibrary.add([word], to: older, now: Date().addingTimeInterval(60), context: context)
        #expect(WordLibrary.folders(context).map(\.id) == [older.id, newer.id])
    }
}

@MainActor
struct BatchOrganizeTests {
    private func makeContext() throws -> ModelContext {
        ModelContext(try ModelContainer(for: SnapLingoApp.schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
    }

    @Test func moveTakesWordsOutOfTheSourceFolder() throws {
        let context = try makeContext()
        let a = VocabWord(word: "bond"), b = VocabWord(word: "lease"), c = VocabWord(word: "fare")
        [a, b, c].forEach(context.insert)
        let from = WordLibrary.createFolder(name: "A", iconName: "icon-key", context: context)
        let to = WordLibrary.createFolder(name: "B", iconName: "icon-box", context: context)
        WordLibrary.add([a, b, c], to: from, context: context)

        WordLibrary.move([a, b], from: from, to: to, context: context)

        #expect(from.words.map(\.word) == ["fare"])
        #expect(Set(to.words.map(\.word)) == ["bond", "lease"])
    }

    @Test func copyKeepsWordsInBothFolders() throws {
        let context = try makeContext()
        let a = VocabWord(word: "bond")
        context.insert(a)
        let one = WordLibrary.createFolder(name: "A", iconName: "icon-key", context: context)
        let two = WordLibrary.createFolder(name: "B", iconName: "icon-box", context: context)
        WordLibrary.add([a], to: one, context: context)
        WordLibrary.add([a], to: two, context: context)
        #expect(a.folders.count == 2)
    }

    @Test func manualCategoryWinsOverThePhoto() throws {
        let context = try makeContext()
        let scan = Scan()
        scan.scene = .restaurant
        let word = VocabWord(word: "receipt")
        context.insert(scan)
        context.insert(word)
        word.scans = [scan]
        #expect(SceneType.of(word) == .restaurant)

        WordLibrary.setCategory([word], to: .shopping, context: context)
        #expect(SceneType.of(word) == .shopping)
        scan.scene = .transport
        #expect(SceneType.of(word) == .shopping, "照片的分类变了，手动改过的词不跟着变")
    }

    @Test func batchDeleteRemovesWordsAndEmptiesFolders() throws {
        let context = try makeContext()
        let a = VocabWord(word: "bond"), b = VocabWord(word: "lease")
        [a, b].forEach(context.insert)
        let folder = WordLibrary.createFolder(name: "A", iconName: "icon-key", context: context)
        WordLibrary.add([a, b], to: folder, context: context)

        WordLibrary.delete([a, b], context: context)

        #expect(try context.fetch(FetchDescriptor<VocabWord>()).isEmpty)
        #expect(folder.words.isEmpty)
    }
}
