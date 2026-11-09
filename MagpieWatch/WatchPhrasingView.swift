//
//  WatchPhrasingView.swift
//  MagpieWatch
//
//  手表上的「怎么说」：用系统听写说出想表达的意思，手表自己联网问 AI，
//  给 2–3 种地道说法，能听、能交给手机加入复习。手机不在身边也能用（加入复习会排队，连上手机再加）。
//

import SwiftUI

struct WatchPhrasingView: View {
    var request: String

    @State private var phase: Phase = .loading
    @State private var added: Set<String> = []

    private enum Phase {
        case loading
        case loaded(PhrasingResult)
        case failed(LocalizedStringKey)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text(verbatim: request)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)

                switch phase {
                case .loading:
                    HStack(spacing: 6) {
                        ProgressView()
                            .frame(width: 20)
                        Text("正在想怎么说…")
                            .font(.footnote)
                    }
                    .padding(.top, 6)
                case .failed(let message):
                    Text(message)
                        .font(.footnote)
                        .padding(.top, 6)
                    Button("重试") { Task { await load() } }
                case .loaded(let result):
                    ForEach(result.phrasings) { phrasing in
                        card(phrasing, situation: result.situation)
                    }
                }
            }
        }
        .navigationTitle("怎么说")
        .sensoryFeedback(.success, trigger: added.count)
        .task { await load() }
    }

    private func card(_ phrasing: Phrasing, situation: String) -> some View {
        let isAdded = added.contains(phrasing.id)
        return VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: phrasing.text)
                .font(.system(.body, design: .serif, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
            if !phrasing.translation.isEmpty {
                Text(verbatim: phrasing.translation)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                Button {
                    WatchSpeech.speak(phrasing.text)
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                }
                .accessibilityLabel(Text("朗读"))
                Button {
                    WatchStore.shared.addPhrase(phrasing, situation: situation)
                    withAnimation(.snappy) { _ = added.insert(phrasing.id) }
                } label: {
                    Image(systemName: isAdded ? "checkmark" : "plus")
                }
                .disabled(isAdded)
                .accessibilityLabel(isAdded ? Text("已加入复习") : Text("加入复习"))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .padding(.top, 2)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.1), in: .rect(cornerRadius: 16, style: .continuous))
    }

    private func load() async {
        let snapshot = WatchStore.shared.snapshot
        guard snapshot?.aiAllowed == true else {
            phase = .failed("先在 iPhone 上的 Magpie 打开 AI 功能")
            return
        }
        phase = .loading
        do {
            let result = try await PhrasingClient.suggest(
                for: request,
                nativeName: snapshot?.nativeName ?? "Simplified Chinese",
                apiKey: APIConfig.claudeAPIKey
            )
            withAnimation(.snappy) { phase = .loaded(result) }
        } catch is CancellationError {
            // 页面关掉了
        } catch PhrasingClient.Failure.network {
            phase = .failed("连不上网络，稍后再试")
        } catch {
            phase = .failed("没想出来，换个说法试试？")
        }
    }
}
