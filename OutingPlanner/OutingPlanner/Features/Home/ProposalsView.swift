//
//  ProposalsView.swift
//  OutingPlanner
//

import SwiftUI

struct ProposalsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    BlueHeroBanner(
                        eyebrow: "TOKYO OUTINGS",
                        title: "今日からのお出かけを組み立てる",
                        subtitle: "期間限定イベントも一覧表示。詳細から公式ページへジャンプできます。",
                        trailing: AnyView(
                            ThemePickerButton(compact: true, onHero: true)
                        )
                    )

                    VStack(alignment: .leading, spacing: 18) {
                        refreshCard

                        FilterBarView(filters: $model.filters)
                            .padding(16)
                            .flatCard(cornerRadius: 20)

                        if let loadError = model.loadError {
                            Text(loadError)
                                .foregroundStyle(DesignTokens.coral)
                        }

                        if let message = model.eventsRefreshMessage {
                            Text(message)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(
                                    message.contains("失敗") || message.contains("HTTP")
                                        ? DesignTokens.coral
                                        : DesignTokens.leaf
                                )
                        }

                        sectionTitle("期間限定・開催予定 (\(limitedTimeEvents.count)件)")

                        if limitedTimeEvents.isEmpty {
                            Text("条件に合う期間限定イベントはまだありません。")
                                .font(.footnote)
                                .foregroundStyle(DesignTokens.muted)
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(limitedTimeEvents) { event in
                                    NavigationLink {
                                        EventDetailView(event: event)
                                    } label: {
                                        EventRowView(
                                            event: event,
                                            reason: EventTiming.recommendationReason(for: event)
                                                ?? "期間限定イベント"
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        sectionTitle("おすすめ \(model.proposals.count)件")

                        LazyVStack(spacing: 12) {
                            ForEach(model.proposals) { proposal in
                                NavigationLink {
                                    EventDetailView(event: proposal.event)
                                } label: {
                                    EventRowView(event: proposal.event, reason: proposal.reason)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        sectionTitle("スポット・その他 (\(evergreenEvents.count))")

                        LazyVStack(spacing: 12) {
                            ForEach(evergreenEvents) { event in
                                NavigationLink {
                                    EventDetailView(event: event)
                                } label: {
                                    EventRowView(event: event)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.bottom, 100)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 18)
                }
            }
            .flatCanvasBackground()
            .toolbar(.hidden, for: .navigationBar)
            .onChange(of: model.filters.purpose) { _, newValue in
                model.slotRequest.purpose = newValue
            }
        }
    }

    private var refreshCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("イベントデータ")
                        .font(.subheadline.weight(.semibold))
                        .fontDesign(.rounded)
                        .foregroundStyle(DesignTokens.ink)
                    Text(refreshStatusText)
                        .font(.caption)
                        .foregroundStyle(DesignTokens.muted)
                }
                Spacer()
                Button {
                    Task { await model.refreshEventsFromRemote() }
                } label: {
                    HStack(spacing: 6) {
                        if model.isRefreshingEvents {
                            ProgressView()
                                .controlSize(.small)
                                .tint(DesignTokens.onAccent)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text(model.isRefreshingEvents ? "更新中" : "更新")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(DesignTokens.onAccent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(DesignTokens.accentGradient)
                    .clipShape(Capsule(style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(model.isRefreshingEvents)
            }

            Text("無料の公開カタログから最新の期間限定イベントを取得します。通信料以外の追加料金はかかりません。")
                .font(.caption2)
                .foregroundStyle(DesignTokens.muted)
        }
        .padding(16)
        .flatCard(cornerRadius: 20)
    }

    private var refreshStatusText: String {
        if let last = model.lastEventsRefreshAt {
            let formatted = last.formatted(
                Date.FormatStyle(date: .abbreviated, time: .shortened)
                    .locale(Locale(identifier: "ja_JP"))
            )
            return "前回更新: \(formatted)（リモート \(model.remoteEventCount)件）"
        }
        return "まだリモート更新していません（同梱データを表示中）"
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.headline)
            .fontDesign(.rounded)
            .foregroundStyle(DesignTokens.ink)
            .padding(.top, 4)
    }

    /// All filtered events that have concrete dates and are still within the recommendation window.
    private var limitedTimeEvents: [OutingEvent] {
        model.filteredEvents
            .filter(\.isLimitedTime)
            .filter { EventTiming.isWithinRecommendationWindow($0) }
            .sorted { lhs, rhs in
                let l = lhs.startAt ?? .distantFuture
                let r = rhs.startAt ?? .distantFuture
                return l < r
            }
    }

    private var evergreenEvents: [OutingEvent] {
        model.filteredEvents.filter { !$0.isLimitedTime }
    }
}
