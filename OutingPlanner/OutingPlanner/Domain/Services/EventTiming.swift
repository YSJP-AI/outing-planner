//
//  EventTiming.swift
//  OutingPlanner
//

import Foundation

enum EventTiming {
    /// Recommendation horizon for the home "おすすめ" list.
    static let recommendationHorizonDays = 30

    /// Evergreen (no dates) or overlapping the next month from `reference`.
    static func isWithinRecommendationWindow(
        _ event: OutingEvent,
        reference: Date = .now
    ) -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: reference)
        guard let horizon = calendar.date(
            byAdding: .day,
            value: recommendationHorizonDays,
            to: today
        ) else {
            return true
        }

        // Always-available spots (no schedule).
        if event.startAt == nil, event.endAt == nil {
            return true
        }

        // Already finished.
        if let endAt = event.endAt, endAt < today {
            return false
        }

        // Starts more than a month later — keep out of top recommendations.
        if let startAt = event.startAt, startAt > horizon {
            return false
        }

        return true
    }

    /// Higher is better for near-term dated events.
    static func recommendationBoost(
        _ event: OutingEvent,
        reference: Date = .now
    ) -> Int {
        guard isWithinRecommendationWindow(event, reference: reference) else {
            return -500
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: reference)

        // Multi-day / ongoing festival currently happening.
        if let startAt = event.startAt, let endAt = event.endAt,
           startAt <= reference, endAt >= today {
            return 55
        }

        if let startAt = event.startAt {
            let days = calendar.dateComponents([.day], from: today, to: startAt).day ?? 0
            switch days {
            case ...0: return 45
            case 1...3: return 42
            case 4...7: return 35
            case 8...14: return 28
            case 15...30: return 20
            default: return 0
            }
        }

        return 5
    }

    static func recommendationReason(
        for event: OutingEvent,
        reference: Date = .now
    ) -> String? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: reference)

        if let startAt = event.startAt, let endAt = event.endAt,
           startAt <= reference, endAt >= today {
            let daysLeft = calendar.dateComponents([.day], from: today, to: endAt).day ?? 0
            if daysLeft <= 2 {
                return "まもなく終了・開催中"
            }
            return "開催中（期間限定）"
        }

        guard let startAt = event.startAt else { return nil }
        let days = calendar.dateComponents([.day], from: today, to: startAt).day ?? 0
        if days <= 0 {
            return "本日のおすすめ"
        }
        if days <= 7 {
            return "今週開催予定"
        }
        if days <= 30 {
            return "1ヶ月以内に開催"
        }
        return nil
    }
}
