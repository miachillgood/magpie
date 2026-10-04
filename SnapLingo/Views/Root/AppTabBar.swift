//
//  AppTabBar.swift
//  SnapLingo
//
//  底部导航：场景 ·（快门）· 复习。
//  一整条 Liquid Glass 胶囊（和系统标签栏同一种玻璃），左右是两个标签。
//  正中间垫一块玻璃圆，比胶囊高出一点；两块玻璃放在同一个 GlassEffectContainer 里，
//  会融成一个连着的鼓包。蜡笔快门图（TabShutter）放在鼓包上。
//  「我的」在首页右上角的头像里。
//

import SwiftUI

struct AppTabBar: View {
    /// true：用系统的 Liquid Glass 标签栏 + 右边的圆形快门（系统标签栏没法把按钮放正中间）；
    /// false：用下面这条自己排的玻璃胶囊，快门在正中间
    static let usesSystemTabBar = false

    @Environment(AppCoordinator.self) private var coordinator

    private struct Item {
        var tab: AppTab
        var symbol: String
        var title: LocalizedStringKey
    }

    /// symbol 为空时用自己画的线条图标（系统的 photo 图标里山是实心的）
    private let home = Item(tab: .home, symbol: "", title: "场景")  // Tab bar: scenes / photo wall
    private let review = Item(tab: .review, symbol: "rectangle.on.rectangle.angled", title: "复习")

    private static let barHeight: CGFloat = 64
    /// 快门直径；底下那块玻璃圆比快门大一圈
    private static let shutterDiameter: CGFloat = 64
    private static let bumpDiameter: CGFloat = 76
    /// 快门和玻璃圆的圆心比胶囊中线高多少（决定凸出来多少）
    private static let lift: CGFloat = 8
    /// 玻璃圆顶比胶囊顶高出的部分
    private static var bumpOverhang: CGFloat { bumpDiameter / 2 + lift - barHeight / 2 }

    var body: some View {
        GlassEffectContainer(spacing: 20) {
            ZStack {
                HStack(spacing: 0) {
                    button(for: home)
                    // 给快门让出位置
                    Color.clear.frame(width: Self.bumpDiameter)
                    button(for: review)
                }
                .padding(.horizontal, 8)
                .frame(height: Self.barHeight)
                .glassEffect(.regular, in: .capsule)

                Color.clear
                    .frame(width: Self.bumpDiameter, height: Self.bumpDiameter)
                    .glassEffect(.regular, in: .circle)
                    .offset(y: -Self.lift)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        // 快门放在玻璃容器外面叠上去：放在里面会被玻璃一起渲染、变糊
        .overlay {
            ZStack {
                Image("TabShutter")
                    .resizable()
                    .scaledToFit()
                    .frame(width: Self.shutterDiameter, height: Self.shutterDiameter)
                    .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                ShutterButton(diameter: Self.shutterDiameter)
            }
            .offset(y: -Self.lift)
        }
        .accessibilityElement(children: .contain)
        // 鼓包比胶囊高出一截，这部分也要让出来
        .padding(.top, 8 + Self.bumpOverhang)
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
        .sensoryFeedback(.selection, trigger: coordinator.selectedTab)
    }

    private func button(for item: Item) -> some View {
        let selected = coordinator.selectedTab == item.tab
        let badge = item.tab == .review && coordinator.reviewPending
        return Button {
            withAnimation(.snappy(duration: 0.3)) { coordinator.selectedTab = item.tab }
        } label: {
            VStack(spacing: 4) {
                Group {
                    if item.symbol.isEmpty {
                        PictureIcon()
                            .stroke(style: StrokeStyle(lineWidth: selected ? 2.2 : 1.6, lineCap: .round, lineJoin: .round))
                            .frame(width: 25, height: 21)
                    } else {
                        Image(systemName: item.symbol)
                            // 选中用实心版，没选中用线条版
                            .environment(\.symbolVariants, selected ? .fill : .none)
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
            // 选中只靠颜色区分：墨色 / 浅灰
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
        .accessibilityValue(badge ? "有待复习的词" : "")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// 快门：TabShutter 图里已经画好了圆，这里只放一块透明的点击区域
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
                .frame(width: diameter + 8, height: diameter + 8)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .medium), trigger: taps)
        .accessibilityLabel("拍一拍，扫描新场景")
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
    @ViewBuilder
    func appTabBar() -> some View {
        if AppTabBar.usesSystemTabBar {
            self
        } else {
            safeAreaInset(edge: .bottom, spacing: 0) {
                AppTabBar()
            }
        }
    }

    /// 放在标签页最外层：整个标签页（包括详情页）都不显示系统标签栏
    @ViewBuilder
    func hidingSystemTabBar() -> some View {
        if AppTabBar.usesSystemTabBar {
            self
        } else {
            toolbarVisibility(.hidden, for: .tabBar)
        }
    }
}

/// 系统标签栏：往下滚时缩小
struct SystemTabBarChrome: ViewModifier {
    func body(content: Content) -> some View {
        if AppTabBar.usesSystemTabBar {
            content.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            content
        }
    }
}
