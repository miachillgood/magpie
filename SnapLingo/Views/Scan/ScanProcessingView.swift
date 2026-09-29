//
//  ScanProcessingView.swift
//  SnapLingo
//

import SwiftUI
import SwiftData

/// 识别中：照片上有一道扫光，下方显示进度
struct ScanProcessingView: View {
    let image: UIImage
    var onFinished: (WordLibrary.ScanDraft) -> Void
    var onRetake: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var step: Step = .reading
    @State private var errorMessage: String?

    private enum Step {
        case reading
        case choosing

        var title: String {
            switch self {
            case .reading:  "正在识别文字…"
            case .choosing: "正在挑选适合你的词…"
            }
        }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .overlay { if errorMessage == nil { ScanSweep() } }
                .clipShape(.rect(cornerRadius: Radius.hero, style: .continuous))
                .padding(Spacing.md)
                .opacity(errorMessage == nil ? 1 : 0.4)
        }
        .overlay(alignment: .bottom) {
            Group {
                if let errorMessage {
                    VStack(spacing: Spacing.md) {
                        Label(errorMessage, systemImage: "text.magnifyingglass")
                            .font(.subheadline.weight(.medium))
                            .multilineTextAlignment(.center)
                        Button {
                            onRetake()
                        } label: {
                            Label("重新拍", systemImage: "arrow.counterclockwise")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.glassProminent)
                        .controlSize(.large)
                    }
                    .padding(Spacing.lg)
                    .glassEffect(.regular, in: .rect(cornerRadius: Radius.hero, style: .continuous))
                } else {
                    HStack(spacing: Spacing.sm) {
                        ProgressView()
                        Text(step.title)
                            .font(.subheadline.weight(.semibold))
                            .contentTransition(.opacity)
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.sm)
                    .glassEffect(.regular, in: .capsule)
                    .animation(.smooth, value: step)
                }
            }
            .padding(Spacing.lg)
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("关闭", systemImage: "xmark") { dismiss() }
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .environment(\.colorScheme, .dark)
        .statusBarHidden()
        .sensoryFeedback(.error, trigger: errorMessage) { _, new in new != nil }
        .task { await run() }
    }

    private func run() async {
        let normalized = ImageUtilities.normalized(image)
        guard let cgImage = normalized.cgImage else {
            errorMessage = OCRError.imageConversionFailed.errorDescription
            return
        }

        let ocr: OCRResult
        do {
            ocr = try await OCRService.recognize(cgImage)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "文字识别失败，请重试"
            return
        }

        step = .choosing
        let level = UserSettings.current(in: context).level
        var draft = WordLibrary.ScanDraft(image: normalized, ocr: ocr, extraction: nil)
        do {
            draft.extraction = try await ClaudeAPIService.shared.extractWords(from: ocr.fullText, level: level)
        } catch is CancellationError {
            return
        } catch {
            draft.aiError = (error as? LocalizedError)?.errorDescription ?? "AI 推荐暂时不可用"
        }
        onFinished(draft)
    }
}

/// 扫光动画
private struct ScanSweep: View {
    @State private var phase: CGFloat = -0.2

    var body: some View {
        GeometryReader { proxy in
            LinearGradient(
                colors: [.clear, Theme.brand.opacity(0.35), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: proxy.size.height * 0.22)
            .offset(y: proxy.size.height * phase)
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                phase = 1.0
            }
        }
    }
}
