//
//  SceneSources.swift
//  SnapLingo
//
//  首页照片墙最上面的「我的英语从哪里来」：按场景类型排的一排卡片（封面 + 占比 + 词数），
//  点进去是这一类的全部场景。
//

import SwiftData
import SwiftUI

struct SceneSourcesRow: View {
    var shares: [SceneTypeShare]
    var scansByID: [UUID: Scan]
    var sidePadding: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("我的英语从哪里来")
                    .font(.system(size: 18, weight: .heavy))
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text("按词数排")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.homeMuted)
            }
            .foregroundStyle(Theme.homeInk)
            .padding(.horizontal, sidePadding)

            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(shares) { share in
                        NavigationLink(value: share.scene) {
                            SceneSourceCard(share: share, cover: scansByID[share.coverScanID])
                        }
                        .buttonStyle(.pressable)
                    }
                }
                .padding(.vertical, 6)
            }
            .contentMargins(.horizontal, sidePadding, for: .scrollContent)
            .scrollIndicators(.hidden)
        }
    }
}

private struct SceneSourceCard: View {
    var share: SceneTypeShare
    var cover: Scan?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScanThumbnail(scan: cover)
                .frame(width: 150, height: 112)
                .clipped()
                .overlay(alignment: .topLeading) {
                    Text("\(share.percent)%")
                        .font(.brand(12))
                        .foregroundStyle(Theme.homeInk)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(Theme.marker, in: .capsule)
                        .padding(8)
                }
            HStack(spacing: 6) {
                Image(systemName: share.scene.symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.homeMuted)
                Text(share.scene.displayName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.homeInk)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            Text("\(share.wordCount) 个词")
                .font(.system(size: 12))
                .foregroundStyle(Theme.homeMuted)
                .padding(.leading, 31)
                .padding(.top, 2)
                .padding(.bottom, 12)
        }
        .frame(width: 150, alignment: .leading)
        .background(Theme.sheet, in: .rect(cornerRadius: 18, style: .continuous))
        .clipShape(.rect(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.07), radius: 10, y: 4)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - 某一类的全部场景

struct SceneTypeScansView: View {
    var scene: SceneType

    @Query(sort: \Scan.createdAt, order: .reverse) private var allScans: [Scan]

    private var scans: [Scan] { allScans.filter { $0.scene == scene } }
    private let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

    var body: some View {
        let scans = scans
        let wordCount = Set(scans.flatMap { $0.words.map(\.id) }).count
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: scene.symbol)
                        .font(.system(size: 19, weight: .semibold))
                        .frame(width: 42, height: 42)
                        .background(Theme.sheet, in: .rect(cornerRadius: 13, style: .continuous))
                        .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
                    Text(scene.displayName)
                        .font(.system(size: 30, weight: .heavy))
                }
                .foregroundStyle(Theme.homeInk)

                Text("\(scans.count) 个场景 · \(wordCount) 个词")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.homeInk.opacity(0.72))
                    .padding(.top, 10)

                LazyVGrid(columns: columns, alignment: .leading, spacing: 20) {
                    ForEach(scans) { scan in
                        NavigationLink(value: scan) {
                            VStack(alignment: .leading, spacing: 0) {
                                ScanThumbnail(scan: scan)
                                    .aspectRatio(1.08, contentMode: .fit)
                                    .clipShape(.rect(cornerRadius: 16, style: .continuous))
                                Text(scan.displayTitle)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Theme.homeInk)
                                    .lineLimit(1)
                                    .padding(.top, 8)
                                Text(HomeDates.dateText(for: scan.createdAt))
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.homeMuted)
                                    .padding(.top, 2)
                            }
                        }
                        .buttonStyle(.pressable)
                    }
                }
                .padding(.top, 22)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 40)
            .background(alignment: .top) { ThemeWash().padding(.horizontal, -24) }
        }
        .scrollIndicators(.hidden)
        .background(Theme.mist.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}
