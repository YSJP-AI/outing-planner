//
//  EventDetailView.swift
//  OutingPlanner
//

import SwiftUI

struct EventDetailView: View {
    @Environment(AppModel.self) private var model
    let event: OutingEvent
    @State private var didAdd = false
    @State private var addFailed = false

    private var linkDestinations: [EventInfoLink.Destination] {
        EventInfoLink.destinations(for: event)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(event.area)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(DesignTokens.sky)
                        if event.isLimitedTime {
                            Text("期間限定")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .foregroundStyle(DesignTokens.onAccent)
                                .background(DesignTokens.accentGradient)
                                .clipShape(Capsule(style: .continuous))
                        }
                    }
                    Text(event.title)
                        .font(.title2.weight(.bold))
                        .fontDesign(.rounded)
                        .foregroundStyle(DesignTokens.ink)
                    if let summary = event.summary {
                        Text(summary)
                            .font(.body)
                            .foregroundStyle(DesignTokens.muted)
                    }
                }

                infoGrid

                linkSection

                Button {
                    let success = model.addToCalendar(event)
                    didAdd = success
                    addFailed = !success
                } label: {
                    Label("カレンダーに追加", systemImage: "calendar.badge.plus")
                }
                .buttonStyle(BluePrimaryButtonStyle())

                if didAdd {
                    Text("今週のカレンダーに配置しました。")
                        .font(.footnote)
                        .foregroundStyle(DesignTokens.leaf)
                }
                if addFailed {
                    Text("空き枠が見つかりませんでした。別の時間帯を週ビューで調整してください。")
                        .font(.footnote)
                        .foregroundStyle(DesignTokens.coral)
                }
            }
            .padding(20)
            .padding(.bottom, 40)
        }
        .flatCanvasBackground()
        .navigationTitle("お出かけ詳細")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var linkSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("詳細・公式情報")
                .font(.subheadline.weight(.semibold))
                .fontDesign(.rounded)
                .foregroundStyle(DesignTokens.ink)

            Text("開催時間・料金・アクセスは、公式またはイベント紹介ページで最新情報を確認してください。")
                .font(.caption)
                .foregroundStyle(DesignTokens.muted)

            ForEach(linkDestinations) { destination in
                Link(destination: destination.url) {
                    HStack(spacing: 12) {
                        Image(systemName: destination.isPrimary ? "safari.fill" : "magnifyingglass")
                            .font(.title3)
                            .foregroundStyle(destination.isPrimary ? DesignTokens.onAccent : DesignTokens.sky)
                            .frame(width: 40, height: 40)
                            .background {
                                if destination.isPrimary {
                                    Circle().fill(DesignTokens.accentGradient)
                                } else {
                                    Circle().fill(DesignTokens.mist)
                                }
                            }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(destination.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(DesignTokens.ink)
                            Text(destination.subtitle)
                                .font(.caption2)
                                .foregroundStyle(DesignTokens.muted)
                                .lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(DesignTokens.sky)
                    }
                    .padding(14)
                    .flatCard(cornerRadius: 16)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var infoGrid: some View {
        VStack(spacing: 12) {
            detailRow(icon: "mappin.and.ellipse", title: "場所", value: event.venue ?? event.area)
            detailRow(icon: "clock", title: "所要時間", value: "\(event.resolvedDurationMinutes)分")
            detailRow(icon: "yensign.circle", title: "金額", value: event.priceLabel)
            detailRow(icon: "calendar", title: "開催", value: event.timeLabel)
            detailRow(icon: "tag", title: "ジャンル", value: event.genres.joined(separator: " / "))
            detailRow(icon: "tray.full", title: "情報元", value: event.source.displayName)
        }
        .padding(14)
        .flatCard(cornerRadius: 16)
    }

    private func detailRow(icon: String, title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(DesignTokens.sky)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(DesignTokens.muted)
                Text(value)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(DesignTokens.ink)
            }
            Spacer()
        }
    }
}
