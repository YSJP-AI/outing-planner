//
//  ScheduleHelper.swift
//  OutingPlanner
//

import Foundation

enum ScheduleHelper {
    static func weekDates(containing date: Date, calendar: Calendar = .current) -> [Date] {
        let startOfDay = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: startOfDay)
        // Make Monday the first column (weekday: Sun=1 ... Sat=7)
        let daysFromMonday = (weekday + 5) % 7
        guard let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: startOfDay) else {
            return []
        }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: monday) }
    }

    static func defaultSlot(
        for event: OutingEvent,
        on day: Date,
        calendar: Calendar = .current
    ) -> (start: Date, end: Date) {
        let startOfDay = calendar.startOfDay(for: day)
        let preferredHour = preferredStartHour(for: event)
        let start = calendar.date(byAdding: .hour, value: preferredHour, to: startOfDay) ?? startOfDay
        let end = calendar.date(byAdding: .minute, value: event.resolvedDurationMinutes, to: start) ?? start
        return (start, end)
    }

    static func conflicts(among plans: [OutingPlan], candidate: OutingPlan) -> Bool {
        plans.contains { $0.id != candidate.id && $0.overlaps(candidate) }
    }

    /// Snap a vertical drag (points) into minute delta, rounded to `stepMinutes`.
    static func minuteDelta(
        forTranslationY translationY: CGFloat,
        hourHeight: CGFloat,
        stepMinutes: Int = 15
    ) -> Int {
        let rawMinutes = translationY / hourHeight * 60
        let stepped = (rawMinutes / CGFloat(stepMinutes)).rounded() * CGFloat(stepMinutes)
        return Int(stepped)
    }

    static func dayDelta(
        forTranslationX translationX: CGFloat,
        dayWidth: CGFloat
    ) -> Int {
        Int((translationX / dayWidth).rounded())
    }

    /// Keep the block inside the visible day window (default 9:00–22:00).
    static func clampedSlot(
        start: Date,
        durationMinutes: Int,
        on day: Date,
        dayStartHour: Int = 9,
        dayEndHour: Int = 22,
        calendar: Calendar = .current
    ) -> (start: Date, end: Date) {
        let startOfDay = calendar.startOfDay(for: day)
        let windowStart = calendar.date(byAdding: .hour, value: dayStartHour, to: startOfDay) ?? startOfDay
        let windowEnd = calendar.date(byAdding: .hour, value: dayEndHour, to: startOfDay) ?? startOfDay
        let duration = max(30, durationMinutes)

        var newStart = max(start, windowStart)
        var newEnd = calendar.date(byAdding: .minute, value: duration, to: newStart) ?? newStart
        if newEnd > windowEnd {
            newEnd = windowEnd
            newStart = calendar.date(byAdding: .minute, value: -duration, to: newEnd) ?? windowStart
            newStart = max(newStart, windowStart)
            newEnd = calendar.date(byAdding: .minute, value: duration, to: newStart) ?? newEnd
        }
        return (newStart, newEnd)
    }

    private static func preferredStartHour(for event: OutingEvent) -> Int {
        if event.genres.contains("グルメ"), event.title.contains("ディナー") || event.area.contains("神楽坂") {
            return 18
        }
        if event.title.contains("夜") || event.title.contains("ライトアップ") {
            return 19
        }
        if event.genres.contains("グルメ") {
            return 12
        }
        return 11
    }
}
