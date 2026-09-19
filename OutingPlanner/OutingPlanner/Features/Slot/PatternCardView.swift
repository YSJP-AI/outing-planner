//
//  PatternCardView.swift
//  OutingPlanner
//

import SwiftUI

struct PatternCardView: View {
    let pattern: OutingPattern

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(pattern.styleLabel)
                        .font(.caption2.weight(.bold))
                        .fontDesign(.rounded)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .foregroundStyle(DesignTokens.sky)
                        .background(DesignTokens.softFill(DesignTokens.sky))
                        .clipShape(Capsule(style: .continuous))
                    Text(pattern.title)
                        .font(.headline)
                        .fontDesign(.rounded)
                        .foregroundStyle(DesignTokens.ink)
                    Text(pattern.subtitle)
                        .font(.caption)
                        .foregroundStyle(DesignTokens.muted)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(pattern.totalDurationMinutes)分")
                        .font(.caption.weight(.bold))
                        .fontDesign(.rounded)
                        .foregroundStyle(DesignTokens.ink)
                    Text(pattern.estimatedBudgetLabel)
                        .font(.caption2)
                        .foregroundStyle(DesignTokens.muted)
                    if pattern.anchorStationName != nil {
                        Image(systemName: "tram.fill")
                            .font(.caption)
                            .foregroundStyle(DesignTokens.sky)
                    }
                }
            }

            if let meeting = pattern.meetingPlace {
                VStack(alignment: .leading, spacing: 2) {
                    Label("集合: \(meeting.name)", systemImage: "person.3.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DesignTokens.leaf)
                    if let meetingTime = pattern.meetingTime {
                        Text("集合時間 \(timeLabel(meetingTime))")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(DesignTokens.sky)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DesignTokens.mist.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(pattern.stops.enumerated()), id: \.element.id) { index, stop in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(DesignTokens.onAccent)
                            .frame(width: 22, height: 22)
                            .background(DesignTokens.accentGradient)
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(stop.event.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(DesignTokens.ink)
                            Text("\(timeLabel(stop.scheduledStart))–\(timeLabel(stop.scheduledEnd)) · \(stop.event.area)")
                                .font(.caption)
                                .foregroundStyle(DesignTokens.muted)
                        }
                    }
                }
            }

            HStack {
                Label("詳細・地図を見る", systemImage: "map")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DesignTokens.sky)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DesignTokens.muted)
            }
        }
        .padding(16)
        .flatCard(cornerRadius: 20)
    }

    private func timeLabel(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(Locale(identifier: "ja_JP")))
    }
}
