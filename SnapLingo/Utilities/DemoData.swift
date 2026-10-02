//
//  DemoData.swift
//  SnapLingo
//
//  仅 DEBUG：示例场景、单词和学习记录，方便截图和调试。
//  启动参数：-seedDemoData  -skipOnboarding  -showOnboarding  -resetData
//

#if DEBUG
import SwiftData
import UIKit

enum DemoData {

    static func applyLaunchArguments(to context: ModelContext) {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-resetData") {
            wipe(context)
        }
        if arguments.contains("-skipOnboarding") {
            let settings = UserSettings.current(in: context)
            settings.onboardingCompleted = true
            settings.assessmentCompleted = true
            // 跳过引导也就跳过了 AI 说明页，当作已经同意（截图、调试用）
            if AIConsent.state == .undecided { AIConsent.state = .granted }
            try? context.save()
        }
        if arguments.contains("-showOnboarding") {
            UserSettings.current(in: context).onboardingCompleted = false
            try? context.save()
        }
        // -newWordsPerDay 2：调小每天的新词上限，让新词排队，方便看结算页的「节奏合适吗？」
        if let index = arguments.firstIndex(of: "-newWordsPerDay"), index + 1 < arguments.count, let count = Int(arguments[index + 1]) {
            let settings = UserSettings.current(in: context)
            settings.newWordsPerDay = count
            settings.paceCheckDone = false
            try? context.save()
        }
        if arguments.contains("-seedDemoData") {
            let count = (try? context.fetchCount(FetchDescriptor<Scan>())) ?? 0
            if count == 0 { seed(into: context) }
        }
    }

    static func wipe(_ context: ModelContext) {
        WordLibrary.wipeAll(context)
    }

    // MARK: - 示例内容

    private struct DemoWord {
        var word: String
        var pos: String
        var cefr: CEFRLevel
        var phonetic: String
        var gloss: String
        var explanation: String
        var example: String
        var translation: String
        var note: String
        var context: String
    }

    private struct DemoScene {
        var title: String
        var scene: SceneType
        var daysAgo: Int
        var lines: [String]
        var colors: (UIColor, UIColor)
        var textColor: UIColor
        var words: [DemoWord]
    }

    private static let scenes: [DemoScene] = [
        DemoScene(
            title: "Little Bird 咖啡菜单",
            scene: .restaurant,
            daysAgo: 0,
            lines: ["LITTLE BIRD CAFÉ", "Flat white  5.50", "Oat milk  +0.80", "Gluten free options", "Please order at the counter"],
            colors: (UIColor(red: 0.13, green: 0.16, blue: 0.14, alpha: 1), UIColor(red: 0.2, green: 0.24, blue: 0.2, alpha: 1)),
            textColor: .white,
            words: [
                DemoWord(word: "flat white", pos: "phr.", cefr: .b1, phonetic: "/ˌflæt ˈwaɪt/", gloss: "馥芮白咖啡", explanation: "一种奶泡很薄、咖啡味较浓的奶咖，新西兰和澳洲的招牌咖啡。", example: "Could I get a flat white, please?", translation: "请给我一杯馥芮白。", note: "点单时常说 small / large，不说 tall / grande。", context: "Flat white  5.50"),
                DemoWord(word: "gluten", pos: "n.", cefr: .b2, phonetic: "/ˈɡluːtən/", gloss: "麸质", explanation: "小麦等谷物里的一种蛋白质，有人对它过敏。", example: "Is this cake gluten free?", translation: "这个蛋糕不含麸质吗？", note: "菜单上的 GF 就是 gluten free。", context: "Gluten free options"),
                DemoWord(word: "counter", pos: "n.", cefr: .a2, phonetic: "/ˈkaʊntə/", gloss: "柜台", explanation: "店里点单、付款的台子。", example: "Please pay at the counter.", translation: "请在柜台付款。", note: "Order at the counter 意思是没有服务员来点单。", context: "Please order at the counter"),
                DemoWord(word: "option", pos: "n.", cefr: .b1, phonetic: "/ˈɒpʃən/", gloss: "选择", explanation: "可以挑选的一种做法或东西。", example: "Do you have any vegan options?", translation: "你们有纯素的选择吗？", note: "", context: "Gluten free options")
            ]
        ),
        DemoScene(
            title: "Countdown 超市货架",
            scene: .supermarket,
            daysAgo: 2,
            lines: ["FREE RANGE EGGS", "12 pack", "Best before 12 OCT", "Club price $6.99", "Contains: wheat, soy"],
            colors: (UIColor(red: 0.98, green: 0.96, blue: 0.9, alpha: 1), UIColor(red: 0.95, green: 0.9, blue: 0.8, alpha: 1)),
            textColor: UIColor(red: 0.1, green: 0.3, blue: 0.15, alpha: 1),
            words: [
                DemoWord(word: "free range", pos: "adj.", cefr: .b2, phonetic: "/ˌfriː ˈreɪndʒ/", gloss: "散养的", explanation: "动物可以在户外自由活动，不是笼养。", example: "I only buy free range eggs.", translation: "我只买散养鸡蛋。", note: "价格通常比 caged eggs 贵一些。", context: "FREE RANGE EGGS"),
                DemoWord(word: "best before", pos: "phr.", cefr: .b1, phonetic: "/best bɪˈfɔː/", gloss: "最佳食用日期", explanation: "在这个日期前吃品质最好，过期不一定不能吃。", example: "Check the best before date.", translation: "看一下最佳食用日期。", note: "Use by 才是必须在此前吃完的日期。", context: "Best before 12 OCT"),
                DemoWord(word: "contain", pos: "v.", cefr: .a2, phonetic: "/kənˈteɪn/", gloss: "含有", explanation: "里面有某种成分。", example: "This bread contains nuts.", translation: "这个面包含有坚果。", note: "过敏原通常写在 Contains 后面。", context: "Contains: wheat, soy"),
                DemoWord(word: "wheat", pos: "n.", cefr: .b1, phonetic: "/wiːt/", gloss: "小麦", explanation: "做面粉和面包的谷物。", example: "Is there wheat in this sauce?", translation: "这个酱里有小麦吗？", note: "", context: "Contains: wheat, soy")
            ]
        ),
        DemoScene(
            title: "租房广告",
            scene: .housing,
            daysAgo: 5,
            lines: ["FOR RENT", "2 bedroom unit — $620 pw", "Bond: 4 weeks", "Utilities not included", "Viewing by appointment"],
            colors: (UIColor(red: 0.9, green: 0.93, blue: 0.97, alpha: 1), UIColor(red: 0.82, green: 0.87, blue: 0.95, alpha: 1)),
            textColor: UIColor(red: 0.1, green: 0.15, blue: 0.35, alpha: 1),
            words: [
                DemoWord(word: "bond", pos: "n.", cefr: .b2, phonetic: "/bɒnd/", gloss: "租房押金", explanation: "租房时交给房东的押金，退租时退还。", example: "The bond is four weeks' rent.", translation: "押金是四周的房租。", note: "新西兰的押金要交到 Tenancy Services，不是直接给房东。", context: "Bond: 4 weeks"),
                DemoWord(word: "utility", pos: "n.", cefr: .b2, phonetic: "/juːˈtɪləti/", gloss: "水电煤", explanation: "水、电、燃气、网络等公共服务费用。", example: "Are utilities included in the rent?", translation: "房租包含水电费吗？", note: "看房时一定要问清楚 utilities 是否包含。", context: "Utilities not included"),
                DemoWord(word: "appointment", pos: "n.", cefr: .b1, phonetic: "/əˈpɔɪntmənt/", gloss: "预约", explanation: "提前约好的时间。", example: "Can I make an appointment for a viewing?", translation: "我可以预约看房吗？", note: "", context: "Viewing by appointment"),
                DemoWord(word: "pw", pos: "abbr.", cefr: .b1, phonetic: "", gloss: "每周", explanation: "per week 的缩写，房租按周计算。", example: "The rent is $620 pw.", translation: "房租是每周 620 元。", note: "新西兰和澳洲房租多按周报价。", context: "2 bedroom unit — $620 pw")
            ]
        ),
        DemoScene(
            title: "公交站牌",
            scene: .transport,
            daysAgo: 9,
            lines: ["BUS STOP 7012", "Tap on with your HOP card", "Next departure: 8:15", "Request stop — signal driver"],
            colors: (UIColor(red: 0.05, green: 0.25, blue: 0.45, alpha: 1), UIColor(red: 0.05, green: 0.35, blue: 0.6, alpha: 1)),
            textColor: .white,
            words: [
                DemoWord(word: "tap on", pos: "phr.", cefr: .b1, phonetic: "/tæp ɒn/", gloss: "上车刷卡", explanation: "上车时把交通卡贴在读卡器上。", example: "Don't forget to tap off when you get off.", translation: "下车时别忘了刷卡。", note: "下车刷卡叫 tap off，忘了会被多扣钱。", context: "Tap on with your HOP card"),
                DemoWord(word: "departure", pos: "n.", cefr: .b1, phonetic: "/dɪˈpɑːtʃə/", gloss: "出发", explanation: "车、飞机离开的时间。", example: "The next departure is at 8:15.", translation: "下一班 8 点 15 分出发。", note: "", context: "Next departure: 8:15"),
                DemoWord(word: "signal", pos: "v.", cefr: .b2, phonetic: "/ˈsɪɡnəl/", gloss: "示意", explanation: "用手势或按钮告诉别人你的意图。", example: "Signal the driver to stop.", translation: "示意司机停车。", note: "在站台招手，司机才会停。", context: "Request stop — signal driver")
            ]
        )
    ]

    // MARK: - 写入

    static func seed(into context: ModelContext) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var created: [VocabWord] = []

        for demo in scenes {
            let date = calendar.date(byAdding: .day, value: -demo.daysAgo, to: Date()) ?? Date()
            let image = render(demo)
            let scan = Scan(createdAt: date)
            scan.title = demo.title
            scan.scene = demo.scene
            scan.imageData = image.jpegData(compressionQuality: 0.85)
            scan.thumbnailData = ImageUtilities.jpeg(image, maxDimension: 600, quality: 0.8)
            scan.imageAspectRatio = Double(image.size.width / image.size.height)
            scan.ocrText = demo.lines.joined(separator: "\n")
            scan.lines = demo.lines.map { OCRLine(text: $0, rect: .zero) }
            scan.candidates = demo.words.map {
                WordCandidate(word: $0.word, lemma: $0.word, partOfSpeech: $0.pos, cefrRaw: $0.cefr.rawValue, gloss: $0.gloss)
            }
            context.insert(scan)

            for item in demo.words {
                let word = VocabWord(word: item.word, partOfSpeech: item.pos, cefr: item.cefr, gloss: item.gloss, contextSnippet: item.context, addedAt: date)
                word.phonetic = item.phonetic
                word.explanation = item.explanation
                word.exampleSentence = item.example
                word.exampleTranslation = item.translation
                word.sceneNote = item.note
                word.explanationStatus = .ready
                context.insert(word)
                word.scans.append(scan)
                created.append(word)
            }
        }

        // 旧一点的场景：已经学过；最新的场景：待学
        for (index, word) in created.enumerated() where word.addedAt < calendar.date(byAdding: .day, value: -1, to: today)! {
            let introduced = word.addedAt
            word.introducedAt = introduced
            word.lastReviewedAt = introduced
            word.repetitions = index % 3 + 1
            word.intervalDays = [1, 3, 8, 25][index % 4]
            word.state = word.intervalDays >= SpacedRepetition.masteredThreshold ? .mastered : .learning
            // 有几个词忘过几次，好让「总是记不住的词」有内容
            if index % 3 == 1 && word.state == .learning { word.lapses = index % 4 + 1 }
            word.dueDate = index % 2 == 0 ? today : (calendar.date(byAdding: .day, value: index % 5 + 1, to: today) ?? today)
        }

        // 最近 3 周的学习记录（热力图和连续天数）
        for dayOffset in 1...20 where dayOffset % 6 != 0 {
            guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
            // 每天复习量不一样：有的天没做完，有的天满环
            for item in 0..<[3, 6, 10, 12][dayOffset % 4] {
                let word = created[(dayOffset + item) % created.count]
                context.insert(ReviewLog(wordID: word.id, word: word.word, rating: item % 4 == 0 ? .hard : .good, wasNew: false, intervalAfter: 3, reviewedAt: day))
            }
        }
        try? context.save()
    }

    /// 画一张“照片”：渐变底色 + 几行文字
    private static func render(_ demo: DemoScene) -> UIImage {
        let size = CGSize(width: 1200, height: 1500)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let colors = [demo.colors.0.cgColor, demo.colors.1.cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                ctx.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
            }
            var y: CGFloat = 220
            for (index, line) in demo.lines.enumerated() {
                let fontSize: CGFloat = index == 0 ? 92 : 64
                let font = UIFont.systemFont(ofSize: fontSize, weight: index == 0 ? .heavy : .semibold)
                let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: demo.textColor]
                let text = line as NSString
                let bounds = text.boundingRect(with: CGSize(width: size.width - 160, height: .greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: attributes, context: nil)
                text.draw(with: CGRect(x: 80, y: y, width: size.width - 160, height: bounds.height), options: .usesLineFragmentOrigin, attributes: attributes, context: nil)
                y += bounds.height + (index == 0 ? 90 : 56)
            }
        }
    }
}
#endif
