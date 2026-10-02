//
//  AppTabBar.swift
//  SnapLingo
//
//  底部导航：场景 ·（快门）· 复习。
//  底条（TabBar）和快门（TabShutter）是两张设计好的图，按钮叠在上面。
//  「我的」在首页右上角的头像里。
//

import SwiftUI

struct AppTabBar: View {
    @Environment(AppCoordinator.self) private var coordinator

    private struct Item {
        var tab: AppTab
        var symbol: String
        var title: LocalizedStringKey
    }

    /// symbol 为空时用自己画的线条图标（系统的 photo 图标里山是实心的）
    private let home = Item(tab: .home, symbol: "", title: "场景")  // Tab bar: scenes / photo wall
    private let review = Item(tab: .review, symbol: "rectangle.on.rectangle.angled", title: "复习")

    /// 两张图的宽高比
    private static let barAspect: CGFloat = 1891.0 / 463.0
    private static let shutterAspect: CGFloat = 864.0 / 778.0
    /// 快门图里黑色圆的位置和直径（相对快门图的宽高）；黄色色块是偏的，要按圆心对齐
    private static let circleInShutter = CGPoint(x: 0.4711, y: 0.5495)
    private static let circleDiameter: CGFloat = 0.6667
    /// 快门占底条宽度的比例，以及黑色圆圆心在底条上的高度（相对底条高度）
    private static let shutterWidth: CGFloat = 0.25
    private static let circleCenterY: CGFloat = 0.46

    var body: some View {
        Image("TabBar")
            .resizable()
            .aspectRatio(Self.barAspect, contentMode: .fit)
            // 图是透明底的，阴影沿着底条的形状走：贴边一圈细阴影 + 四周一圈明显的柔光，让底条浮在内容上面
            .shadow(color: .black.opacity(0.10), radius: 2, y: 1)
            .shadow(color: .black.opacity(0.18), radius: 16, y: 6)
            .overlay {
                GeometryReader { proxy in
                    let size = proxy.size
                    let shutterW = size.width * Self.shutterWidth
                    let shutterH = shutterW / Self.shutterAspect
                    let circle = CGPoint(x: size.width / 2, y: size.height * Self.circleCenterY)

                    button(for: home)
                        .frame(width: size.width * 0.3, height: size.height * 0.62)
                        .position(x: size.width * 0.19, y: size.height * 0.62)
                    button(for: review)
                        .frame(width: size.width * 0.3, height: size.height * 0.62)
                        .position(x: size.width * 0.81, y: size.height * 0.62)

                    Image("TabShutter")
                        .resizable()
                        .frame(width: shutterW, height: shutterH)
                        .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                        .position(
                            x: circle.x + (0.5 - Self.circleInShutter.x) * shutterW,
                            y: circle.y + (0.5 - Self.circleInShutter.y) * shutterH
                        )
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                    ShutterButton(diameter: shutterW * Self.circleDiameter)
                        .position(circle)
                    SnapLabel()
                        .position(x: size.width * 0.7, y: size.height * 0.02)
                }
            }
            .accessibilityElement(children: .contain)
            // 底条是一张奶油色的图，深色模式下也是浅色，上面的文字和图标固定用浅色模式的颜色
            .environment(\.colorScheme, .light)
            // 快门和「Snap!」比底条高出一截，这部分也要让出来
            .padding(.top, 20)
            .padding(.horizontal, 16)
            .padding(.bottom, 6)
            .sensoryFeedback(.selection, trigger: coordinator.selectedTab)
    }

    private func button(for item: Item) -> some View {
        let selected = coordinator.selectedTab == item.tab
        let badge = item.tab == .review && coordinator.reviewPending
        return Button {
            coordinator.selectedTab = item.tab
        } label: {
            VStack(spacing: 4) {
                Group {
                    if item.symbol.isEmpty {
                        PictureIcon()
                            .stroke(style: StrokeStyle(lineWidth: selected ? 2 : 1.6, lineCap: .round, lineJoin: .round))
                            .frame(width: 25, height: 21)
                    } else {
                        Image(systemName: item.symbol)
                            // 系统在导航里会自动换成实心图标，这里固定用线条版
                            .environment(\.symbolVariants, .none)
                            .font(.system(size: 21, weight: selected ? .semibold : .regular))
                    }
                }
                .frame(height: 26)
                    .overlay(alignment: .topTrailing) {
                        if badge {
                            Circle()
                                .fill(Theme.brand)
                                .frame(width: 9, height: 9)
                                .overlay(Circle().stroke(Theme.cream, lineWidth: 2))
                                .offset(x: 5, y: -2)
                        }
                    }
                Text(item.title)
                    .font(.system(size: 12, weight: selected ? .semibold : .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(selected ? Theme.homeInk : Theme.homeMuted)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
        .accessibilityValue(badge ? "有待复习的词" : "")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// 快门：TabShutter 图里已经画好了黑色圆，这里只放一块透明的点击区域
private struct ShutterButton: View {
    var diameter: CGFloat
    @Environment(AppCoordinator.self) private var coordinator
    @State private var taps = 0

    var body: some View {
        Button {
            taps += 1
            coordinator.startScan()
        } label: {
            Circle()
                .fill(.clear)
                .frame(width: diameter + 12, height: diameter + 12)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .medium), trigger: taps)
        .accessibilityLabel("拍一拍，扫描新场景")
    }
}

/// 快门右上方的三笔闪光线和手写「Snap!」
private struct SnapLabel: View {
    var body: some View {
        HStack(alignment: .top, spacing: 2) {
            SparkleLines()
                .stroke(Theme.homeInk, style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                .frame(width: 20, height: 20)
                .rotationEffect(.degrees(20))
            HandwrittenLabel(text: "Snap!", size: 20, revealed: true)
                .offset(y: 12)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// 线条画的照片图标：圆角框 + 太阳 + 两座山
private struct PictureIcon: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * w, y: rect.minY + y * h) }
        var path = Path(roundedRect: rect, cornerRadius: min(w, h) * 0.2, style: .continuous)
        path.addEllipse(in: CGRect(x: rect.minX + w * 0.2, y: rect.minY + h * 0.2, width: w * 0.16, height: w * 0.16))
        path.move(to: p(0.06, 0.86))
        path.addLine(to: p(0.38, 0.5))
        path.addLine(to: p(0.58, 0.72))
        path.addLine(to: p(0.72, 0.56))
        path.addLine(to: p(0.94, 0.82))
        return path
    }
}

extension View {
    /// 放在每个标签页 NavigationStack 的根页面上（放在 NavigationStack 外面时，
    /// 让出的空间传不进去，列表最后几行会被导航挡住）。进入详情页时导航随之隐藏
    func appTabBar() -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            AppTabBar()
        }
    }

    /// 放在标签页最外层：整个标签页（包括详情页）都不显示系统标签栏
    func hidingSystemTabBar() -> some View {
        toolbarVisibility(.hidden, for: .tabBar)
    }
}
