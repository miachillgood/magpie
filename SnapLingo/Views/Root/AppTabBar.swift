//
//  AppTabBar.swift
//  SnapLingo
//
//  底部导航：只有图标，中间是黑色快门（直接打开相机）。
//

import SwiftUI

struct AppTabBar: View {
    @Environment(AppCoordinator.self) private var coordinator

    private struct Item {
        var tab: AppTab
        var symbol: String
        var title: String
    }

    private let leading = [
        Item(tab: .home, symbol: "photo.on.rectangle.angled", title: "照片墙"),
        Item(tab: .review, symbol: "rectangle.on.rectangle.angled", title: "复习")
    ]
    private let trailing = [
        Item(tab: .words, symbol: "book.closed", title: "词库"),
        Item(tab: .me, symbol: "person", title: "我的")
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(leading, id: \.tab) { button(for: $0) }
            Color.clear.frame(width: 84)
            ForEach(trailing, id: \.tab) { button(for: $0) }
        }
        .frame(height: 64)
        .padding(.horizontal, 6)
        .glassEffect(.regular.tint(Theme.sheet.opacity(0.7)), in: .capsule)
        .shadow(color: .black.opacity(0.10), radius: 18, y: 8)
        .overlay { ShutterButton().offset(y: -8) }
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
        // 快门比导航条高出一截，这部分也要让出来，内容才不会被它挡住
        .padding(.top, 16)
        .sensoryFeedback(.selection, trigger: coordinator.selectedTab)
    }

    private func button(for item: Item) -> some View {
        let selected = coordinator.selectedTab == item.tab
        return Button {
            coordinator.selectedTab = item.tab
        } label: {
            Image(systemName: item.symbol)
                .symbolVariant(selected ? .fill : .none)
                .font(.system(size: 21, weight: .medium))
                .foregroundStyle(selected ? Theme.homeInk : Theme.homeMuted)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .top) {
                    if item.tab == .review && coordinator.reviewPending {
                        Circle()
                            .fill(Color(hex: 0xFF7A2F))
                            .frame(width: 9, height: 9)
                            .overlay(Circle().stroke(Theme.sheet, lineWidth: 2))
                            .offset(x: 11, y: 14)
                    }
                }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
        .accessibilityValue(item.tab == .review && coordinator.reviewPending ? "有待复习的词" : "")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// 快门：白色外圈 + 墨黑圆 + 黄色细环
private struct ShutterButton: View {
    @Environment(AppCoordinator.self) private var coordinator
    @State private var taps = 0

    var body: some View {
        Button {
            taps += 1
            coordinator.startScan()
        } label: {
            ZStack {
                Circle()
                    .fill(Theme.sheet)
                    .frame(width: 78, height: 78)
                    .shadow(color: .black.opacity(0.22), radius: 12, y: 8)
                Circle()
                    .fill(Theme.homeInk)
                    .frame(width: 64, height: 64)
                    .overlay(Circle().stroke(Theme.shutterRing, lineWidth: 3.5))
                Image(systemName: "camera")
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(Theme.cream)
            }
            .contentShape(.circle)
        }
        .buttonStyle(.pressable)
        .sensoryFeedback(.impact(weight: .medium), trigger: taps)
        .accessibilityLabel("拍一拍，扫描新场景")
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
