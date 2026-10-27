//
//  VoiceInput.swift
//  SnapLingo
//
//  「说一说」的录音和转文字（iOS 26 的 SpeechAnalyzer，全部在手机上识别，录音不上传）。
//  同一段录音同时喂给两个识别器：英语和用户的母语。
//  念一个英文词时英语那条准，用母语说一段话时母语那条准；两条都交给 AI，由它判断用户想干嘛。
//

import AVFoundation
import Speech

enum VoiceInputError: LocalizedError {
    case microphoneDenied
    case unavailable

    var errorDescription: String? {
        switch self {
        case .microphoneDenied: String(localized: "没有麦克风权限，可以在系统设置里打开")
        case .unavailable: String(localized: "这台设备暂时不支持语音识别")
        }
    }
}

@Observable
final class VoiceRecorder {
    enum Phase: Equatable {
        case idle
        /// 第一次用某种语言时要下载识别模型
        case preparing
        case recording
        case finishing
    }

    private(set) var phase: Phase = .idle
    /// 英语识别器听到的
    private(set) var english = ""
    /// 母语识别器听到的
    private(set) var native = ""
    /// 音量 0...1，给麦克风按钮做动画
    private(set) var level: Float = 0

    private let engine = AVAudioEngine()
    private var lanes: [Lane] = []
    private var levelTask: Task<Void, Never>?
    /// 只有真的开过麦克风才去碰 inputNode：没录音就关面板时，访问它会无谓地初始化音频硬件
    private var tapInstalled = false

    /// 一种语言一条：一个识别模块 + 一个 analyzer + 喂音频的入口
    private final class Lane {
        let isEnglish: Bool
        let module: any SpeechModule
        let analyzer: SpeechAnalyzer
        let input: AsyncStream<AnalyzerInput>.Continuation
        let stream: AsyncStream<AnalyzerInput>
        var finalized = ""
        var volatile = ""
        var task: Task<Void, Never>?

        init(isEnglish: Bool, module: any SpeechModule) {
            self.isEnglish = isEnglish
            self.module = module
            self.analyzer = SpeechAnalyzer(modules: [module])
            (stream, input) = AsyncStream<AnalyzerInput>.makeStream()
        }

        var text: String { (finalized + volatile).trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    /// 母语对应的识别语言；母语就是英语时只用一条
    static func speechLocale(for language: NativeLanguage) -> Locale? {
        switch language {
        case .simplifiedChinese: Locale(identifier: "zh-CN")
        case .traditionalChinese: Locale(identifier: "zh-TW")
        case .japanese: Locale(identifier: "ja-JP")
        case .korean: Locale(identifier: "ko-KR")
        case .spanish: Locale(identifier: "es-ES")
        case .portuguese: Locale(identifier: "pt-BR")
        case .english: nil
        }
    }

    func start(native language: NativeLanguage) async throws {
        guard phase == .idle else { return }
        english = ""
        native = ""
        guard await AVAudioApplication.requestRecordPermission() else { throw VoiceInputError.microphoneDenied }

        phase = .preparing
        do {
            var locales: [(Locale, Bool)] = [(Locale(identifier: "en-US"), true)]
            if let locale = Self.speechLocale(for: language) { locales.append((locale, false)) }
            var built: [Lane] = []
            for (locale, isEnglish) in locales {
                guard let module = await Self.module(for: locale) else { continue }
                if let request = try await AssetInventory.assetInstallationRequest(supporting: [module]) {
                    try await request.downloadAndInstall()
                }
                built.append(Lane(isEnglish: isEnglish, module: module))
            }
            guard !built.isEmpty,
                  let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: built.map(\.module))
            else { throw VoiceInputError.unavailable }

            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            for lane in built {
                try await lane.analyzer.start(inputSequence: lane.stream)
                lane.task = Task { await self.collect(lane) }
            }
            lanes = built

            let input = engine.inputNode
            let inputFormat = input.outputFormat(forBus: 0)
            guard let converter = BufferConverter(from: inputFormat, to: format) else { throw VoiceInputError.unavailable }
            // 音量从音频线程经过一条流送回主线程
            let (levels, levelInput) = AsyncStream<Float>.makeStream(bufferingPolicy: .bufferingNewest(1))
            levelTask = Task {
                for await level in levels { self.level = level }
            }
            tapInstalled = true
            input.installTap(
                onBus: 0,
                bufferSize: 4096,
                format: inputFormat,
                block: Self.tapBlock(converter: converter, inputs: built.map(\.input), levels: levelInput)
            )
            engine.prepare()
            try engine.start()
            phase = .recording
        } catch {
            await cancel()
            throw error
        }
    }

