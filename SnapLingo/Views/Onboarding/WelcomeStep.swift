//
//  WelcomeStep.swift
//  SnapLingo
//
//  第一次打开：暖沙斑点底，一块公交站牌「照片」套在取景框里，单词像是自己从照片上跳出来。
//  出场顺序：照片落下 → 单词贴纸弹出 → 闪光线 → 手写字写出来 → 荧光笔划过。
//

import SwiftUI

struct WelcomeStep: View {
    var onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < 700
            VStack(alignment: .leading, spacing: 0) {
                MagpieWordmark()
                    .padding(.top, 6)

                WelcomePhoto(appeared: appeared, reduceMotion: reduceMotion)
                    .frame(height: min(proxy.size.height * (compact ? 0.38 : 0.46), 410))
                    .frame(maxWidth: .infinity)
                    .padding(.top, compact ? 6 : 16)

                // 手写的品牌口号，所有语言都保留英文
                HandwrittenLabel(text: "See it. Snap it. Learn it.", size: compact ? 23 : 27, revealed: appeared)
                    .rotationEffect(.degrees(-3), anchor: .leading)
                    .padding(.top, compact ? 4 : 12)
                    .animation(motion(.easeOut(duration: 0.7), delay: 1.0), value: appeared)
                    .accessibilityHidden(true)

                headline(size: compact ? 28 : 34)
                    .padding(.top, compact ? 6 : 10)

                Text("只挑适合你水平的词，释义和例句用你的母语写，每天复习几分钟就好。")
                    .font(.system(size: compact ? 15 : 16))
                    .foregroundStyle(Theme.homeMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
                    .opacity(appeared ? 1 : 0)
                    .animation(motion(.smooth(duration: 0.5), delay: 0.5), value: appeared)

                Spacer(minLength: 14)

                PrimaryButton(title: "开始", trailingSymbol: "arrow.right", action: onContinue)
                Text("不用注册，打开就能用")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.homeMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
        .background {
            SpeckleBackground(base: HomeTheme.sand.base)
                .ignoresSafeArea()
        }
        .onAppear {
            guard !appeared else { return }
            if reduceMotion {
                appeared = true
            } else {
                Task {
                    try? await Task.sleep(for: .milliseconds(80))
                    appeared = true
                }
            }
        }
    }

    private func motion(_ animation: Animation, delay: Double) -> Animation? {
        reduceMotion ? nil : animation.delay(delay)
    }

    private func headline(size: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("对着英文拍一张")
                .fixedSize(horizontal: false, vertical: true)
            MarkedPhrase(
                text: String(localized: "词会自己**跳出来**", comment: "Welcome headline, line 2. The part between ** gets a yellow highlighter"),
                size: size,
                drawn: appeared,
                reduceMotion: reduceMotion
            )
        }
        .font(.system(size: size, weight: .heavy))
        .foregroundStyle(Theme.homeInk)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .animation(motion(.smooth(duration: 0.5), delay: 0.35), value: appeared)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - 荧光笔句子

/// 一句话里用 ** 标出的部分划上荧光笔；一行放不下时拆成两行
private struct MarkedPhrase: View {
    var text: String
    var size: CGFloat
    var drawn: Bool
    var reduceMotion: Bool

    private var pieces: [HeadlinePiece] { HeadlinePiece.phrase(text) }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            ForEach([1, 0.88, 0.78], id: \.self) { factor in
                HStack(spacing: size * 0.18 * factor) { segments(size * factor) }
            }
            VStack(alignment: .leading, spacing: 2) { segments(size) }
        }
    }

    @ViewBuilder private func segments(_ size: CGFloat) -> some View {
        ForEach(Array(pieces.enumerated()), id: \.offset) { _, piece in
            if case .marker(let marked) = piece {
                Text(marked)
                    .font(.system(size: size, weight: .heavy))
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .background {
                        MarkerHighlight(drawn: drawn, cornerScale: 0.7)
                            .padding(.top, size * 0.34)
                            .animation(reduceMotion ? nil : .easeOut(duration: 0.5).delay(1.2), value: drawn)
                    }
                    .fixedSize()
            } else {
                Text(piece.plainText)
                    .font(.system(size: size, weight: .heavy))
                    .lineLimit(1)
                    .fixedSize()
            }
        }
    }
}

// MARK: - 照片 + 取景框 + 单词贴纸

private struct WelcomePhoto: View {
    var appeared: Bool
    var reduceMotion: Bool

