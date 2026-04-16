//
//  ReviewView.swift
//  SnapLingo
//

import SwiftUI
import SwiftData

struct ReviewView: View {
    @Query private var allWords: [VocabWord]

    private var dueAll: [VocabWord] { allWords.filter(\.isDueForReview) }
    private var masteredAll: Int { allWords.filter(\.isMastered).count }

    private var categoryStats: [CategoryReviewStat] {
        var groups: [String: [VocabWord]] = [:]
        for word in allWords { groups[word.categoryName, default: []].append(word) }
        return groups.map { name, words in
            CategoryReviewStat(categoryName: name, words: words)
        }
        .sorted { $0.dueCount > $1.dueCount }
    }

    var body: some View {
        NavigationStack {
            List {
                // 全局概览 banner
                overviewSection

                // 全部复习入口
                if !dueAll.isEmpty {
                    Section {
                        NavigationLink {
                            FlashcardReviewView(
                                categoryName: "全部复习",
                                wordsToReview: dueAll
                            )
                        } label: {
                            allReviewRow
                        }
                    }
                }

                // 各分类
                if !categoryStats.isEmpty {
                    Section("分类复习") {
                        ForEach(categoryStats) { stat in
                            NavigationLink {
                                FlashcardReviewView(
                                    categoryName: stat.categoryName,
                                    wordsToReview: stat.dueWords
                                )
                            } label: {
                                categoryRow(stat)
                            }
                            .disabled(stat.dueCount == 0)
                        }
                    }
                }

                // 无词状态
                if allWords.isEmpty {
                    Section {
                        ContentUnavailableView(
                            "还没有词汇",
                            systemImage: "books.vertical",
                            description: Text("从首页扫描照片来添加词汇吧")
                        )
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("复习")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - 全局概览

    private var overviewSection: some View {
        Section {
            HStack(spacing: 0) {
                overviewCell(value: "\(allWords.count)", label: "总词汇", color: .blue)
                Divider().frame(height: 36)
                overviewCell(value: "\(dueAll.count)", label: "待复习", color: .orange)
                Divider().frame(height: 36)
                overviewCell(value: "\(masteredAll)", label: "已掌握", color: .green)
            }
            .padding(.vertical, 8)
        }
    }

    private func overviewCell(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 全部复习行

    private var allReviewRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "brain.head.profile")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text("全部复习")
                    .font(.headline)
                Text("混合所有分类，\(dueAll.count) 词待复习")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            dueBadge(dueAll.count, color: .accentColor)
        }
        .padding(.vertical, 4)
    }

    // MARK: - 分类行

    private func categoryRow(_ stat: CategoryReviewStat) -> some View {
        HStack(spacing: 12) {
            Image(systemName: stat.words.first?.sceneTag.icon ?? "tag")
                .font(.title3)
                .foregroundStyle(stat.dueCount > 0 ? .white : .secondary)
                .frame(width: 44, height: 44)
                .background(
                    stat.dueCount > 0 ? Color.accentColor.opacity(0.85) : Color.secondary.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 10)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(stat.categoryName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(stat.dueCount > 0 ? .primary : .secondary)

                HStack(spacing: 8) {
                    Text("\(stat.totalCount) 词")
                    Text("·")
                    Text("\(stat.masteredCount) 已掌握")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if stat.dueCount > 0 {
                dueBadge(stat.dueCount, color: .orange)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 4)
    }

    private func dueBadge(_ count: Int, color: Color) -> some View {
        Text("\(count)")
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color, in: Capsule())
    }
}

// MARK: - 辅助数据结构

struct CategoryReviewStat: Identifiable {
    let id = UUID()
    let categoryName: String
    let words: [VocabWord]

    var dueWords: [VocabWord] { words.filter(\.isDueForReview) }
    var dueCount: Int { dueWords.count }
    var masteredCount: Int { words.filter(\.isMastered).count }
    var totalCount: Int { words.count }
}
