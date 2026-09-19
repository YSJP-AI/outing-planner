//
//  ProposalEngine.swift
//  OutingPlanner
//

import Foundation

struct OutingProposal: Identifiable, Hashable {
    let id: String
    let event: OutingEvent
    let reason: String
}

enum ProposalEngine {
    /// Returns Tokyo outing ideas, prioritizing dated / seasonal events in the next month.
    static func propose(
        from events: [OutingEvent],
        filters: OutingFilters,
        existingPlans: [OutingPlan],
        referenceDate: Date = .now,
        limit: Int = 8
    ) -> [OutingProposal] {
        let filtered = EventFilterService.filter(events, with: filters, referenceDate: referenceDate)
        let plannedIds = Set(existingPlans.map(\.eventId))

        let inWindow = filtered.filter {
            EventTiming.isWithinRecommendationWindow($0, reference: referenceDate)
        }

        let ranked = inWindow.sorted { lhs, rhs in
            score(lhs, plannedIds: plannedIds, purpose: filters.purpose, reference: referenceDate)
                > score(rhs, plannedIds: plannedIds, purpose: filters.purpose, reference: referenceDate)
        }

        // Fill timed/seasonal events first so things like drone shows surface.
        let timed = ranked.filter { $0.startAt != nil || $0.endAt != nil }
        let evergreen = ranked.filter { $0.startAt == nil && $0.endAt == nil }

        var results: [OutingProposal] = []
        var usedGenres: Set<String> = []
        var usedAreas: Set<String> = []

        func append(from pool: [OutingEvent], requireGenreVariety: Bool) {
            for event in pool {
                if results.count >= limit { return }
                if plannedIds.contains(event.id) { continue }
                if results.contains(where: { $0.id == event.id }) { continue }

                let primaryGenre = event.genres.first ?? "その他"
                if requireGenreVariety,
                   usedGenres.contains(primaryGenre),
                   results.count >= 3 {
                    continue
                }
                // Soft area diversity after a few picks.
                if usedAreas.contains(event.area), results.count >= 4, event.startAt == nil {
                    continue
                }

                results.append(
                    OutingProposal(
                        id: event.id,
                        event: event,
                        reason: reason(for: event, purpose: filters.purpose, reference: referenceDate)
                    )
                )
                usedGenres.insert(primaryGenre)
                usedAreas.insert(event.area)
            }
        }

        let timedSlots = min(limit, max(4, (limit + 1) / 2 + 1))
        append(from: Array(timed.prefix(timedSlots + 4)), requireGenreVariety: false)
        if results.count < timedSlots {
            append(from: timed, requireGenreVariety: false)
        }
        append(from: evergreen, requireGenreVariety: true)

        if results.count < min(3, limit) {
            for event in ranked where !results.contains(where: { $0.id == event.id }) {
                if plannedIds.contains(event.id) { continue }
                results.append(
                    OutingProposal(
                        id: event.id,
                        event: event,
                        reason: reason(for: event, purpose: filters.purpose, reference: referenceDate)
                    )
                )
                if results.count >= min(3, limit) { break }
            }
        }

        return Array(results.prefix(limit))
    }

    private static func score(
        _ event: OutingEvent,
        plannedIds: Set<String>,
        purpose: OutingPurpose,
        reference: Date
    ) -> Int {
        var value = 0
        if plannedIds.contains(event.id) { return -1000 }
        value += EventTiming.recommendationBoost(event, reference: reference)

        // Prefer concrete limited-time events over evergreen spots.
        if event.isLimitedTime {
            value += 50
            if isHappeningSoonOrNow(event, reference: reference) {
                value += 35
            }
        }

        if event.priceMin == 0 || event.priceText?.contains("無料") == true { value += 18 }
        if event.resolvedDurationMinutes <= 120 { value += 10 }

        let knownAreas = ["お台場", "上野", "浅草", "渋谷", "六本木", "豊洲", "丸の内", "芝公園", "新宿", "代々木", "池袋", "吉祥寺"]
        if knownAreas.contains(where: { event.area.contains($0) }) {
            value += 10
        }

        if event.genres.contains("祭り") { value += 12 }
        if event.genres.contains("エンタメ") || event.genres.contains("アート") || event.genres.contains("グルメ") {
            value += 6
        }
        if event.genres.contains("映え") || event.source == .instagram || event.source == .trend {
            value += 8
        }
        if event.source == .official { value += 10 }

        value += OutingPurposeScorer.score(event, purpose: purpose)
        return value
    }

    private static func isHappeningSoonOrNow(_ event: OutingEvent, reference: Date) -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: reference)
        guard let horizon = calendar.date(byAdding: .day, value: 7, to: today) else { return false }

        if let endAt = event.endAt, endAt < today { return false }
        if let startAt = event.startAt, startAt <= horizon {
            if let endAt = event.endAt { return endAt >= today }
            return true
        }
        if event.startAt == nil, let endAt = event.endAt {
            return endAt >= today && endAt <= horizon
        }
        return false
    }

    private static func reason(
        for event: OutingEvent,
        purpose: OutingPurpose,
        reference: Date
    ) -> String {
        if let timing = EventTiming.recommendationReason(for: event, reference: reference) {
            return timing
        }
        if event.isLimitedTime {
            return "期間限定イベント"
        }
        if event.genres.contains("祭り") {
            return "祭り・催事"
        }
        if let purposeReason = OutingPurposeScorer.reasonSuffix(for: event, purpose: purpose) {
            return purposeReason
        }
        if event.source == .instagram {
            return "Instagramで話題のスポット"
        }
        if event.source == .trend || event.genres.contains("映え") {
            return "今っぽいトレンドのお出かけ"
        }
        if event.priceMin == 0 || event.priceText?.contains("無料") == true {
            return "予算を抑えやすい東京プラン"
        }
        if event.resolvedDurationMinutes <= 90 {
            return "空き時間に入れやすい短時間プラン"
        }
        if event.genres.contains("グルメ") {
            return "食事と散策を組み合わせやすい"
        }
        if event.genres.contains("アート") {
            return "半日で満足しやすい文化系プラン"
        }
        return "東京の定番エリアで回りやすい"
    }
}