    var body: some View {
        GeometryReader { geo in
            let height = geo.size.height
            let photoHeight = height - 44
            let photoWidth = min(geo.size.width - 72, photoHeight * 0.92)
            ZStack {
                ViewfinderCorners(length: 30, radius: 14)
                    .stroke(Theme.homeInk, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: photoWidth + 56, height: height)
                    .opacity(appeared ? 1 : 0)
                    .animation(motion(.easeOut(duration: 0.4), delay: 0.1), value: appeared)

                BusStopSign(appeared: appeared, reduceMotion: reduceMotion)
                    .frame(width: photoWidth, height: photoHeight)
                    .clipShape(.rect(cornerRadius: 15, style: .continuous))
                    .padding(7)
                    .background(Theme.sheet, in: .rect(cornerRadius: 21, style: .continuous))
                    .shadow(color: .black.opacity(0.16), radius: 15, y: 12)
                    .rotationEffect(.degrees(appeared ? -3 : 6))
                    .offset(y: appeared ? 0 : 30)
                    .opacity(appeared ? 1 : 0)
                    .animation(motion(.spring(response: 0.8, dampingFraction: 0.72), delay: 0.15), value: appeared)

                SparkleLines()
                    .trim(from: 0, to: appeared ? 1 : 0)
                    .stroke(Color(hex: 0xF2B928), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 30, height: 30)
                    .offset(x: photoWidth / 2 + 8, y: -photoHeight * 0.34)
                    .animation(motion(.easeOut(duration: 0.4), delay: 0.95), value: appeared)
            }
            .frame(width: geo.size.width, height: height)
        }
        .accessibilityElement()
        .accessibilityLabel(Text("拍下一块公交站牌，单词 tap on、departure、signal 被挑了出来"))
    }

    private func motion(_ animation: Animation, delay: Double) -> Animation? {
        reduceMotion ? nil : animation.delay(delay)
    }
}

/// 欢迎页上的「照片」：一块公交站牌，文字和示例数据里的公交站场景一样。
/// 每行下面挂着从这一行里挑出来的词。用代码画，所有设备上都清楚，也不用担心图片版权
private struct BusStopSign: View {
    var appeared: Bool
    var reduceMotion: Bool

    private struct Row {
        var text: String
        var word: String
        var gloss: String
        var highlighted = false
        var rotation: Double
    }

    private var rows: [Row] {
        [
            Row(text: "Tap on with your HOP card", word: "tap on",
                gloss: String(localized: "上车刷卡", comment: "Meaning of 'tap on' (tap your bus card)"), rotation: -2),
            Row(text: "Next departure  8:15", word: "departure",
                gloss: String(localized: "出发", comment: "Meaning of 'departure' (a bus leaving)"), highlighted: true, rotation: 2),
            Row(text: "Request stop: signal driver", word: "signal",
                gloss: String(localized: "示意", comment: "Meaning of 'signal' (signal the driver to stop)"), rotation: -1.5)
        ]
    }

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width / 270, geo.size.height / 300)
            ZStack(alignment: .topLeading) {
                LinearGradient(
                    colors: [Color(red: 0.05, green: 0.25, blue: 0.45), Color(red: 0.06, green: 0.37, blue: 0.62)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 9 * s) {
                        Image(systemName: "bus.fill")
                            .font(.system(size: 18 * s, weight: .bold))
                            .frame(width: 34 * s, height: 34 * s)
                            .background(.white.opacity(0.18), in: .rect(cornerRadius: 9 * s, style: .continuous))
                        Text(verbatim: "BUS STOP 7012")
                            .font(.system(size: 22 * s, weight: .heavy))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    Rectangle()
                        .fill(.white.opacity(0.35))
                        .frame(height: 2 * s)
                        .padding(.top, 12 * s)
                        .padding(.bottom, 14 * s)
                    VStack(alignment: .leading, spacing: 12 * s) {
                        ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                            VStack(alignment: .leading, spacing: 5 * s) {
                                Text(verbatim: row.text)
                                    .font(.system(size: 15 * s, weight: .semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                WordSticker(word: row.word, gloss: row.gloss, compact: s < 0.95, highlighted: row.highlighted)
                                    .rotationEffect(.degrees(row.rotation))
                                    .padding(.leading, CGFloat(index) * 14 * s + 18 * s)
                                    .scaleEffect(appeared ? 1 : 0.5, anchor: .leading)
                                    .opacity(appeared ? 1 : 0)
                                    .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.6).delay(0.6 + 0.1 * Double(index)), value: appeared)
                            }
                        }
                    }
                }
                .foregroundStyle(.white)
                .padding(20 * s)
            }
        }
        .accessibilityHidden(true)
    }
}
