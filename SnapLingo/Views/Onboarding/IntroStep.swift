//
//  IntroStep.swift
//  SnapLingo
//
//  欢迎页之后的介绍页：黄色底，手写标题「Collect English as you go.」，
//  下面是一整张插画（撕边的咖啡店照片、菜单牌、喜鹊，自带黄色底），
//  两个单词气泡对应菜单上被框出来的词。
//  出场顺序：标题写出来 → 插画淡入 → 一道光从上往下扫过照片，扫到哪个词就框出哪个词 → 气泡 → 底部的话和按钮。
//

import SwiftUI

struct IntroStep: View {
    var onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    /// 和插画自带的黄色一致
    private static let paper = Color(UIColor(hex: 0xFEE06F))

    var body: some View {
        GeometryReader { proxy in
            let scale = proxy.size.width / 390
            let compact = proxy.size.height < 760
            // 插画按屏幕宽铺满；它自带上下的黄底，所以照片那一段（插画高度的 19%–79%）放在标题和底部文字之间。
            // 矮屏幕放不下时整张缩小，照片段刚好填满中间
            let titleBottom: CGFloat = (compact ? 118 : 168) * scale
            let footer: CGFloat = compact ? 150 : 176
            let band = max(proxy.size.height - titleBottom - footer, 200)
            let width = min(proxy.size.width, band / MenuPicture.photoBand * MenuPicture.aspect)
            let height = width / MenuPicture.aspect
            ZStack(alignment: .top) {
                MenuPicture(width: width, appeared: appeared, reduceMotion: reduceMotion)
                    .offset(y: titleBottom - height * MenuPicture.photoTop)
                    .frame(maxWidth: .infinity)

                title(scale: scale)
                    .padding(.top, compact ? 8 : 28)

                VStack(spacing: compact ? 14 : 22) {
                    Spacer()
                    // 和标题一样，所有语言都用英文
                    Text(verbatim: "Spot something you don't know?\nSnap it.")
                        .font(.custom("ChalkboardSE-Regular", size: 21 * min(scale, 1.1)))
                        .foregroundStyle(Theme.homeInk)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 24)
                        .modifier(Entrance(appeared: appeared, delay: MenuPicture.footerDelay, reduceMotion: reduceMotion))

                    PrimaryButton(title: "继续", trailingSymbol: "arrow.right", action: onContinue)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 8)
                        .modifier(Entrance(appeared: appeared, delay: MenuPicture.footerDelay + 0.1, reduceMotion: reduceMotion))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
        }
        .background(Self.paper.ignoresSafeArea())
        // 插画是固定配色，深色模式下也保持黄色底
        .environment(\.colorScheme, .light)
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

    /// 和水平测试结果页一样，手写标题所有语言都用英文
    private func title(scale: CGFloat) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Text(verbatim: "Collect English\nas you go.")
                .font(.custom("ChalkboardSE-Bold", size: 42 * scale))
                .foregroundStyle(Theme.homeInk)
                .lineSpacing(-4)
                .fixedSize()
                .mask(alignment: .leading) {
                    Rectangle().scaleEffect(x: appeared ? 1 : 0.001, anchor: .leading)
                }
                .animation(reduceMotion ? nil : .easeOut(duration: 0.8).delay(0.1), value: appeared)
            SparkleLines()
                .trim(from: 0, to: appeared ? 1 : 0)
                .stroke(Theme.homeInk, style: StrokeStyle(lineWidth: 3 * scale, lineCap: .round))
                .frame(width: 30 * scale, height: 30 * scale)
                .offset(x: -6 * scale, y: -14 * scale)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.4).delay(0.9), value: appeared)
                .accessibilityHidden(true)
        }
        .rotationEffect(.degrees(-7))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 30 * scale)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "Collect English as you go."))
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - 插画

/// 一整张插画：撕边的咖啡店照片、菜单牌和喜鹊。气泡和框按插画的比例定位（0...1），任何屏幕上都对得上
private struct MenuPicture: View {
    var width: CGFloat
    var appeared: Bool
    var reduceMotion: Bool

    /// 原图 950 × 1656
    static let aspect: CGFloat = 950 / 1656
    /// 照片（撕边那一段）从插画的哪里开始、占多高
    static let photoTop: CGFloat = 0.19
    static let photoBand: CGFloat = 0.6

    /// 扫描光什么时候开始、扫一遍多久（秒）；框、气泡、底部按钮都按这两个数排
    static let scanStart: Double = 1.0
    static let scanDuration: Double = 1.3
    static var scanEnd: Double { scanStart + scanDuration }
    static var footerDelay: Double { scanEnd + 0.5 }

    /// 光扫到插画高度 y（0...1）那一刻
    static func scanTime(at y: CGFloat) -> Double {
        scanStart + Double((y - photoTop) / photoBand) * scanDuration
    }

    private struct Word {
        var x, y, width, height: CGFloat
        var angle: Double
    }

    /// 菜单上被“认出来”的两个词（插画的比例）
    private static let flatWhite = Word(x: 0.442, y: 0.425, width: 0.2, height: 0.031, angle: -1)
    private static let sourdough = Word(x: 0.428, y: 0.584, width: 0.31, height: 0.037, angle: 2.5)

    /// 扫到一个词就轻轻震一下
    @State private var found = 0

