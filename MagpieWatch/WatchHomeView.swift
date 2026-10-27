//
//  WatchHomeView.swift
//  MagpieWatch
//

import SwiftUI

/// 首页：今天还剩几个词
struct WatchHomeView: View {
    private var store = WatchStore.shared
    @State private var reviewing = false

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                if !store.hasTodaysPlan {
                    message(symbol: "iphone", text: "打开 iPhone 上的 Magpie 同步今天的词")
                } else if store.remaining.isEmpty {
                    message(symbol: "checkmark.seal.fill", text: "今天的词都复习完了")
                } else {
                    Text("今天")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(verbatim: "\(store.remaining.count)")
                        .font(.system(size: 52, weight: .heavy, design: .rounded))
                        .contentTransition(.numericText())
                    Text("个词")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button("开始") { reviewing = true }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Magpie")
        .navigationDestination(isPresented: $reviewing) {
            WatchReviewView(cards: store.remaining)
        }
    }

    private func message(symbol: String, text: LocalizedStringKey) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(.tint)
            Text(text)
                .font(.footnote)
                .multilineTextAlignment(.center)
        }
    }
}
