//
//  OutingPattern.swift
//  OutingPlanner
//

import CoreLocation
import Foundation

struct TimeSlotRequest: Equatable {
    var start: Date
    var end: Date
    /// Optional free-text nearest station (e.g. "渋谷", "上野駅").
    var preferredStation: String = ""
    /// Set when MapKit resolves a station outside the hardcoded catalog.
    var resolvedStationOverride: TokyoStation? = nil
    var purpose: OutingPurpose = .unspecified
    var lunchEnabled: Bool = false
    var lunchTime: Date = Date()
    var dinnerEnabled: Bool = false
    var dinnerTime: Date = Date()

    var durationMinutes: Int {
        max(0, Int(end.timeIntervalSince(start) / 60))
    }

    var isValid: Bool {
        end > start && durationMinutes >= 30
    }

    var resolvedStation: TokyoStation? {
        TokyoStationCatalog.resolve(preferredStation) ?? resolvedStationOverride
    }

    static func defaultRequest(reference: Date = .now) -> TimeSlotRequest {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: reference)
        var start = calendar.date(byAdding: .hour, value: 12, to: startOfDay) ?? reference
        if start < reference {
            start = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        }
        let end = calendar.date(byAdding: .hour, value: 4, to: start) ?? start
        let lunch = calendar.date(bySettingHour: 12, minute: 30, second: 0, of: start) ?? start
        let dinner = calendar.date(bySettingHour: 18, minute: 30, second: 0, of: start) ?? start
        return TimeSlotRequest(
            start: start,
            end: end,
            preferredStation: "",
            resolvedStationOverride: nil,
            purpose: .unspecified,
            lunchEnabled: false,
            lunchTime: lunch,
            dinnerEnabled: false,
            dinnerTime: dinner
        )
    }

    mutating func syncMealTimesToStartDay() {
        let calendar = Calendar.current
        lunchTime = calendar.date(
            bySettingHour: calendar.component(.hour, from: lunchTime),
            minute: calendar.component(.minute, from: lunchTime),
            second: 0,
            of: start
        ) ?? lunchTime
        dinnerTime = calendar.date(
            bySettingHour: calendar.component(.hour, from: dinnerTime),
            minute: calendar.component(.minute, from: dinnerTime),
            second: 0,
            of: start
        ) ?? dinnerTime
    }
}

struct PatternStop: Identifiable, Hashable {
    let id: String
    let event: OutingEvent
    let scheduledStart: Date
    let scheduledEnd: Date
    var isMealStop: Bool = false

    var durationMinutes: Int {
        max(30, Int(scheduledEnd.timeIntervalSince(scheduledStart) / 60))
    }

    var coordinate: CLLocationCoordinate2D? {
        GeoHelper.coordinate(for: event)
    }
}

struct OutingPattern: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let styleLabel: String
    let stops: [PatternStop]
    var anchorStationName: String? = nil
    var anchorStationCoordinate: CLLocationCoordinate2D? = nil
    var meetingPlace: MeetingPlace? = nil

    var totalDurationMinutes: Int {
        guard let first = stops.first, let last = stops.last else { return 0 }
        return max(0, Int(last.scheduledEnd.timeIntervalSince(first.scheduledStart) / 60))
    }

    var estimatedBudgetLabel: String {
        let mins = stops.compactMap(\.event.priceMin)
        if mins.isEmpty { return "料金は各スポットを確認" }
        if mins.allSatisfy({ $0 == 0 }) { return "ほぼ無料〜低予算" }
        let sum = mins.reduce(0, +)
        return "目安 ¥\(sum.formatted())〜"
    }

    var mapCoordinates: [CLLocationCoordinate2D] {
        stops.compactMap(\.coordinate)
    }

    var meetingTime: Date? {
        guard let meetingPlace else { return nil }
        return MeetingPlaceSuggestor.suggestedMeetingTime(for: meetingPlace, stops: stops)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: OutingPattern, rhs: OutingPattern) -> Bool {
        lhs.id == rhs.id
            && lhs.stops == rhs.stops
            && lhs.anchorStationName == rhs.anchorStationName
            && lhs.meetingPlace?.id == rhs.meetingPlace?.id
    }
}
