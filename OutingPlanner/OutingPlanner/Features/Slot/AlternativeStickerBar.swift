//
//  AlternativeStickerBar.swift
//  OutingPlanner
//

import SwiftUI

struct AlternativeStickerBar: View {
    let alternatives: [OutingEvent]
    let currentID: String
    var title: String = "代替案"
    var onSelect: (OutingEvent) -> Void
    var onDelete: ((OutingEvent) -> Void)? = nil
    var onAdd: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DesignTokens.muted)
                Spacer()
                if onAdd != nil {
                    Button {
                        onAdd?()
                    } label: {
                        Label("追加", systemImage: "plus")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(DesignTokens.sky)
                }
            }

            if alternatives.isEmpty {
                Text("候補がありません。「追加」から店名検索できます。")
                    .font(.caption2)
                    .foregroundStyle(DesignTokens.muted)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(StickerDeduper.unique(alternatives)) { event in
                            sticker(event)
                        }
                    }
                    .padding(.vertical, 2)
                    .padding(.trailing, 4)
                }
            }
        }
    }

    private func sticker(_ event: OutingEvent) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                onSelect(event)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DesignTokens.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 4) {
                        if let cuisine = FoodCuisine.labels(for: event).first {
                            Text(cuisine)
                            Text("·")
                        }
                        Text(event.area)
                        Text("·")
                        Text(event.source == .tabelog ? "食べログ" : "\(event.resolvedDurationMinutes)分")
                    }
                    .font(.caption2)
                    .foregroundStyle(DesignTokens.muted)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(width: 148, alignment: .leading)
                .background(DesignTokens.card)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(
                            event.id == currentID
                                ? DesignTokens.sky
                                : DesignTokens.border,
                            lineWidth: event.id == currentID ? 2 : 1
                        )
                )
            }
            .buttonStyle(.plain)

            if let onDelete {
                Button {
                    onDelete(event)
                } label: {
                    Text("外す")
                        .font(.caption2)
                        .foregroundStyle(DesignTokens.muted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("ステッカーを削除")
            }
        }
    }
}
