//
//  DayDetailSheet.swift
//  SnapLingo
//

import SwiftUI

struct DayDetailSheet: View {
    let date: Date
    let sessions: [ScanSession]

    private var totalWords: Int { sessions.reduce(0) { $0 + $1.wordCount } }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 EEEE"
        return f
    }()

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    ContentUnavailableView(
                        "这天没有添加词汇",
                        systemImage: "calendar.badge.minus",
                        description: Text("试试扫描一张图片来添加新词汇")
                    )
                } else {
                    scrollContent
                }
            }
            .navigationTitle(Self.dateFormatter.string(from: date))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        Text(Self.dateFormatter.string(from: date))
                            .font(.headline)
                        Text("\(totalWords) 个词")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var scrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(sessions) { session in
                    sessionCard(session)
                }
            }
            .padding()
        }
    }

    private func sessionCard(_ session: ScanSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // 分类 badge
            Label(session.categoryName, systemImage: session.words.first?.sceneTag.icon ?? "tag")
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.accentColor.opacity(0.1), in: Capsule())
                .foregroundStyle(Color.accentColor)

            // 源图
            if let data = session.thumbnail, let img = UIImage(data: data) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            // 词汇胶囊
            FlowLayout(spacing: 8) {
                ForEach(session.words) { vocabWord in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(vocabWord.word)
                            .font(.subheadline.weight(.medium))
                        Text(vocabWord.chineseExplanation)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}
