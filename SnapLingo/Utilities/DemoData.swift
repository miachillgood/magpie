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
            UserDefaults.standard.removeObject(forKey: MistakeBackfill.doneKey)
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
        // -newWordsPerDay 2：调小每天的新词上限，让新词排队，方便看结算页的「再学 5 个新词」
        if let index = arguments.firstIndex(of: "-newWordsPerDay"), index + 1 < arguments.count, let count = Int(arguments[index + 1]) {
            let settings = UserSettings.current(in: context)
            settings.newWordsPerDay = count
            try? context.save()
        }
        // -demoFolder：建一个“搬家”文件夹，放进几个词，看文件夹的界面
        if arguments.contains("-demoFolder"), ((try? context.fetchCount(FetchDescriptor<WordFolder>())) ?? 0) == 0 {
            let words = ((try? context.fetch(FetchDescriptor<VocabWord>())) ?? []).filter { ["detergent", "fabric softener", "rinse"].contains($0.normalizedForm) }
            let folder = WordLibrary.createFolder(name: String(localized: "搬家"), iconName: "icon-box", context: context)
            WordLibrary.add(words, to: folder, context: context)
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
        /// 照片上的店名（首页胶囊）；空 = 没有店名
        var placeName = ""
        /// 拍照的街区（首页「刚刚在 Ponsonby 的」）
        var neighborhood = ""
        var scene: SceneType
        var daysAgo: Int
        /// Preview Content/DemoScenes.xcassets 里的示意照片
        var imageName: String
        var lines: [String]
        var words: [DemoWord]
    }

    private static let scenes: [DemoScene] = [
        DemoScene(
            title: "The Oyster Inn " + String(localized: "菜单", comment: "Demo scene title noun after the restaurant name The Oyster Inn"),
            placeName: "The Oyster Inn",
            neighborhood: "Ponsonby",
            scene: .restaurant,
            daysAgo: 0,
            imageName: "DemoOysterInn",
            lines: ["THE OYSTER INN", "Market Oysters (1/2 dozen)  24", "Slow-cooked Lamb Shoulder  38", "Market Fish  MP", "Please inform our staff of any allergies or dietary requirements."],
            words: [
                DemoWord(word: "dozen", pos: "n.", cefr: .a2, phonetic: "/ˈdʌzən/", gloss: "一打（十二个）", explanation: "十二个为一组的数量单位，half a dozen 就是六个。", example: "Can we get half a dozen oysters?", translation: "我们能要六只生蚝吗？", note: "菜单上的 1/2 dozen 就是 6 只。", context: "Market Oysters (1/2 dozen)  24"),
                DemoWord(word: "slow-cooked", pos: "adj.", cefr: .b2, phonetic: "/ˌsləʊ ˈkʊkt/", gloss: "慢炖的", explanation: "用小火长时间烹煮，肉会很软烂。", example: "The slow-cooked lamb falls off the bone.", translation: "慢炖羊肉一碰就脱骨。", note: "", context: "Slow-cooked Lamb Shoulder  38"),
                DemoWord(word: "MP", pos: "abbr.", cefr: .b1, phonetic: "", gloss: "时价", explanation: "market price 的缩写，价格按当天进货价定。", example: "What's the market price for the fish today?", translation: "今天的鱼时价多少？", note: "看到 MP 可以直接问服务员今天多少钱。", context: "Market Fish  MP"),
                DemoWord(word: "dietary requirement", pos: "phr.", cefr: .b2, phonetic: "/ˈdaɪətəri rɪˈkwaɪəmənt/", gloss: "饮食要求", explanation: "因为过敏、宗教或健康原因不能吃某些东西。", example: "Do you have any dietary requirements?", translation: "您有什么饮食上的要求吗？", note: "订餐、参加活动时常被问到，比如 vegetarian、no nuts。", context: "Please inform our staff of any allergies or dietary requirements.")
            ]
        ),
        DemoScene(
            title: String(localized: "面包店柜台", comment: "Demo scene title: a bakery counter"),
            neighborhood: "Ponsonby",
            scene: .restaurant,
            daysAgo: 0,
            imageName: "DemoBakery",
            lines: ["Freshly Baked", "Sourdough  $6.5", "Naturally leavened", "Almond Croissant  With glaze  $5.5", "Roasted Veg Sandwich  Savoury filling  $8.0"],
            words: [
                DemoWord(word: "sourdough", pos: "n.", cefr: .b2, phonetic: "/ˈsaʊədəʊ/", gloss: "酸种面包", explanation: "用天然酵种慢慢发酵的面包，带一点酸味。", example: "I'd like a loaf of sourdough, please.", translation: "请给我一条酸种面包。", note: "面包按条买说 a loaf of。", context: "Sourdough  $6.5"),
                DemoWord(word: "leavened", pos: "adj.", cefr: .c1, phonetic: "/ˈlevənd/", gloss: "发酵过的", explanation: "加了酵母或酵种、让面团膨胀起来的。", example: "This bread is naturally leavened.", translation: "这款面包是天然发酵的。", note: "", context: "Naturally leavened"),
                DemoWord(word: "glaze", pos: "n.", cefr: .b2, phonetic: "/ɡleɪz/", gloss: "糖霜；亮面", explanation: "刷在糕点表面的一层糖浆，让它发亮。", example: "The danish has a vanilla glaze.", translation: "这个丹麦酥上有香草糖霜。", note: "", context: "Almond Croissant  With glaze  $5.5"),
                DemoWord(word: "savoury", pos: "adj.", cefr: .b2, phonetic: "/ˈseɪvəri/", gloss: "咸味的", explanation: "咸的、不是甜的食物。", example: "Do you have anything savoury?", translation: "有咸口的吗？", note: "英式拼写 savoury，美式是 savory。", context: "Roasted Veg Sandwich  Savoury filling  $8.0")
            ]
        ),
        DemoScene(
            title: "Countdown " + String(localized: "果汁货架", comment: "Demo scene title noun after the supermarket name Countdown"),
            placeName: "Countdown",
            scene: .shopping,
            daysAgo: 1,
            imageName: "DemoJuice",
            lines: ["100% ORANGE JUICE", "A blend of orange juice from concentrate", "No added sugar. Unsweetened.", "Keep refrigerated below 4°C.", "Consume within 5 days of opening."],
            words: [
                DemoWord(word: "concentrate", pos: "n.", cefr: .c1, phonetic: "/ˈkɒnsəntreɪt/", gloss: "浓缩汁", explanation: "去掉水分后的果汁，加水还原后再装瓶。", example: "Is this juice made from concentrate?", translation: "这果汁是浓缩还原的吗？", note: "not from concentrate 是非浓缩还原，通常更贵。", context: "A blend of orange juice from concentrate"),
                DemoWord(word: "unsweetened", pos: "adj.", cefr: .b2, phonetic: "/ʌnˈswiːtənd/", gloss: "无添加糖的", explanation: "没有额外加糖，只有食物本身的糖分。", example: "I prefer unsweetened yoghurt.", translation: "我喜欢无糖酸奶。", note: "", context: "No added sugar. Unsweetened."),
                DemoWord(word: "refrigerate", pos: "v.", cefr: .b2, phonetic: "/rɪˈfrɪdʒəreɪt/", gloss: "冷藏", explanation: "放进冰箱冷藏保存。", example: "Refrigerate after opening.", translation: "开封后请冷藏。", note: "", context: "Keep refrigerated below 4°C."),
                DemoWord(word: "consume", pos: "v.", cefr: .b2, phonetic: "/kənˈsjuːm/", gloss: "食用；消耗", explanation: "吃掉或喝掉，包装上常用的正式说法。", example: "Consume within 3 days of opening.", translation: "开封后 3 天内食用。", note: "", context: "Consume within 5 days of opening.")
            ]
        ),
        DemoScene(
            title: String(localized: "药房货架", comment: "Demo scene title: pharmacy shelf"),
            scene: .medical,
            daysAgo: 2,
            imageName: "DemoPharmacy",
            lines: ["Pharmacy", "Panadol  Paracetamol 500 mg", "Benadryl Hayfever Relief  Once a day", "Drixne Decongestant Nasal Spray", "Savlon Antiseptic Cream  For cuts, grazes and minor burns"],
            words: [
                DemoWord(word: "hayfever", pos: "n.", cefr: .b2, phonetic: "/ˈheɪfiːvə/", gloss: "花粉症", explanation: "对花粉过敏，会打喷嚏、流鼻涕、眼睛痒。", example: "My hayfever is really bad this spring.", translation: "今年春天我的花粉症特别严重。", note: "新西兰春天花粉多，药房里很常见。", context: "Benadryl Hayfever Relief  Once a day"),
                DemoWord(word: "decongestant", pos: "n.", cefr: .c1, phonetic: "/ˌdiːkənˈdʒestənt/", gloss: "减充血剂", explanation: "缓解鼻塞的药。", example: "Do you have a decongestant for a blocked nose?", translation: "有治鼻塞的药吗？", note: "鼻塞说 blocked nose 或 stuffy nose。", context: "Drixne Decongestant Nasal Spray"),
                DemoWord(word: "antiseptic", pos: "adj.", cefr: .c1, phonetic: "/ˌæntiˈseptɪk/", gloss: "消毒的；抗菌的", explanation: "能杀菌、防止伤口感染的。", example: "Put some antiseptic cream on the cut.", translation: "在伤口上涂点消毒药膏。", note: "", context: "Savlon Antiseptic Cream  For cuts, grazes and minor burns"),
                DemoWord(word: "graze", pos: "n.", cefr: .c1, phonetic: "/ɡreɪz/", gloss: "擦伤", explanation: "皮肤被擦破的小伤口。", example: "It's just a graze, nothing serious.", translation: "只是擦伤，不严重。", note: "", context: "Savlon Antiseptic Cream  For cuts, grazes and minor burns")
            ]
        ),
        DemoScene(
            title: String(localized: "服装店吊牌", comment: "Demo scene title: clothing store tags"),
            scene: .shopping,
            daysAgo: 3,
            imageName: "DemoClothing",
            lines: ["100% Linen  Breathable.", "Shell: 100% Linen  Lining: 100% Cotton", "Tumble dry low", "Fitting Room  Please take up to 5 items at a time.", "Our team can help with hemming, resizing and other alterations."],
            words: [
                DemoWord(word: "linen", pos: "n.", cefr: .b2, phonetic: "/ˈlɪnɪn/", gloss: "亚麻", explanation: "一种透气、凉快的天然面料，容易起皱。", example: "Linen shirts are perfect for summer.", translation: "亚麻衬衫很适合夏天穿。", note: "", context: "100% Linen  Breathable."),
                DemoWord(word: "tumble dry", pos: "phr.", cefr: .b2, phonetic: "/ˈtʌmbəl draɪ/", gloss: "滚筒烘干", explanation: "用烘干机转动烘干衣服。", example: "Can I tumble dry this jumper?", translation: "这件毛衣可以烘干吗？", note: "low 是低温，do not tumble dry 就是不能烘。", context: "Tumble dry low"),
                DemoWord(word: "fitting room", pos: "n.", cefr: .b1, phonetic: "/ˈfɪtɪŋ ruːm/", gloss: "试衣间", explanation: "商店里试穿衣服的小隔间。", example: "Where's the fitting room?", translation: "试衣间在哪里？", note: "美式也叫 dressing room。", context: "Fitting Room  Please take up to 5 items at a time."),
                DemoWord(word: "alteration", pos: "n.", cefr: .b2, phonetic: "/ˌɔːltəˈreɪʃən/", gloss: "改衣服", explanation: "把衣服改短、改小等修改服务。", example: "Do you do alterations here?", translation: "你们这里可以改衣服吗？", note: "改裤脚叫 hemming。", context: "Our team can help with hemming, resizing and other alterations.")
            ]
        ),
        DemoScene(
            title: String(localized: "自助洗衣店", comment: "Demo scene title: a laundromat"),
            scene: .housing,
            daysAgo: 5,
            imageName: "DemoLaundromat",
            lines: ["How to Use Our Washers", "Load laundry  Do not overload the machine.", "Add detergent (and fabric softener if desired)", "Rinse + Spin  Rinse and spin only", "Delicate  Gentle care for delicate fabrics"],
            words: [
                DemoWord(word: "detergent", pos: "n.", cefr: .b2, phonetic: "/dɪˈtɜːdʒənt/", gloss: "洗衣剂", explanation: "洗衣服用的洗衣粉或洗衣液。", example: "How much detergent should I use?", translation: "我该放多少洗衣液？", note: "", context: "Add detergent (and fabric softener if desired)"),
                DemoWord(word: "fabric softener", pos: "n.", cefr: .b2, phonetic: "/ˈfæbrɪk ˈsɒfənə/", gloss: "柔顺剂", explanation: "让衣服变软、有香味的洗衣用品。", example: "I always add fabric softener to my towels.", translation: "我洗毛巾总会加柔顺剂。", note: "", context: "Add detergent (and fabric softener if desired)"),
                DemoWord(word: "overload", pos: "v.", cefr: .b2, phonetic: "/ˌəʊvəˈləʊd/", gloss: "超载；装太多", explanation: "放进去的东西超过能承受的量。", example: "Don't overload the washing machine.", translation: "别往洗衣机里塞太多衣服。", note: "", context: "Load laundry  Do not overload the machine."),
                DemoWord(word: "rinse", pos: "v.", cefr: .b1, phonetic: "/rɪns/", gloss: "冲洗；漂洗", explanation: "用清水把肥皂或脏东西冲掉。", example: "Rinse the cup before you use it.", translation: "用之前把杯子冲一下。", note: "", context: "Rinse + Spin  Rinse and spin only")
            ]
        ),
        DemoScene(
            title: "Airbnb " + String(localized: "房屋须知", comment: "Demo scene title noun after the name Airbnb: house rules"),
            placeName: "Airbnb",
            scene: .housing,
            daysAgo: 8,
            imageName: "DemoAirbnb",
            lines: ["House Rules", "Keep noise to a minimum after 10pm.", "Fire Evacuation Plan  Do not use the lifts.", "Proceed to the assembly point.", "Food scraps only. No plastic please."],
            words: [
                DemoWord(word: "evacuation", pos: "n.", cefr: .c1, phonetic: "/ɪˌvækjuˈeɪʃən/", gloss: "疏散", explanation: "紧急情况下让大家离开建筑或地区。", example: "Follow the evacuation route to the exit.", translation: "沿疏散路线走到出口。", note: "", context: "Fire Evacuation Plan  Do not use the lifts."),
                DemoWord(word: "assembly point", pos: "n.", cefr: .b2, phonetic: "/əˈsembli pɔɪnt/", gloss: "集合点", explanation: "火警时大家疏散后集合的地方。", example: "Where is the assembly point?", translation: "集合点在哪里？", note: "", context: "Proceed to the assembly point."),
                DemoWord(word: "lift", pos: "n.", cefr: .a2, phonetic: "/lɪft/", gloss: "电梯", explanation: "英式英语里的电梯，美式说 elevator。", example: "Take the lift to the third floor.", translation: "坐电梯到三楼。", note: "", context: "Fire Evacuation Plan  Do not use the lifts."),
                DemoWord(word: "scraps", pos: "n.", cefr: .b2, phonetic: "/skræps/", gloss: "残渣；剩饭", explanation: "吃剩的、切下来不要的食物碎块。", example: "Put the food scraps in the yellow bin.", translation: "把厨余放进黄色垃圾桶。", note: "", context: "Food scraps only. No plastic please.")
            ]
        ),
        DemoScene(
            title: String(localized: "街头路牌", comment: "Demo scene title: street signs"),
            neighborhood: "Auckland CBD",
            scene: .signage,
            daysAgo: 12,
            imageName: "DemoStreet",
            lines: ["Queen St  27 - 53", "LOADING ZONE  8am - 6pm", "PERMIT HOLDERS ONLY", "Victoria St Intersection", "DETOUR"],
            words: [
                DemoWord(word: "loading zone", pos: "n.", cefr: .b2, phonetic: "/ˈləʊdɪŋ zəʊn/", gloss: "装卸区", explanation: "只给货车临时停车上下货的地方。", example: "You can't park in the loading zone.", translation: "装卸区不能停车。", note: "注意时间段，规定时间外有时可以停。", context: "LOADING ZONE  8am - 6pm"),
                DemoWord(word: "permit", pos: "n.", cefr: .b2, phonetic: "/ˈpɜːmɪt/", gloss: "许可证", explanation: "官方发的允许做某事的证件。", example: "You need a permit to park here.", translation: "在这里停车需要许可证。", note: "", context: "PERMIT HOLDERS ONLY"),
                DemoWord(word: "intersection", pos: "n.", cefr: .b2, phonetic: "/ˌɪntəˈsekʃən/", gloss: "十字路口", explanation: "两条路交叉的地方。", example: "Turn left at the next intersection.", translation: "下个路口左转。", note: "", context: "Victoria St Intersection"),
                DemoWord(word: "detour", pos: "n.", cefr: .b2, phonetic: "/ˈdiːtʊə/", gloss: "绕行", explanation: "原路不通时要走的另一条路。", example: "We had to take a detour because of roadworks.", translation: "因为修路我们只好绕道。", note: "", context: "DETOUR")
            ]
        ),
        DemoScene(
            title: String(localized: "公交车上", comment: "Demo scene title: inside a bus"),
            scene: .transport,
            daysAgo: 4,
            imageName: "DemoBus",
            lines: ["Please tag on tag off", "Northern Express  Outbound", "Britomart  Parnell  Newmarket  Transfer", "Service disruption", "Buses are being replaced due to track works. Please allow extra travel time."],
            words: [
                DemoWord(word: "tag on", pos: "phr.", cefr: .b1, phonetic: "/tæɡ ɒn/", gloss: "上车刷卡", explanation: "上车时把 AT HOP 卡贴在读卡器上。", example: "Don't forget to tag off when you get off.", translation: "下车时别忘了刷卡。", note: "下车刷卡叫 tag off，忘了会被多扣钱。", context: "Please tag on tag off"),
                DemoWord(word: "outbound", pos: "adj.", cefr: .b2, phonetic: "/ˈaʊtbaʊnd/", gloss: "出城方向的", explanation: "从市中心往外开的方向，反方向是 inbound。", example: "Is this the outbound platform?", translation: "这是出城方向的站台吗？", note: "", context: "Northern Express  Outbound"),
                DemoWord(word: "disruption", pos: "n.", cefr: .b2, phonetic: "/dɪsˈrʌpʃən/", gloss: "中断；受阻", explanation: "服务因为意外或施工不能正常运行。", example: "There are disruptions on the train line today.", translation: "今天火车线路有运营中断。", note: "", context: "Service disruption"),
                DemoWord(word: "allow", pos: "v.", cefr: .b1, phonetic: "/əˈlaʊ/", gloss: "预留（时间）", explanation: "allow extra time 是多留出一些时间的意思。", example: "Allow 20 minutes to get to the airport.", translation: "去机场要预留 20 分钟。", note: "这里不是“允许”的意思。", context: "Buses are being replaced due to track works. Please allow extra travel time.")
            ]
        ),
        DemoScene(
            title: String(localized: "停车场缴费机", comment: "Demo scene title: a car park pay machine"),
            scene: .transport,
            daysAgo: 10,
            imageName: "DemoParking",
            lines: ["Pay Here for Parking", "Validation  Scan your validation ticket", "Maximum stay  3 hours unless otherwise signed.", "Spaces marked as reserved are for authorised vehicles only.", "Vehicles in breach of these conditions may receive a parking infringement."],
            words: [
                DemoWord(word: "validation", pos: "n.", cefr: .c1, phonetic: "/ˌvælɪˈdeɪʃən/", gloss: "（停车）验证盖章", explanation: "商场给的停车优惠凭证，扫一下就能免费或打折。", example: "Can I get parking validation here?", translation: "在这里消费能拿停车优惠吗？", note: "买完东西可以问收银员要 validation。", context: "Validation  Scan your validation ticket"),
                DemoWord(word: "maximum stay", pos: "phr.", cefr: .b2, phonetic: "/ˈmæksɪməm steɪ/", gloss: "最长停留时间", explanation: "最多可以停多久，超时可能被罚款。", example: "The maximum stay here is two hours.", translation: "这里最多停两小时。", note: "", context: "Maximum stay  3 hours unless otherwise signed."),
                DemoWord(word: "authorised", pos: "adj.", cefr: .b2, phonetic: "/ˈɔːθəraɪzd/", gloss: "经授权的", explanation: "得到正式许可的。", example: "Authorised staff only.", translation: "仅限授权人员。", note: "英式拼写 authorised，美式是 authorized。", context: "Spaces marked as reserved are for authorised vehicles only."),
                DemoWord(word: "infringement", pos: "n.", cefr: .c1, phonetic: "/ɪnˈfrɪndʒmənt/", gloss: "违规；罚单", explanation: "违反规定，停车违规会收到 infringement notice（罚单）。", example: "I got a parking infringement yesterday.", translation: "我昨天收到一张停车罚单。", note: "", context: "Vehicles in breach of these conditions may receive a parking infringement.")
            ]
        )
    ]

    // MARK: - 演示用的「AI」（录视频用：模拟器没有 API key）
    // -demoAI：拍照后的挑词和单词解释直接用上面的示例内容；文字识别仍然是真的
    // -demoSkipScene DemoOysterInn：示例数据里先不放这个场景，留着现场拍

    static var demoAI: Bool { ProcessInfo.processInfo.arguments.contains("-demoAI") }

    /// 照片里认出的文字和哪个示例场景最像，就用它的词当 AI 推荐
    static func extraction(for text: String) -> SceneExtraction? {
        let lower = text.lowercased()
        func score(_ scene: DemoScene) -> Int { scene.words.filter { lower.contains($0.word.lowercased()) }.count }
        guard let best = scenes.max(by: { score($0) < score($1) }), score(best) > 0 else { return nil }
        return SceneExtraction(
            scene: best.scene,
            title: best.title,
            candidates: best.words.map { WordCandidate(word: $0.word, lemma: $0.word, partOfSpeech: $0.pos, cefrRaw: $0.cefr.rawValue, gloss: $0.gloss) },
            place: best.placeName
        )
    }

    /// 新存的词用示例里的解释；找不到返回 false
    static func fillExplanation(_ word: VocabWord) -> Bool {
        let key = word.word.normalizedWordKey
        guard let item = scenes.flatMap(\.words).first(where: { $0.word.normalizedWordKey == key }) else { return false }
        word.phonetic = item.phonetic
        word.explanation = item.explanation
        word.exampleSentence = item.example
        word.exampleTranslation = item.translation
        word.sceneNote = item.note
        if word.gloss.isEmpty { word.gloss = item.gloss }
        word.explanationStatus = .ready
        return true
    }

    // MARK: - 写入

    static func seed(into context: ModelContext) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var created: [VocabWord] = []
        let arguments = ProcessInfo.processInfo.arguments
        let skipped = arguments.firstIndex(of: "-demoSkipScene").flatMap { $0 + 1 < arguments.count ? arguments[$0 + 1] : nil }

        for demo in scenes where demo.imageName != skipped {
            let date = calendar.date(byAdding: .day, value: -demo.daysAgo, to: Date()) ?? Date()
            guard let image = UIImage(named: demo.imageName) else { continue }
            let scan = Scan(createdAt: date)
            scan.title = demo.title
            scan.placeName = demo.placeName
            scan.neighborhood = demo.neighborhood
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
}
#endif
