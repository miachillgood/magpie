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

@MainActor
struct LookupTests {
    @Test func onlyEnglishWordsOrShortPhrasesCanBeLookedUp() {
        #expect(WordLookupSheet.isLookupQuery("oat"))
        #expect(WordLookupSheet.isLookupQuery(" flat white "))
        #expect(WordLookupSheet.isLookupQuery("take-away"))
        #expect(WordLookupSheet.isLookupQuery("don't"))
        #expect(!WordLookupSheet.isLookupQuery("燕麦"))
        #expect(!WordLookupSheet.isLookupQuery("123"))
        #expect(!WordLookupSheet.isLookupQuery("a b c d e"))
        #expect(!WordLookupSheet.isLookupQuery(""))
    }

    @Test func lookedUpWordJoinsTodaysNewWordsOnce() throws {
        let container = try ModelContainer(for: SnapLingoApp.schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let candidate = WordCandidate(word: "oats", lemma: "oat", partOfSpeech: "n.", cefrRaw: 2, gloss: "燕麦")
        let explanation = WordExplanation(
            lemma: "oat", partOfSpeech: "n.", cefr: .a2, gloss: "燕麦", phonetic: "/oʊt/",
            explanation: "燕麦", exampleSentence: "Oat milk, please.", exampleTranslation: "请用燕麦奶。", sceneNote: ""
        )

        let word = WordLibrary.addStandalone(candidate, explanation: explanation, context: context)
        let again = WordLibrary.addStandalone(candidate, explanation: nil, context: context)

        #expect(again.id == word.id)
        #expect(try context.fetch(FetchDescriptor<VocabWord>()).count == 1)
        #expect(word.word == "oat")
        #expect(word.scans.isEmpty)
        #expect(word.state == .new)
        #expect(word.explanationStatus == .ready)
        #expect(word.exampleSentence == "Oat milk, please.")

        let plan = DailyPlanner.plan(words: [word], events: [ReviewLog](), newPerDay: 10, maxReviews: 100)
        #expect(plan.newIDs == [word.id])
    }
}

@MainActor
struct VoiceSceneTests {
    private func extraction(_ words: [String]) -> SceneExtraction {
        SceneExtraction(
            scene: .medical,
            title: "看牙医",
            candidates: words.map { WordCandidate(word: $0, lemma: $0, partOfSpeech: "n.", cefrRaw: 2, gloss: "") }
        )
    }

    @Test func speechIsAWordOrAScene() {
        let scene = extraction(["dentist", "appointment"])
        // AI 说是词：直接查
        if case .word(let word) = SpeechIntent.resolve(kind: "word", word: "oat", english: "how do you say 燕麦", extraction: extraction([])) {
            #expect(word == "oat")
        } else { Issue.record("应该是查词") }
        // 描述场景：推荐的词
        if case .scene(let result) = SpeechIntent.resolve(kind: "scene", word: "", english: "I'm seeing the dentist tomorrow", extraction: scene) {
            #expect(result.candidates.count == 2)
        } else { Issue.record("应该是场景") }
        // AI 说是词却没给词：英语那条像个词就查它
        if case .word(let word) = SpeechIntent.resolve(kind: "word", word: "", english: "Oat.", extraction: extraction([])) {
            #expect(word == "Oat")
        } else { Issue.record("应该退回查英语那条") }
        // 什么都没听出来
        #expect(SpeechIntent.resolve(kind: "scene", word: "", english: "嗯嗯", extraction: extraction([])) == nil)
    }

    @Test func voiceSceneHasNoPhotoAndKeepsWhatWasSaid() throws {
        let container = try ModelContainer(for: SnapLingoApp.schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let candidates = extraction(["dentist", "appointment", "cavity"]).candidates

        let scan = WordLibrary.saveVoiceScene(
            title: "看牙医",
            placeName: "",
            scene: .medical,
            transcript: "明天要去看牙医",
            candidates: candidates,
            selectedKeys: ["dentist", "appointment"],
            context: context
        )

        #expect(scan.isVoice)
        #expect(scan.imageData == nil)
        #expect(scan.ocrText == "明天要去看牙医")
        #expect(Set(scan.words.map(\.word)) == ["dentist", "appointment"])
        #expect(scan.candidates.count == 3)
        #expect(Scan().isVoice == false)
    }
}
