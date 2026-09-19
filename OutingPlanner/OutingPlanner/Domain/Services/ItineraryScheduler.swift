//
//  ItineraryScheduler.swift
//  OutingPlanner
//

import CoreLocation
import Foundation

struct EditableStop: Identifiable, Hashable {
    var id: String
    var event: OutingEvent
    var scheduledStart: Date
    var scheduledEnd: Date
    var isMealStop: Bool

    var durationMinutes: Int {
        max(30, Int(scheduledEnd.timeIntervalSince(scheduledStart) / 60))
    }

    init(from stop: PatternStop) {
        id = stop.id
        event = stop.event
        scheduledStart = stop.scheduledStart
        scheduledEnd = stop.scheduledEnd
        isMealStop = stop.isMealStop
    }

    init(
        id: String,
        event: OutingEvent,
        scheduledStart: Date,
        scheduledEnd: Date,
        isMealStop: Bool = false
    ) {
        self.id = id
        self.event = event
        self.scheduledStart = scheduledStart
        self.scheduledEnd = scheduledEnd
        self.isMealStop = isMealStop
    }

    func toPatternStop() -> PatternStop {
        PatternStop(
            id: id,
            event: event,
            scheduledStart: scheduledStart,
            scheduledEnd: scheduledEnd,
            isMealStop: isMealStop
        )
    }
}

enum ItineraryScheduler {
    /// Estimated travel minutes between two spots.
    static func travelMinutes(from: OutingEvent, to: OutingEvent) -> Int {
        if let fromCoord = GeoHelper.coordinate(for: from),
           let toCoord = GeoHelper.coordinate(for: to) {
            let km = GeoHelper.distanceKm(from: fromCoord, to: toCoord)
            switch km {
            case ..<0.6: return 10
            case ..<1.5: return 15
            case ..<3.0: return 25
            case ..<5.0: return 35
            default: return 50
            }
        }
        return travelMinutes(fromArea: from.area, toArea: to.area)
    }

    static func travelMinutes(fromArea: String, toArea: String) -> Int {
        if fromArea == toArea { return 10 }
        if isNearbyArea(fromArea, toArea) { return 20 }
        return 35
    }

    static func gapMinutes(between earlier: EditableStop, and later: EditableStop) -> Int {
        max(0, Int(later.scheduledStart.timeIntervalSince(earlier.scheduledEnd) / 60))
    }

    static func requiredTravel(between earlier: EditableStop, and later: EditableStop) -> Int {
        travelMinutes(from: earlier.event, to: later.event)
    }

    /// Travel estimate from an arbitrary meeting coordinate to a stop.
    static func travelMinutes(from coordinate: CLLocationCoordinate2D?, to event: OutingEvent) -> Int {
        guard let from = coordinate,
              let to = GeoHelper.coordinate(for: event) else {
            return 10
        }
        let km = GeoHelper.distanceKm(from: from, to: to)
        switch km {
        case ..<0.35: return 5
        case ..<0.6: return 10
        case ..<1.5: return 15
        case ..<3.0: return 25
        case ..<5.0: return 35
        default: return 50
        }
    }

    /// Returns warnings after mutating stops to keep travel feasible.
    @discardableResult
    static func setStart(
        _ stops: inout [EditableStop],
        at index: Int,
        to requestedStart: Date,
        window: TimeSlotRequest
    ) -> [String] {
        guard stops.indices.contains(index) else { return [] }
        var warnings: [String] = []

        let duration = max(30, stops[index].event.resolvedDurationMinutes)
        var start = max(requestedStart, window.start)

        if index > 0 {
            let previous = stops[index - 1]
            let travel = travelMinutes(from: previous.event, to: stops[index].event)
            let earliest = previous.scheduledEnd.addingTimeInterval(TimeInterval(travel * 60))
            if start < earliest {
                start = earliest
                warnings.append(
                    "\(index)番目の開始を\(travel)分の移動後（\(timeLabel(earliest))）に調整しました。"
                )
            }
        }

        stops[index].scheduledStart = start
        stops[index].scheduledEnd = start.addingTimeInterval(TimeInterval(duration * 60))
        warnings.append(contentsOf: cascadeForward(from: index, stops: &stops, window: window))
        return warnings
    }

    /// Swap the event at index and re-pack times with travel buffers.
    @discardableResult
    static func swapEvent(
        _ stops: inout [EditableStop],
        at index: Int,
        with event: OutingEvent,
        window: TimeSlotRequest
    ) -> [String] {
        guard stops.indices.contains(index) else { return [] }
        let duration = max(30, event.resolvedDurationMinutes)
        let start = stops[index].scheduledStart
        stops[index] = EditableStop(
            id: "\(stops[index].id)-alt-\(event.id)",
            event: event,
            scheduledStart: start,
            scheduledEnd: start.addingTimeInterval(TimeInterval(duration * 60))
        )
        // Re-validate against previous, then cascade.
        return setStart(&stops, at: index, to: start, window: window)
    }