    private var height: CGFloat { width / Self.aspect }
    /// 按设计稿 390 宽缩放气泡里的字
    private var scale: CGFloat { width / 390 }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Image("IntroMenu")
                .resizable()
                .frame(width: width, height: height)
                .scaleEffect(appeared ? 1 : 1.04)
                .opacity(appeared ? 1 : 0)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.8).delay(0.2), value: appeared)

            if !reduceMotion {
                ScanBeam(width: width, height: height, appeared: appeared, scale: scale)
            }

            highlight(Self.flatWhite)
            highlight(Self.sourdough)

            // 扫完再出气泡
            WordBubble(word: "flat white", gloss: "a milky coffee", scale: scale)
                .offset(x: 0.03 * width, y: 0.385 * height)
                .modifier(Pop(appeared: appeared, delay: Self.scanEnd + 0.1, reduceMotion: reduceMotion))

            WordBubble(word: "sourdough", gloss: "slow-fermented bread", scale: scale)
                .offset(x: 0.015 * width, y: 0.47 * height)
                .modifier(Pop(appeared: appeared, delay: Self.scanEnd + 0.22, reduceMotion: reduceMotion))
        }
        .frame(width: width, height: height, alignment: .topLeading)
        .sensoryFeedback(.selection, trigger: found)
        .onChange(of: appeared, initial: true) { _, isOn in
            guard isOn, !reduceMotion, found == 0 else { return }
            Task {
                var elapsed = 0.0
                for word in [Self.flatWhite, Self.sourdough] {
                    let at = Self.scanTime(at: word.y + word.height / 2)
                    try? await Task.sleep(for: .seconds(at - elapsed))
                    elapsed = at
                    found += 1
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "flat white, sourdough"))
    }

    private static let orange = Color(UIColor(hex: 0xF5A524))

    /// 菜单上那个词外面的橙色圆角框：光扫到这个词的那一刻，先大一圈带点光晕，再弹回原大小
    private func highlight(_ word: Word) -> some View {
        RoundedRectangle(cornerRadius: 6 * scale, style: .continuous)
            .stroke(Self.orange, lineWidth: 2.4 * scale)
            .shadow(color: Self.orange.opacity(0.7), radius: 5 * scale)
            .frame(width: word.width * width, height: word.height * height)
            .rotationEffect(.degrees(word.angle))
            .scaleEffect(appeared ? 1 : 1.35)
            .opacity(appeared ? 1 : 0)
            .animation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.55).delay(Self.scanTime(at: word.y + word.height / 2)), value: appeared)
            .offset(x: word.x * width, y: word.y * height)
    }

}

/// 扫描光：一条暖白色的亮线，上面拖一段往上渐隐的光，从照片上沿匀速扫到下沿，只扫一遍。
/// 和真实扫描页（ScanProcessingView 的 ScanSweep）同一个品牌色，只在照片那一段里出现
private struct ScanBeam: View {
    var width: CGFloat
    var height: CGFloat
    var appeared: Bool
    var scale: CGFloat

    private struct Phase {
        var y: CGFloat = MenuPicture.photoTop
        var opacity: Double = 0
    }

    var body: some View {
        let trail = 64 * scale
        VStack(spacing: 0) {
            LinearGradient(colors: [.clear, Theme.brand.opacity(0.25), Color.white.opacity(0.55)], startPoint: .top, endPoint: .bottom)
                .frame(height: trail)
            Capsule()
                .fill(Color.white)
                .frame(height: 2.5 * scale)
                .shadow(color: Theme.brand.opacity(0.9), radius: 6 * scale)
                .shadow(color: .white, radius: 2 * scale)
        }
        .frame(width: width)
        .blendMode(.screen)
        .keyframeAnimator(initialValue: Phase(), trigger: appeared) { content, phase in
            content
                .offset(y: phase.y * height - trail)
                .opacity(phase.opacity)
        } keyframes: { _ in
            KeyframeTrack(\.y) {
                LinearKeyframe(MenuPicture.photoTop, duration: MenuPicture.scanStart)
                LinearKeyframe(MenuPicture.photoTop + MenuPicture.photoBand, duration: MenuPicture.scanDuration)
            }
            KeyframeTrack(\.opacity) {
                LinearKeyframe(0, duration: MenuPicture.scanStart)
                LinearKeyframe(1, duration: 0.15)
                LinearKeyframe(1, duration: MenuPicture.scanDuration - 0.4)
                LinearKeyframe(0, duration: 0.25)
            }
        }
        .frame(width: width, height: height, alignment: .topLeading)
        // 只在照片那一段里扫，不扫到上下的黄底
        .mask(alignment: .top) {
            Rectangle()
                .frame(height: MenuPicture.photoBand * height)
                .offset(y: MenuPicture.photoTop * height)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// 白色单词气泡：英文词 + 一行英文解释
private struct WordBubble: View {
    var word: String
    var gloss: String
    var scale: CGFloat

    var body: some View {
        VStack(spacing: 2 * scale) {
            Text(verbatim: word)
                .font(.system(size: 16 * scale, weight: .bold))
            Text(verbatim: gloss)
                .font(.system(size: 10.5 * scale, weight: .medium))
                .foregroundStyle(Theme.homeInk.opacity(0.75))
        }
        .foregroundStyle(Theme.homeInk)
        .fixedSize()
        .padding(.horizontal, 12 * scale)
        .padding(.vertical, 8 * scale)
        .background(Color.white, in: .rect(cornerRadius: 18 * scale, style: .continuous))
        .shadow(color: .black.opacity(0.16), radius: 10 * scale, y: 5 * scale)
    }
}

private struct Pop: ViewModifier {
    var appeared: Bool
    var delay: Double
    var reduceMotion: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(appeared ? 1 : 0.6)
            .opacity(appeared ? 1 : 0)
            .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.62).delay(delay), value: appeared)
    }
}