    /// 说完了：把剩下的音频识别完，返回两条文字
    func stop() async -> (english: String, native: String) {
        guard phase == .recording else { return (english, native) }
        phase = .finishing
        stopAudio()
        for lane in lanes {
            lane.input.finish()
            try? await lane.analyzer.finalizeAndFinishThroughEndOfInput()
        }
        for lane in lanes { await lane.task?.value }
        publish()
        lanes = []
        phase = .idle
        return (english, native)
    }

    /// 关掉面板时：不要结果了
    func cancel() async {
        guard phase != .idle || !lanes.isEmpty else { return }
        stopAudio()
        for lane in lanes {
            lane.input.finish()
            await lane.analyzer.cancelAndFinishNow()
            lane.task?.cancel()
        }
        lanes = []
        phase = .idle
    }

    private func stopAudio() {
        if engine.isRunning { engine.stop() }
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        levelTask?.cancel()
        levelTask = nil
        level = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func collect(_ lane: Lane) async {
        func apply(_ text: AttributedString, isFinal: Bool) {
            let string = String(text.characters)
            if isFinal {
                lane.finalized += string
                lane.volatile = ""
            } else {
                lane.volatile = string
            }
            publish()
        }
        do {
            if let transcriber = lane.module as? SpeechTranscriber {
                for try await result in transcriber.results { apply(result.text, isFinal: result.isFinal) }
            } else if let transcriber = lane.module as? DictationTranscriber {
                for try await result in transcriber.results { apply(result.text, isFinal: result.isFinal) }
            }
        } catch {
            #if DEBUG
            print("VoiceRecorder lane failed:", error)
            #endif
        }
    }

    private func publish() {
        english = lanes.first(where: \.isEnglish)?.text ?? english
        native = lanes.first(where: { !$0.isEnglish })?.text ?? native
    }

    /// 新机型用 SpeechTranscriber；不支持的设备退回 DictationTranscriber
    private static func module(for locale: Locale) async -> (any SpeechModule)? {
        if SpeechTranscriber.isAvailable, let supported = await SpeechTranscriber.supportedLocale(equivalentTo: locale) {
            return SpeechTranscriber(locale: supported, preset: .progressiveTranscription)
        }
        if let supported = await DictationTranscriber.supportedLocale(equivalentTo: locale) {
            return DictationTranscriber(locale: supported, preset: .progressiveShortDictation)
        }
        return nil
    }

    /// 录音回调在音频线程上跑，单独放在 nonisolated 里，不碰主线程的状态
    nonisolated private static func tapBlock(
        converter: BufferConverter,
        inputs: [AsyncStream<AnalyzerInput>.Continuation],
        levels: AsyncStream<Float>.Continuation
    ) -> AVAudioNodeTapBlock {
        { buffer, _ in
            levels.yield(BufferConverter.level(of: buffer))
            guard let converted = converter.convert(buffer) else { return }
            for input in inputs { input.yield(AnalyzerInput(buffer: converted)) }
        }
    }
}

/// 麦克风的格式 → 识别器要的格式
nonisolated private final class BufferConverter: @unchecked Sendable {
    private let converter: AVAudioConverter?
    private let target: AVAudioFormat

    init?(from source: AVAudioFormat, to target: AVAudioFormat) {
        self.target = target
        if source == target {
            converter = nil
        } else {
            guard let converter = AVAudioConverter(from: source, to: target) else { return nil }
            converter.primeMethod = .none
            self.converter = converter
        }
    }

    func convert(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let converter else { return buffer }
        let ratio = target.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio + 1)
        guard let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return nil }
        var consumed = false
        var error: NSError?
        converter.convert(to: output, error: &error) { _, status in
            if consumed {
                status.pointee = .noDataNow
                return nil
            }
            consumed = true
            status.pointee = .haveData
            return buffer
        }
        return error == nil ? output : nil
    }

    static func level(of buffer: AVAudioPCMBuffer) -> Float {
        guard let samples = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return 0 }
        var sum: Float = 0
        for index in 0..<Int(buffer.frameLength) { sum += samples[index] * samples[index] }
        let rms = (sum / Float(buffer.frameLength)).squareRoot()
        // 说话一般在 0.01...0.3 之间，换成 0...1 好做动画
        return min(1, max(0, (20 * log10(max(rms, 1e-6)) + 50) / 40))
    }
}
