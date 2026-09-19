//
//  MeetingPlace.swift
//  OutingPlanner
//

import CoreLocation
import Foundation

struct MeetingPlace: Identifiable, Hashable {
    let id: String
    let name: String
    let detail: String
    let reason: String
    let coordinate: CLLocationCoordinate2D?

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: MeetingPlace, rhs: MeetingPlace) -> Bool {
        lhs.id == rhs.id
    }
}

enum MealKind: String, CaseIterable, Identifiable {
    case lunch
    case dinner

    var id: String { rawValue }

    var label: String {
        switch self {
        case .lunch: "昼食"
        case .dinner: "夕食"
        }
    }

    var defaultHour: Int {
        switch self {
        case .lunch: 12
        case .dinner: 18
        }
    }

    var defaultMinute: Int {
        switch self {
        case .lunch: 30
        case .dinner: 30
        }
    }
}

enum MeetingPlaceSuggestor {
    private static let stationExits: [String: [(id: String, name: String, detail: String)]] = [
        "池袋": [
            ("ike-e", "池袋駅東口", "サンシャイン方面の待ち合わせに便利"),
            ("ike-w", "池袋駅西口", "西口公園前で目立ちやすい"),
            ("ike-metro", "池袋駅メトロポリタン口", "ホテル前でわかりやすい")
        ],
        "渋谷": [
            ("sby-hachi", "渋谷駅ハチ公口", "定番の待ち合わせ場所"),
            ("sby-scr", "スクランブル交差点前", "写真映えも狙える"),
            ("sby-sky", "渋谷スクランブルスクエア前", "雨の日も屋根があり安心")
        ],
        "新宿": [
            ("sjk-alta", "新宿駅アルタ前", "東口の定番"),
            ("sjk-south", "新宿駅南口", "ルミネ方面に近い"),
            ("sjk-west", "新宿駅西口広場", "都庁方面の出発に便利")
        ],
        "上野": [
            ("uen-park", "上野駅公園口", "動物園・美術館方面"),
            ("uen-hiro", "上野駅広小路口", "アメ横に近い"),
            ("uen-central", "上野駅中央改札外", "迷いにくい")
        ],
        "東京": [
            ("tok-maru", "東京駅丸の内中央口", "駅舎前の定番"),
            ("tok-yaesu", "東京駅八重洲口", "グランスタ利用に便利"),
            ("tok-gran", "グランルーフ下", "雨の日の待ち合わせ向き")
        ],
        "吉祥寺": [
            ("kic-park", "吉祥寺駅公園口", "井の頭公園方面"),
            ("kic-central", "吉祥寺駅中央口", "ハモニカ横丁に近い")
        ],
        "浅草": [
            ("asa-kaminari", "雷門前", "観光の定番集合場所"),
            ("asa-station", "浅草駅前", "電車利用者にわかりやすい")
        ],
        "六本木": [
            ("rop-hills", "六本木ヒルズけやき坂入口", "ヒルズ利用者向け"),
            ("rop-station", "六本木駅麻布方面改札", "地下鉄利用者向け")
        ]
    ]

    static func primary(for pattern: OutingPattern, station: TokyoStation?) -> MeetingPlace {
        alternatives(for: pattern, station: station).first
            ?? MeetingPlace(
                id: "fallback",
                name: "最初のスポット入口",
                detail: pattern.stops.first?.event.venue ?? pattern.stops.first?.event.area ?? "現地",
                reason: "プラン最初の場所で合流",
                coordinate: pattern.stops.first?.coordinate
            )
    }

