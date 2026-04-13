//
//  ReviewResultView.swift
//  SnapLingo
//

import SwiftUI

struct ReviewResultView: View {
    let results: [ReviewResult]
    let onDismiss: () -> Void

    private var correctCount: Int { results.filter { $0.quality >= 3 }.count }
    private var accuracy: Double {
        guard !results.isEmpty else { return 0 }
        return Double(correctCount) / Double(results.count)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    // 结果图标
                    Image(systemName: accuracyIcon)
                        .font(.system(size: 64))
                        .foregroundStyle(accuracyColor)
                        .padding(.top, 20)

                    // 统计数字
                    VStack(spacing: 6) {
                        Text("复习完成！")
                            .font(.title.bold())
                        Text("共 \(results.count) 个词，答对 \(correctCount) 个")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // 准确率环形
                    ZStack {
                        Circle()
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 12)
                        Circle()
                            .trim(from: 0, to: accuracy)
                            .stroke(accuracyColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.easeOut(duration: 0.8), value: accuracy)
                        Text("\(Int(accuracy * 100))%")
                            .font(.title2.bold())
                            .foregroundStyle(accuracyColor)
                    }
                    .frame(width: 120, height: 120)

                    // 各词结果列表
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(results, id: \.word) { result in
                            HStack {
                                Image(systemName: result.quality >= 3 ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(result.quality >= 3 ? .green : .red)
                                Text(result.word)
                                    .font(.body)
                                Spacer()
                                Text(qualityLabel(result.quality))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            Divider().padding(.leading, 44)
                        }
                    }
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }
            }
            .navigationTitle("复习结果")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成", action: onDismiss)
                }
            }
        }
    }

    private var accuracyIcon: String {
        switch accuracy {
        case 0.8...: return "star.fill"
        case 0.5...: return "hand.thumbsup.fill"
        default:     return "arrow.clockwise"
        }
    }

    private var accuracyColor: Color {
        switch accuracy {
        case 0.8...: return .green
        case 0.5...: return .orange
        default:     return .red
        }
    }

    private func qualityLabel(_ q: Int) -> String {
        switch q {
        case 0: return "完全忘了"
        case 3: return "有点难"
        case 4: return "认识"
        case 5: return "很简单"
        default: return ""
        }
    }
}
