//
//  VocabWordRowView.swift
//  SnapLingo
//

import SwiftUI

struct VocabWordRowView: View {
    let word: VocabWord

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // 缩略图
            thumbnailView

            // 文字内容
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(word.word)
                        .font(.headline)
                    if word.isMastered {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
                Text(word.chineseExplanation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // 右侧状态
            VStack(alignment: .trailing, spacing: 4) {
                Label(word.sceneTag.rawValue, systemImage: word.sceneTag.icon)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.tint)

                reviewBadge
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let data = word.sourceImageThumbnail,
           let uiImg = UIImage(data: data) {
            Image(uiImage: uiImg)
                .resizable()
                .scaledToFill()
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.15))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: "text.viewfinder")
                        .foregroundStyle(.secondary)
                )
        }
    }

    private var reviewBadge: some View {
        let due = word.isDueForReview
        let text = due ? "待复习" : nextReviewText
        return Text(text)
            .font(.caption2)
            .foregroundStyle(due ? .white : .secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(due ? Color.orange : Color.clear, in: Capsule())
    }

    private var nextReviewText: String {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: word.nextReviewDate).day ?? 0
        if days <= 0 { return "今天" }
        if days == 1 { return "明天" }
        return "\(days) 天后"
    }
}