    static func alternatives(
        for stops: [EditableStop],
        at index: Int,
        catalog: [OutingEvent],
        station: TokyoStation?,
        limit: Int = 8
    ) -> [OutingEvent] {
        guard stops.indices.contains(index) else { return [] }
        let current = stops[index]
        let usedIds = Set(stops.map(\.event.id))

        let ranked = catalog
            .filter { !usedIds.contains($0.id) || $0.id == current.event.id }
            .filter { $0.id != current.event.id }
            .map { event -> (OutingEvent, Int) in
                var score = 0
                if Set(event.genres).intersection(Set(current.event.genres)).isEmpty == false {
                    score += 20
                }
                if isNearbyArea(event.area, current.event.area) { score += 25 }
                if let station,
                   let distance = GeoHelper.distanceKm(from: event, to: station) {
                    switch distance {
                    case ..<1.5: score += 40
                    case ..<3.0: score += 25
                    case ..<5.0: score += 10
                    default: score -= 30
                    }
                } else if let currentCoord = GeoHelper.coordinate(for: current.event),
                          let eventCoord = GeoHelper.coordinate(for: event) {
                    let km = GeoHelper.distanceKm(from: currentCoord, to: eventCoord)
                    if km < 2 { score += 30 }
                    else if km < 4 { score += 15 }
                    else if km > 8 { score -= 25 }
                }
                if event.resolvedDurationMinutes <= current.durationMinutes + 30 {
                    score += 8
                }
                return (event, score)
            }
            .sorted { $0.1 > $1.1 }
            .map(\.0)

        return Array(StickerDeduper.unique(ranked).prefix(limit))
    }

    static func feasibilityWarnings(
        stops: [EditableStop],
        window: TimeSlotRequest
    ) -> [String] {
        var warnings: [String] = []
        for index in 0..<(stops.count - 1) {
            let needed = requiredTravel(between: stops[index], and: stops[index + 1])
            let gap = gapMinutes(between: stops[index], and: stops[index + 1])
            if gap < needed {
                warnings.append(
                    "\(index + 1)→\(index + 2)の移動が不足しています（必要\(needed)分 / 空き\(gap)分）。"
                )
            }
        }
        if let last = stops.last, last.scheduledEnd > window.end {
            warnings.append("最終スポットが希望終了時刻を超えています。")
        }
        if let first = stops.first, first.scheduledStart < window.start {
            warnings.append("最初のスポットが希望開始時刻より前です。")
        }
        return warnings
    }

    // MARK: - Private

    private static func cascadeForward(
        from index: Int,
        stops: inout [EditableStop],
        window: TimeSlotRequest
    ) -> [String] {
        var warnings: [String] = []
        guard index < stops.count - 1 else {
            if let last = stops.last, last.scheduledEnd > window.end {
                warnings.append("希望の終了時刻（\(timeLabel(window.end))）を超えています。")
            }
            return warnings
        }

        for j in (index + 1)..<stops.count {
            let previous = stops[j - 1]
            let travel = travelMinutes(from: previous.event, to: stops[j].event)
            let earliest = previous.scheduledEnd.addingTimeInterval(TimeInterval(travel * 60))
            let duration = max(30, stops[j].event.resolvedDurationMinutes)

            if stops[j].scheduledStart < earliest {
                stops[j].scheduledStart = earliest
                stops[j].scheduledEnd = earliest.addingTimeInterval(TimeInterval(duration * 60))
                warnings.append(
                    "\(j + 1)番目以降を移動時間（\(travel)分）に合わせて後ろへずらしました。"
                )
            } else {
                // Keep duration consistent with event default when cascading isn't needed.
                stops[j].scheduledEnd = stops[j].scheduledStart
                    .addingTimeInterval(TimeInterval(duration * 60))
            }
        }

        if let last = stops.last, last.scheduledEnd > window.end {
            warnings.append("調整の結果、希望の終了時刻を超えるプランになっています。時間を短くするか代替案に差し替えてください。")
        }
        return Array(Set(warnings))
    }

    private static let areaGroups: [[String]] = [
        ["池袋", "雑司が谷", "目白", "南長崎"],
        ["上野", "谷中", "浅草", "秋葉原", "日暮里", "千駄木", "押上"],
        ["渋谷", "原宿", "表参道", "外苑", "代々木", "恵比寿"],
        ["新宿", "中野", "高田馬場"],
        ["六本木", "麻布", "麻布台", "赤坂"],
        ["豊洲", "お台場", "有明"],
        ["丸の内", "銀座", "築地", "日本橋", "有楽町", "東京"],
        ["吉祥寺", "井の頭"],
        ["神楽坂", "飯田橋"]
    ]

    private static func isNearbyArea(_ a: String, _ b: String) -> Bool {
        if a == b { return true }
        let ga = areaGroups.firstIndex { group in group.contains { a.contains($0) } }
        let gb = areaGroups.firstIndex { group in group.contains { b.contains($0) } }
        guard let ga, let gb else { return false }
        return ga == gb
    }

    private static func timeLabel(_ date: Date) -> String {
        date.formatted(
            Date.FormatStyle(date: .omitted, time: .shortened)
                .locale(Locale(identifier: "ja_JP"))
        )
    }
}
