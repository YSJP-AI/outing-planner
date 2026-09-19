//
//  EventRowView.swift
//  OutingPlanner
//

import SwiftUI

struct EventRowView: View {
    let event: OutingEvent
    var reason: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        if event.isLimitedTime {
                            Text("期間限定")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .foregroundStyle(DesignTokens.onAccent)
                                .background(DesignTokens.sky)
                                .clipShape(Capsule(style: .continuous))
                        }
                        Text(event.timeLabel)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(DesignTokens.muted)
                            .lineLimit(1)
                    }
                    Text(event.title)
                        .font(.headline)
                        .fontDesign(.rounded)
                        .foregroundStyle(DesignTokens.ink)
                        .multilineTextAlignment(.leading)
                    Text("\(event.area)\(event.venue.map { " · \($0)" } ?? "")")
                        .font(.subheadline)
                        .foregroundStyle(DesignTokens.muted)
                }
                Spacer(minLength: 8)
                Text(event.priceLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DesignTokens.sky)
            }

            if let reason {
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(DesignTokens.leaf)
            }

            HStack(spacing: 8) {
                ForEach(event.genres, id: \.self) { genre in
                    Text(genre)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(DesignTokens.softFill(DesignTokens.genreColor(genre)))
                        .foregroundStyle(DesignTokens.genreColor(genre))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(DesignTokens.genreColor(genre).opacity(0.35), lineWidth: 1)
                        )
                }
                Spacer()
                Label("\(event.resolvedDurationMinutes)分", systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(DesignTokens.muted)
            }
        }
        .padding(16)
        .flatCard(cornerRadius: 20)
    }
}
