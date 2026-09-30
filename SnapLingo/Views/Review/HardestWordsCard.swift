//
//  HardestWordsCard.swift
//  SnapLingo
//
//  复习页「总是记不住的词」：忘过的词按次数排，最多 5 个；点词看详情，按钮专门练这几个。
//  没有忘过的词时整块不显示。
//

import SwiftUI

struct HardestWordsCard: View {
    var words: [VocabWord]
    var onStudy: () -> Void

    private static let fills: [Color] = [Theme.sheet, Theme.placeChip, Theme.sheet, Theme.marker.opacity(0.55), Theme.sheet]
    private static let rotations: [Double] = [-1.5, 1, -1, 1.5, -1]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("总是记不住的词")
                    .font(.system(size: 18, weight: .heavy))
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text("按忘记次数排")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.homeMuted)
            }
            .foregroundStyle(Theme.homeInk)

            FlowLayout(spacing: 8) {
                ForEach(Array(words.enumerated()), id: \.element.id) { index, word in
                    NavigationLink(value: word) {
                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                            Text(verbatim: word.word)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Theme.homeInk)
                            Text("忘了 \(word.lapses) 次")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.homeMuted)
                        }
                        .padding(.horizontal, 13)
                        .padding(.vertical, 7)
                        .background(Self.fills[index % 5], in: .capsule)
                        .overlay(Capsule().strokeBorder(Theme.homeInk.opacity(0.05)))
                        .shadow(color: .black.opacity(0.06), radius: 5, y: 2)
                        .rotationEffect(.degrees(Self.rotations[index % 5]))
                    }
                    .buttonStyle(.pressable)
                }
            }

            Button(action: onStudy) {
                HStack(spacing: 8) {
                    Text("专门练这几个")
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.cream)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(Theme.homeInk, in: .capsule)
            }
            .buttonStyle(.pressable)
            .padding(.top, 2)
        }
        .padding(16)
        .background(Theme.sheet, in: .rect(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
    }
}