    static func alternatives(for pattern: OutingPattern, station: TokyoStation?) -> [MeetingPlace] {
        var places: [MeetingPlace] = []

        if let station {
            let exits = stationExits[station.name] ?? [
                ("gen-central", "\(station.name)駅改札外", "駅利用者にわかりやすい場所")
            ]
            for exit in exits {
                places.append(
                    MeetingPlace(
                        id: "station-\(station.id)-\(exit.id)",
                        name: exit.name,
                        detail: exit.detail,
                        reason: "最寄駅での集合",
                        coordinate: station.coordinate
                    )
                )
            }
        }

        if let first = pattern.stops.first {
            places.append(
                MeetingPlace(
                    id: "first-\(first.event.id)",
                    name: "\(first.event.title)の入口",
                    detail: first.event.venue ?? first.event.area,
                    reason: "最初の予定地で合流",
                    coordinate: first.coordinate
                )
            )
        }

        if pattern.stops.count >= 2,
           let mid = pattern.stops[safe: pattern.stops.count / 2] {
            places.append(
                MeetingPlace(
                    id: "mid-\(mid.event.id)",
                    name: "\(mid.event.area)で合流",
                    detail: mid.event.venue ?? mid.event.title,
                    reason: "行程の中盤でも集まりやすい",
                    coordinate: mid.coordinate
                )
            )
        }

        // Unique by name and similar detail (avoid near-identical stickers).
        var seen = Set<String>()
        return places.filter { place in
            let key = "\(place.name)|\(place.detail)"
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "　", with: "")
            return seen.insert(key).inserted
        }
    }

    /// Suggested meet-up time so the group can reach the relevant stop on time.
    static func suggestedMeetingTime(
        for place: MeetingPlace,
        stops: [PatternStop]
    ) -> Date? {
        guard let target = targetStop(for: place, in: stops) else { return nil }
        let travel = ItineraryScheduler.travelMinutes(from: place.coordinate, to: target.event)
        let gatherBuffer = place.id.hasPrefix("first-") ? 5 : 0
        let raw = target.scheduledStart.addingTimeInterval(TimeInterval(-(travel + gatherBuffer) * 60))
        return roundDownToFiveMinutes(raw)
    }

    static func suggestedMeetingTime(
        for place: MeetingPlace,
        stops: [EditableStop]
    ) -> Date? {
        suggestedMeetingTime(for: place, stops: stops.map { $0.toPatternStop() })
    }

    /// Minutes from meeting place to the stop the group heads to next.
    static func travelToTargetMinutes(
        for place: MeetingPlace,
        stops: [PatternStop]
    ) -> Int {
        guard let target = targetStop(for: place, in: stops) else { return 0 }
        return ItineraryScheduler.travelMinutes(from: place.coordinate, to: target.event)
    }

    static func travelToTargetMinutes(
        for place: MeetingPlace,
        stops: [EditableStop]
    ) -> Int {
        travelToTargetMinutes(for: place, stops: stops.map { $0.toPatternStop() })
    }

    static func targetStopLabel(
        for place: MeetingPlace,
        stops: [PatternStop]
    ) -> String? {
        targetStop(for: place, in: stops)?.event.title
    }

    private static func targetStop(
        for place: MeetingPlace,
        in stops: [PatternStop]
    ) -> PatternStop? {
        if place.id.hasPrefix("mid-"),
           let matched = stops.first(where: { place.id.contains($0.event.id) }) {
            return matched
        }
        if place.id.hasPrefix("first-"),
           let matched = stops.first(where: { place.id.contains($0.event.id) }) {
            return matched
        }
        return stops.first
    }

    private static func roundDownToFiveMinutes(_ date: Date) -> Date {
        let calendar = Calendar.current
        let minute = calendar.component(.minute, from: date)
        let floored = minute - (minute % 5)
        return calendar.date(
            bySettingHour: calendar.component(.hour, from: date),
            minute: floored,
            second: 0,
            of: date
        ) ?? date
    }
}

enum MealPlaceSuggestor {
    static func suggest(
        kind: MealKind,
        at mealTime: Date,
        for pattern: OutingPattern,
        restaurants: [OutingEvent],
        station: TokyoStation?,
        limit: Int = 6
    ) -> [OutingEvent] {
        let neighbors = mealNeighbors(at: mealTime, in: pattern.stops)
        let context = MealSearchContext(
            before: neighbors.before?.event,
            after: neighbors.after?.event,
            mealDurationMinutes: 70,
            availableGapMinutes: neighbors.gapMinutes
        )

        let used = Set(pattern.stops.map(\.event.id))
        let usedTitles = Set(pattern.stops.map { StickerDeduper.normalizedTitle($0.event.title) })
        let ranked = restaurants
            .filter { $0.genres.contains("グルメ") || $0.source == .tabelog || $0.id.hasPrefix("rst-") }
            .filter { !used.contains($0.id) }
            .filter { !usedTitles.contains(StickerDeduper.normalizedTitle($0.title)) }
            .map { restaurant -> (OutingEvent, Int) in
                var score = RestaurantSearch.itineraryFitScore(restaurant, context: context)

                if let station,
                   let distance = GeoHelper.distanceKm(from: restaurant, to: station),
                   distance < 2.5 {
                    score += 10
                }
                if kind == .dinner,
                   restaurant.title.contains("ディナー")
                    || restaurant.title.contains("夜")
                    || FoodCuisine.detected(in: restaurant).contains(.yakiniku)
                    || FoodCuisine.detected(in: restaurant).contains(.yakitori) {
                    score += 6
                }
                if kind == .lunch,
                   restaurant.title.contains("ランチ")
                    || restaurant.title.contains("昼")
                    || FoodCuisine.detected(in: restaurant).contains(.soba)
                    || FoodCuisine.detected(in: restaurant).contains(.teishoku) {
                    score += 6
                }
                return (restaurant, score)
            }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
            .map(\.0)

        return Array(StickerDeduper.unique(ranked).prefix(limit))
    }

    static func mealNeighbors(
        at mealTime: Date,
        in stops: [PatternStop]
    ) -> (before: PatternStop?, after: PatternStop?, gapMinutes: Int?) {
        let nonMeal = stops.filter { !$0.isMealStop }
        let before = nonMeal.last { $0.scheduledEnd <= mealTime }
            ?? nonMeal.last { $0.scheduledStart < mealTime }
        let after = nonMeal.first { $0.scheduledStart >= mealTime }
            ?? nonMeal.first { $0.scheduledEnd > mealTime && $0.scheduledStart > mealTime }

        let gap: Int?
        if let before, let after {
            gap = max(0, Int(after.scheduledStart.timeIntervalSince(before.scheduledEnd) / 60))
        } else {
            gap = nil
        }
        return (before, after, gap)
    }

    static func mealNeighbors(
        at mealTime: Date,
        in stops: [EditableStop]
    ) -> (before: EditableStop?, after: EditableStop?, gapMinutes: Int?) {
        let mapped = mealNeighbors(at: mealTime, in: stops.map { $0.toPatternStop() })
        let before = mapped.before.flatMap { target in
            stops.first { $0.id == target.id }
        }
        let after = mapped.after.flatMap { target in
            stops.first { $0.id == target.id }
        }
        return (before, after, mapped.gapMinutes)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
