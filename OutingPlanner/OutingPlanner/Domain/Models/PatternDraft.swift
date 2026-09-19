//
//  PatternDraft.swift
//  OutingPlanner
//

import CoreLocation
import Foundation
import Observation

@Observable
final class PatternDraft {
    let id: String
    let title: String
    let subtitle: String
    let styleLabel: String
    var stops: [EditableStop]
    let window: TimeSlotRequest
    var anchorStationName: String?
    var anchorStationCoordinate: CLLocationCoordinate2D?
    var meetingPlace: MeetingPlace?
    var meetingPlaceOptions: [MeetingPlace] = []
    /// Editable sticker trays per meal kind.
    var mealStickerTray: [MealKind: [OutingEvent]] = [:]
    /// Editable alternative stickers per stop index.
    var stopStickerTray: [Int: [OutingEvent]] = [:]
    private(set) var adjustmentNotes: [String] = []

    init(pattern: OutingPattern, window: TimeSlotRequest, restaurants: [OutingEvent] = []) {
        id = pattern.id
        title = pattern.title
        subtitle = pattern.subtitle
        styleLabel = pattern.styleLabel
        stops = pattern.stops.map(EditableStop.init(from:))
        self.window = window
        anchorStationName = pattern.anchorStationName
        anchorStationCoordinate = pattern.anchorStationCoordinate
        meetingPlace = pattern.meetingPlace
        meetingPlaceOptions = MeetingPlaceSuggestor.alternatives(
            for: pattern,
            station: window.resolvedStation ?? TokyoStationCatalog.resolve(pattern.anchorStationName ?? "")
        )
        if meetingPlace == nil {
            meetingPlace = meetingPlaceOptions.first
        }

        for kind in MealKind.allCases where mealEnabled(kind) {
            mealStickerTray[kind] = MealPlaceSuggestor.suggest(
                kind: kind,
                at: mealTime(kind),
                for: pattern,
                restaurants: restaurants,
                station: window.resolvedStation ?? TokyoStationCatalog.resolve(pattern.anchorStationName ?? "")
            )
        }
        // Ensure lunch/dinner trays don't repeat the same shop titles.
        dedupeMealStickerTrays()
    }

    private func dedupeMealStickerTrays() {
        var reserved = Set(stops.map { StickerDeduper.normalizedTitle($0.event.title) })
        for kind in MealKind.allCases {
            guard let list = mealStickerTray[kind] else { continue }
            let unique = StickerDeduper.unique(list, excludingTitles: reserved)
            mealStickerTray[kind] = unique
            for event in unique {
                reserved.insert(StickerDeduper.normalizedTitle(event.title))
            }
        }
    }

    var feasibilityWarnings: [String] {
        ItineraryScheduler.feasibilityWarnings(stops: stops, window: window)
    }

    var allWarnings: [String] {
        adjustmentNotes + feasibilityWarnings
    }

    var isFeasible: Bool {
        feasibilityWarnings.isEmpty
    }

    var totalDurationMinutes: Int {
        guard let first = stops.first, let last = stops.last else { return 0 }
        return max(0, Int(last.scheduledEnd.timeIntervalSince(first.scheduledStart) / 60))
    }

    func setStart(at index: Int, to date: Date) {
        adjustmentNotes = ItineraryScheduler.setStart(
            &stops,
            at: index,
            to: date,
            window: window
        )
    }

    func swap(at index: Int, with event: OutingEvent) {
        adjustmentNotes = ItineraryScheduler.swapEvent(
            &stops,
            at: index,
            with: event,
            window: window
        )
    }

    func removeStop(at index: Int) {
        guard stops.indices.contains(index) else { return }
        stops.remove(at: index)
        var rebuilt: [Int: [OutingEvent]] = [:]
        for (key, value) in stopStickerTray where key < index {
            rebuilt[key] = value
        }
        for (key, value) in stopStickerTray where key > index {
            rebuilt[key - 1] = value
        }
        stopStickerTray = rebuilt
        adjustmentNotes = ["スポットを削除しました。"]
    }

    func selectMeetingPlace(_ place: MeetingPlace) {
        meetingPlace = place
    }

    var meetingTime: Date? {
        guard let meetingPlace else { return nil }
        return meetingTime(for: meetingPlace)
    }

    func meetingTime(for place: MeetingPlace) -> Date? {
        MeetingPlaceSuggestor.suggestedMeetingTime(for: place, stops: stops)
    }

    func meetingTravelMinutes(for place: MeetingPlace) -> Int {
        MeetingPlaceSuggestor.travelToTargetMinutes(for: place, stops: stops)
    }

    func meetingTargetLabel(for place: MeetingPlace) -> String? {
        MeetingPlaceSuggestor.targetStopLabel(for: place, stops: stops.map { $0.toPatternStop() })
    }

    func mealSearchContext(for kind: MealKind) -> MealSearchContext {
        let neighbors = MealPlaceSuggestor.mealNeighbors(at: mealTime(kind), in: stops)
        return MealSearchContext(
            before: neighbors.before?.event,
            after: neighbors.after?.event,
            mealDurationMinutes: 70,
            availableGapMinutes: neighbors.gapMinutes
        )
    }

    func addMeetingPlace(_ place: MeetingPlace) {
        if !meetingPlaceOptions.contains(where: { $0.id == place.id }) {
            meetingPlaceOptions.append(place)
        }
        meetingPlace = place
    }

