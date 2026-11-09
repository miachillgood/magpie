//
//  WatchHomeView.swift
//  MagpieWatch
//

import SwiftUI

/// 首页：今天还剩几个词
struct WatchHomeView: View {
    private var store = WatchStore.shared
    @State private var reviewing = false
    /// 「怎么说」：听写完的那句话
    @State private var sayRequest: SayRequest?

    private struct SayRequest: Identifiable, Hashable {
        let id = UUID()
        let text: String
    }

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
        .toolbar {
            // 右上角的麦克风：想说一句话不会说，点开系统听写，说完问 AI
            ToolbarItem(placement: .topBarTrailing) {
                TextFieldLink(prompt: Text("想说什么？")) {
                    Image(systemName: "mic.fill")
                        .foregroundStyle(.white)
                        .accessibilityLabel(Text("怎么说"))
                } onSubmit: { text in
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    sayRequest = SayRequest(text: trimmed)
                }
            }
        }
        .navigationDestination(isPresented: $reviewing) {
            WatchReviewView(cards: store.remaining)
        }
        .navigationDestination(item: $sayRequest) { request in
            WatchPhrasingView(request: request.text)
        }
        #if DEBUG
        // 模拟器上没法听写中文：-watchSay "我想让店员帮我加热一下" 直接打开「怎么说」
        .task {
            let arguments = ProcessInfo.processInfo.arguments
            if let index = arguments.firstIndex(of: "-watchSay"), arguments.indices.contains(index + 1) {
                sayRequest = SayRequest(text: arguments[index + 1])
            }
        }
        #endif
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
