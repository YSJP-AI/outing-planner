//
//  EventFilterService.swift
//  OutingPlanner
//

import Foundation

enum EventFilterService {
    static func filter(_ events: [OutingEvent], with filters: OutingFilters, referenceDate: Date = .now) -> [OutingEvent] {
        events.filter { event in
            if !filters.selectedGenres.isEmpty {
                let overlap = Set(event.genres).intersection(filters.selectedGenres)
                if overlap.isEmpty { return false }
            }

            let query = filters.areaQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            if !query.isEmpty {
                let haystack = [event.area, event.venue ?? "", event.title].joined(separator: " ")
                if !haystack.localizedCaseInsensitiveContains(query) {
                    return false
                }
            }

            if let maxBudget = filters.maxBudget {
                let cost = event.priceMin ?? event.priceMax ?? 0
                if cost > maxBudget { return false }
            }

            if let maxDuration = filters.maxDurationMinutes {
                if event.resolvedDurationMinutes > maxDuration { return false }
            }

            if filters.weekendOnly {
                if let startAt = event.startAt {
                    if !Calendar.current.isDateInWeekend(startAt) {
                        return false
                    }
                }
            }

            // Tokyo-first MVP: keep events that are ongoing or date-free.
            if let endAt = event.endAt, endAt < referenceDate.startOfDay {
                return false
            }

            return true
        }
    }
}

private extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }
}