    func removeMeetingPlaceSticker(_ place: MeetingPlace) {
        meetingPlaceOptions.removeAll { $0.id == place.id }
        if meetingPlace?.id == place.id {
            meetingPlace = meetingPlaceOptions.first
        }
    }

    func stickers(forStop index: Int, catalog: [OutingEvent]) -> [OutingEvent] {
        if let custom = stopStickerTray[index] {
            return StickerDeduper.unique(custom)
        }
        let defaults = ItineraryScheduler.alternatives(
            for: stops,
            at: index,
            catalog: catalog,
            station: window.resolvedStation ?? TokyoStationCatalog.resolve(anchorStationName ?? "")
        )
        // Also avoid titles already shown on other stop trays.
        var reserved = Set(stops.map { StickerDeduper.normalizedTitle($0.event.title) })
        for (otherIndex, list) in stopStickerTray where otherIndex != index {
            for event in list {
                reserved.insert(StickerDeduper.normalizedTitle(event.title))
            }
        }
        let unique = StickerDeduper.unique(defaults, excludingTitles: reserved)
        stopStickerTray[index] = unique
        return unique
    }

    func addStopSticker(_ event: OutingEvent, at index: Int) {
        var list = stopStickerTray[index] ?? []
        let title = StickerDeduper.normalizedTitle(event.title)
        if list.contains(where: {
            $0.id == event.id || StickerDeduper.normalizedTitle($0.title) == title
        }) {
            return
        }
        list.insert(event, at: 0)
        stopStickerTray[index] = StickerDeduper.unique(list)
    }

    func removeStopSticker(_ event: OutingEvent, at index: Int) {
        stopStickerTray[index]?.removeAll { $0.id == event.id }
    }

    func mealStickers(for kind: MealKind) -> [OutingEvent] {
        StickerDeduper.unique(mealStickerTray[kind] ?? [])
    }

    func addMealSticker(_ event: OutingEvent, kind: MealKind) {
        var list = mealStickerTray[kind] ?? []
        let title = StickerDeduper.normalizedTitle(event.title)
        if list.contains(where: {
            $0.id == event.id || StickerDeduper.normalizedTitle($0.title) == title
        }) {
            return
        }
        // Don't mirror the same shop onto the other meal tray.
        for other in MealKind.allCases where other != kind {
            if mealStickerTray[other]?.contains(where: {
                $0.id == event.id || StickerDeduper.normalizedTitle($0.title) == title
            }) == true {
                mealStickerTray[other]?.removeAll {
                    $0.id == event.id || StickerDeduper.normalizedTitle($0.title) == title
                }
            }
        }
        list.insert(event, at: 0)
        mealStickerTray[kind] = StickerDeduper.unique(list)
    }

    func removeMealSticker(_ event: OutingEvent, kind: MealKind) {
        mealStickerTray[kind]?.removeAll { $0.id == event.id }
    }

    func mealEnabled(_ kind: MealKind) -> Bool {
        switch kind {
        case .lunch: return window.lunchEnabled
        case .dinner: return window.dinnerEnabled
        }
    }

    func mealTime(_ kind: MealKind) -> Date {
        switch kind {
        case .lunch: return window.lunchTime
        case .dinner: return window.dinnerTime
        }
    }

    func applyMeal(_ event: OutingEvent, kind: MealKind) {
        addMealSticker(event, kind: kind)
        let time = mealTime(kind)
        let duration = max(55, min(90, event.resolvedDurationMinutes))
        let end = time.addingTimeInterval(TimeInterval(duration * 60))

        if let existing = stops.firstIndex(where: { $0.isMealStop && mealKind(for: $0) == kind }) {
            stops[existing].event = event
            stops[existing].id = "meal-\(kind.rawValue)-\(event.id)"
            adjustmentNotes = ItineraryScheduler.setStart(&stops, at: existing, to: time, window: window)
            return
        }

        let mealStop = EditableStop(
            id: "meal-\(kind.rawValue)-\(event.id)",
            event: event,
            scheduledStart: time,
            scheduledEnd: end,
            isMealStop: true
        )

        let insertIndex = stops.firstIndex { $0.scheduledStart >= time } ?? stops.count
        stops.insert(mealStop, at: insertIndex)
        adjustmentNotes = ItineraryScheduler.setStart(
            &stops,
            at: insertIndex,
            to: time,
            window: window
        )
        if adjustmentNotes.isEmpty {
            adjustmentNotes = ["\(kind.label)に「\(event.title)」を追加しました。"]
        }
    }

    func removeMeal(kind: MealKind) {
        stops.removeAll { $0.isMealStop && mealKind(for: $0) == kind }
        adjustmentNotes = ["\(kind.label)を行程から削除しました。"]
    }

    private func mealKind(for stop: EditableStop) -> MealKind? {
        if stop.id.contains("lunch") { return .lunch }
        if stop.id.contains("dinner") { return .dinner }
        return stop.isMealStop ? .lunch : nil
    }

    func toPattern() -> OutingPattern {
        OutingPattern(
            id: id,
            title: title,
            subtitle: subtitle,
            styleLabel: styleLabel,
            stops: stops.map { $0.toPatternStop() },
            anchorStationName: anchorStationName,
            anchorStationCoordinate: anchorStationCoordinate,
            meetingPlace: meetingPlace
        )
    }
}
