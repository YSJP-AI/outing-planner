//
//  SlotProposalEngine.swift
//  OutingPlanner
//

import Foundation

enum SlotProposalEngine {
    /// Build several multi-stop outing patterns for the requested window.
    static func proposePatterns(
        for slot: TimeSlotRequest,
        from events: [OutingEvent],
        filters: OutingFilters,
        existingPlans: [OutingPlan],
        limit: Int = 8
    ) -> [OutingPattern] {
        guard slot.isValid else { return [] }

        var slot = slot
        if slot.purpose == .unspecified {
            slot.purpose = filters.purpose
        }

        // Slot proposals should not inherit Home genre/area chips — those shrink variety.
        var slotFilters = OutingFilters()
        slotFilters.purpose = slot.purpose
        slotFilters.maxBudget = filters.maxBudget
        slotFilters.maxDurationMinutes = filters.maxDurationMinutes
        slotFilters.weekendOnly = false

        let station = slot.resolvedStation
        let filtered = EventFilterService.filter(events, with: slotFilters)
        let plannedIds = Set(existingPlans.map(\.eventId))
        let eligible = filtered
            .filter { !plannedIds.contains($0.id) }
            .filter { isCompatible($0, with: slot) }

        let pool = prioritizedPool(eligible, station: station, slot: slot)

        guard pool.count >= 2 else {
            return pool.prefix(limit).enumerated().map { index, event in
                anchored(
                    makeSingle(
                        id: "pattern-single-\(index)",
                        title: "単発プラン",
                        subtitle: "候補が少ないため1件提案",
                        styleLabel: "単発",
                        event: event,
                        slot: slot
                    ),
                    station: station
                )
            }
        }

        let stopBudget = maxStops(for: slot.durationMinutes)
        let maxPerStop = maxPackMinutes(for: slot.durationMinutes, stops: stopBudget)

        var patterns: [OutingPattern] = []
        var seenSignatures: Set<String> = []
        var usedEventCounts: [String: Int] = [:]

        func overlapScore(_ pattern: OutingPattern) -> Int {
            pattern.stops.reduce(0) { $0 + (usedEventCounts[$1.event.id] ?? 0) }
        }

        func append(_ pattern: OutingPattern?) {
            guard var pattern, pattern.stops.count >= 2 else { return }
            guard hasAdequateTravel(pattern) else { return }
            if let station, !isLocalEnough(pattern, to: station) { return }

            // Prefer distinct event sets; allow light overlap across patterns.
            if overlapScore(pattern) >= 3 { return }

            let signature = pattern.stops.map(\.event.id).sorted().joined(separator: "|")
            guard !seenSignatures.contains(signature) else { return }

            // Also reject near-identical title sets (same shops under different ids).
            let titleSignature = pattern.stops
                .map { StickerDeduper.normalizedTitle($0.event.title) }
                .sorted()
                .joined(separator: "|")
            guard !seenSignatures.contains("titles:\(titleSignature)") else { return }
            seenSignatures.insert(signature)
            seenSignatures.insert("titles:\(titleSignature)")
            pattern = anchored(pattern, station: station)
            patterns.append(pattern)
            for stop in pattern.stops {
                usedEventCounts[stop.event.id, default: 0] += 1
            }
        }

        let recipes: [RouteRecipe] = makeRecipes(
            station: station,
            slot: slot,
            stopBudget: stopBudget,
            maxPerStop: maxPerStop
        )

        for recipe in recipes {
            if patterns.count >= limit { break }
            let avoid = Set(usedEventCounts.keys)
            append(
                buildRoute(
                    id: recipe.id,
                    title: recipe.title,
                    subtitle: recipe.subtitle,
                    styleLabel: recipe.styleLabel,
                    from: recipe.orderedPool(from: pool),
                    slot: slot,
                    station: station,
                    targetStops: recipe.targetStops,
                    maxPerStop: recipe.maxPerStop,
                    preferNearbyAreas: recipe.preferNearby,
                    requireGenreVariety: recipe.requireGenreVariety,
                    avoidEventIds: avoid,
                    seedOffset: recipe.seedOffset,
                    preferredGenres: recipe.preferredGenres
                )
            )
        }

        if patterns.count < limit {
            let extras = generateExtraCombos(
                from: pool,
                slot: slot,
                station: station,
                maxPerStop: maxPerStop,
                excluding: seenSignatures,
                usedEventCounts: usedEventCounts,
                needed: limit - patterns.count
            )
            for pattern in extras {
                append(pattern)
            }
        }

        if patterns.isEmpty {
            append(
                buildRoute(
                    id: "combo-fallback",
                    title: "おまかせ2スポット",
                    subtitle: "空き枠に収まる組み合わせ",
                    styleLabel: "おまかせ",
                    from: pool,
                    slot: slot,
                    station: station,
                    targetStops: 2,
                    maxPerStop: maxPerStop,
                    preferNearbyAreas: true,
                    avoidEventIds: [],
                    seedOffset: 0
                )
            )
        }

        return Array(patterns.prefix(limit)).map { flavored($0, purpose: slot.purpose) }
    }

    private static func flavored(_ pattern: OutingPattern, purpose: OutingPurpose) -> OutingPattern {
        guard let flavor = OutingPurposeScorer.patternFlavor(purpose: purpose) else {
            return pattern
        }
        return OutingPattern(
            id: pattern.id,
            title: "\(flavor.titlePrefix)\(pattern.title)",
            subtitle: "\(flavor.styleHint) · \(pattern.subtitle)",
            styleLabel: flavor.styleHint,
            stops: pattern.stops,
            anchorStationName: pattern.anchorStationName,
            anchorStationCoordinate: pattern.anchorStationCoordinate,
            meetingPlace: pattern.meetingPlace
        )
    }

    // MARK: - Recipes for variety

    private struct RouteRecipe {
        let id: String
        let title: String
        let subtitle: String
        let styleLabel: String
        let targetStops: Int
        let maxPerStop: Int
        let preferNearby: Bool
        let requireGenreVariety: Bool
        let seedOffset: Int
        let preferredGenres: [String]
        let poolTransform: ([OutingEvent]) -> [OutingEvent]

        func orderedPool(from pool: [OutingEvent]) -> [OutingEvent] {
            poolTransform(pool)
        }
    }

    private static func makeRecipes(
        station: TokyoStation?,
        slot: TimeSlotRequest,
        stopBudget: Int,
        maxPerStop: Int
    ) -> [RouteRecipe] {
        let stationName = station?.name
        var recipes: [RouteRecipe] = []

        if let stationName {
            recipes.append(
                RouteRecipe(
                    id: "combo-station-near",
                    title: "\(stationName)駅周辺のおすすめ",
                    subtitle: "駅から近いスポットを中心にしたコース",
                    styleLabel: "駅周辺",
                    targetStops: min(3, stopBudget),
                    maxPerStop: maxPerStop,
                    preferNearby: true,
                    requireGenreVariety: true,
                    seedOffset: 0,
                    preferredGenres: [],
                    poolTransform: { $0 }
                )
            )
        }

        recipes.append(contentsOf: [
            RouteRecipe(
                id: "combo-food-first",
                title: stationName.map { "\($0)で食事からはじめる" } ?? "食事からはじめるコース",
                subtitle: "グルメを先に入れて、そのあと別ジャンルへ",
                styleLabel: "食事メイン",
                targetStops: 2,
                maxPerStop: maxPerStop,
                preferNearby: true,
                requireGenreVariety: true,
                seedOffset: 0,
                preferredGenres: ["グルメ"],
                poolTransform: { prioritizeGenres(["グルメ"], in: $0) }
            ),
            RouteRecipe(
                id: "combo-culture",
                title: stationName.map { "\($0)で文化を楽しむ" } ?? "文化を楽しむコース",
                subtitle: "美術館・エンタメ系を軸にしたコース",
                styleLabel: "文化",
                targetStops: 2,
                maxPerStop: maxPerStop,
                preferNearby: true,
                requireGenreVariety: true,
                seedOffset: 1,
                preferredGenres: ["アート", "エンタメ"],
                poolTransform: { prioritizeGenres(["アート", "エンタメ"], in: $0) }
            ),
            RouteRecipe(
                id: "combo-instagram",
                title: stationName.map { "\($0)で映えを回収" } ?? "Instagram映えコース",
                subtitle: "SNSで話題のスポットを中心にした今っぽい回り方",
                styleLabel: "映え",
                targetStops: min(3, stopBudget),
                maxPerStop: maxPerStop,
                preferNearby: true,
                requireGenreVariety: true,
                seedOffset: 3,
                preferredGenres: ["映え", "アート"],
                poolTransform: { pool in
                    let viral = pool.filter {
                        $0.genres.contains("映え")
                            || $0.source == .instagram
                            || $0.source == .trend
                    }
                    return viral.isEmpty ? prioritizeGenres(["映え", "アート"], in: pool) : viral + pool
                }
            ),
            RouteRecipe(
                id: "combo-outdoor",
                title: stationName.map { "\($0)のそと歩き" } ?? "そと歩きコース",
                subtitle: "公園や散策を中心に、休憩どころも挟む",
                styleLabel: "散策",
                targetStops: min(3, stopBudget),
                maxPerStop: maxPerStop,
                preferNearby: true,
                requireGenreVariety: true,
                seedOffset: 2,
                preferredGenres: ["自然"],
                poolTransform: { prioritizeGenres(["自然"], in: $0) }
            ),
            RouteRecipe(
                id: "combo-budget",
                title: "費用を抑えたコース",
                subtitle: "無料〜低予算のスポットを組み合わせ",
                styleLabel: "節約",
                targetStops: min(3, stopBudget),
                maxPerStop: maxPerStop,
                preferNearby: true,
                requireGenreVariety: false,
                seedOffset: 0,
                preferredGenres: [],
                poolTransform: { pool in
                    let budget = pool.filter(isBudgetFriendly)
                    return budget.count >= 2 ? budget : pool
                }
            ),
            RouteRecipe(
                id: "combo-short-long",
                title: "短時間＋しっかり滞在",
                subtitle: "短めのスポットのあとにメインを置く",
                styleLabel: "メリハリ",
                targetStops: 2,
                maxPerStop: max(maxPerStop, 100),
                preferNearby: true,
                requireGenreVariety: true,
                seedOffset: 0,
                preferredGenres: [],
                poolTransform: { $0.sorted { $0.resolvedDurationMinutes < $1.resolvedDurationMinutes } }
            ),
            RouteRecipe(
                id: "combo-shopping",
                title: stationName.map { "\($0)で買い物とひと息" } ?? "買い物とひと息",
                subtitle: "ショッピングと休憩・食事の組み合わせ",
                styleLabel: "買い物",
                targetStops: 2,
                maxPerStop: maxPerStop,
                preferNearby: true,
                requireGenreVariety: true,
                seedOffset: 1,
                preferredGenres: ["ショッピング"],
                poolTransform: { prioritizeGenres(["ショッピング", "グルメ"], in: $0) }
            ),
            RouteRecipe(
                id: "combo-experience",
                title: stationName.map { "\($0)で体験・エンタメ" } ?? "体験・エンタメコース",
                subtitle: "体験やエンタメを軸にした回り方",
                styleLabel: "体験",
                targetStops: 2,
                maxPerStop: maxPerStop,
                preferNearby: true,
                requireGenreVariety: true,
                seedOffset: 2,
                preferredGenres: ["体験", "エンタメ", "祭り"],
                poolTransform: { prioritizeGenres(["体験", "エンタメ", "祭り"], in: $0) }
            ),
            RouteRecipe(
                id: "combo-alt-seed",
                title: "別の組み合わせ",
                subtitle: "いつもと違う並びのおすすめ",
                styleLabel: "別案",
                targetStops: 2,
                maxPerStop: maxPerStop,
                preferNearby: true,
                requireGenreVariety: true,
                seedOffset: 3,
                preferredGenres: [],
                poolTransform: { Array($0.dropFirst(min(3, max(0, $0.count - 2)))) + Array($0.prefix(3)) }
            ),
            RouteRecipe(
                id: "combo-farther-seed",
                title: "少し足を伸ばす案",
                subtitle: "駅周辺から少し離れた候補も混ぜた別ルート",
                styleLabel: "拡張",
                targetStops: 2,
                maxPerStop: maxPerStop,
                preferNearby: false,
                requireGenreVariety: true,
                seedOffset: 4,
                preferredGenres: [],
                poolTransform: { Array($0.reversed()) }
            )
        ])

        if stopBudget >= 3, slot.durationMinutes >= 210 {
            recipes.append(
                RouteRecipe(
                    id: "combo-three",
                    title: "3スポットゆったり回り",
                    subtitle: "移動時間を確保した3か所コース",
                    styleLabel: "じっくり",
                    targetStops: 3,
                    maxPerStop: min(70, maxPerStop),
                    preferNearby: true,
                    requireGenreVariety: true,
                    seedOffset: 1,
                    preferredGenres: [],
                    poolTransform: { $0.sorted { $0.resolvedDurationMinutes < $1.resolvedDurationMinutes } }
                )
            )
        }

        return recipes
    }

    private static func prioritizeGenres(_ genres: [String], in pool: [OutingEvent]) -> [OutingEvent] {
        let preferred = pool.filter { !Set($0.genres).isDisjoint(with: Set(genres)) }
        let others = pool.filter { Set($0.genres).isDisjoint(with: Set(genres)) }
        return preferred + others
    }

    // MARK: - Route builders

    private static func buildRoute(
        id: String,
        title: String,
        subtitle: String,
        styleLabel: String,
        from pool: [OutingEvent],
        slot: TimeSlotRequest,
        station: TokyoStation? = nil,
        targetStops: Int,
        maxPerStop: Int,
        preferNearbyAreas: Bool,
        requireGenreVariety: Bool = false,
        avoidEventIds: Set<String>,
        seedOffset: Int,
        preferredGenres: [String] = []
    ) -> OutingPattern? {
        guard targetStops >= 2, pool.count >= 2 else { return nil }

        let rotated: [OutingEvent]
        if seedOffset == 0 || pool.count <= seedOffset {
            rotated = pool
        } else {
            rotated = Array(pool[seedOffset...]) + Array(pool[..<seedOffset])
        }

        // Soft-avoid already used events by pushing them later.
        let ordered = rotated.sorted { lhs, rhs in
            let lUsed = avoidEventIds.contains(lhs.id)
            let rUsed = avoidEventIds.contains(rhs.id)
            if lUsed != rUsed { return !lUsed && rUsed }
            return false
        }

        var chosen: [OutingEvent] = []
        var remaining = ordered

        let first = pickFirstStop(
            from: remaining,
            station: station,
            preferredGenres: preferredGenres,
            avoidEventIds: avoidEventIds
        )

        guard let first else { return nil }
        chosen.append(first)
        remaining.removeAll { $0.id == first.id }

        while chosen.count < targetStops {
            let previous = chosen.last!
            let usedGenres = Set(chosen.flatMap(\.genres))

            let candidates = remaining.filter { candidate in
                let travel = ItineraryScheduler.travelMinutes(from: previous, to: candidate)
                if travel >= 45, slot.durationMinutes < 210 { return false }
                if let station,
                   let distance = GeoHelper.distanceKm(from: candidate, to: station),
                   distance > stationHardMaxKm {
                    return false
                }
                return true
            }

            let next: OutingEvent?
            if preferNearbyAreas {
                next = candidates.first {
                    isNearby(previous.area, $0.area)
                        && (!requireGenreVariety || Set($0.genres).isDisjoint(with: usedGenres))
                }
                    ?? candidates.first { isNearby(previous.area, $0.area) }
                    ?? candidates.first {
                        !requireGenreVariety || Set($0.genres).isDisjoint(with: usedGenres)
                    }
                    ?? candidates.first
            } else if requireGenreVariety {
                next = candidates.first { Set($0.genres).isDisjoint(with: usedGenres) }
                    ?? candidates.first
            } else {
                next = candidates.first
            }

            guard let next else { break }
            chosen.append(next)
            remaining.removeAll { $0.id == next.id }
        }

        guard chosen.count >= 2 else { return nil }
        return schedule(
            id: id,
            title: title,
            subtitle: subtitle,
            styleLabel: styleLabel,
            events: chosen,
            slot: slot,
            maxPerStop: maxPerStop
        )
    }

    /// Prefer a first stop within walking distance of the chosen station.
    private static func pickFirstStop(
        from remaining: [OutingEvent],
        station: TokyoStation?,
        preferredGenres: [String],
        avoidEventIds: Set<String>
    ) -> OutingEvent? {
        let usable = remaining.filter { !avoidEventIds.contains($0.id) }
        let base = usable.isEmpty ? remaining : usable

        func matchesGenre(_ event: OutingEvent) -> Bool {
            preferredGenres.isEmpty
                || !Set(event.genres).isDisjoint(with: Set(preferredGenres))
        }

        if let station {
            let near = base.compactMap { event -> (OutingEvent, Double)? in
                guard let distance = GeoHelper.distanceKm(from: event, to: station) else { return nil }
                return (event, distance)
            }
            .sorted { $0.1 < $1.1 }

            let anchor = near.filter { $0.1 <= stationAnchorRadiusKm }.map(\.0)
            let primary = near.filter { $0.1 <= stationPrimaryRadiusKm }.map(\.0)

            if let pick = anchor.first(where: matchesGenre) ?? anchor.first {
                return pick
            }
            if let pick = primary.first(where: matchesGenre) ?? primary.first {
                return pick
            }
            if let pick = near.first?.0 {
                return pick
            }
        }

        return base.first(where: matchesGenre) ?? base.first
    }

    private static func generateExtraCombos(
        from pool: [OutingEvent],
        slot: TimeSlotRequest,
        station: TokyoStation?,
        maxPerStop: Int,
        excluding: Set<String>,
        usedEventCounts: [String: Int],
        needed: Int
    ) -> [OutingPattern] {
        var results: [OutingPattern] = []
        var localSeen = excluding

        for i in 0..<pool.count {
            for j in (i + 1)..<pool.count {
                let a = pool[i]
                let b = pool[j]
                let overlap = (usedEventCounts[a.id] ?? 0) + (usedEventCounts[b.id] ?? 0)
                if overlap >= 3 { continue }
                if Set(a.genres).isDisjoint(with: Set(b.genres)) == false, overlap >= 2 {
                    continue
                }

                // Prefer pairs that both stay near the station when one is set.
                if let station {
                    let da = GeoHelper.distanceKm(from: a, to: station) ?? 99
                    let db = GeoHelper.distanceKm(from: b, to: station) ?? 99
                    if min(da, db) > stationPrimaryRadiusKm { continue }
                    if max(da, db) > stationHardMaxKm { continue }
                }

                let pair = daFirst(a, b, station: station)
                let signature = pair.map(\.id).sorted().joined(separator: "|")
                guard !localSeen.contains(signature) else { continue }

                if let pattern = schedule(
                    id: "combo-extra-\(signature)",
                    title: "\(pair[0].area)と\(pair[1].area)を組み合わせ",
                    subtitle: "\(pair[0].genres.first ?? "お出かけ")×\(pair[1].genres.first ?? "スポット")",
                    styleLabel: "別案",
                    events: pair,
                    slot: slot,
                    maxPerStop: maxPerStop
                ) {
                    localSeen.insert(signature)
                    results.append(pattern)
                    if results.count >= needed { return results }
                }
            }
        }
        return results
    }

    private static func daFirst(_ a: OutingEvent, _ b: OutingEvent, station: TokyoStation?) -> [OutingEvent] {
        guard let station else { return [a, b] }
        let da = GeoHelper.distanceKm(from: a, to: station) ?? 99
        let db = GeoHelper.distanceKm(from: b, to: station) ?? 99
        return da <= db ? [a, b] : [b, a]
    }

    private static func schedule(
        id: String,
        title: String,
        subtitle: String,
        styleLabel: String,
        events: [OutingEvent],
        slot: TimeSlotRequest,
        maxPerStop: Int
    ) -> OutingPattern? {
        guard events.count >= 2 else { return nil }

        // Use the same travel estimator as the detail editor.
        let buffers: [Int] = (0..<(events.count - 1)).map { index in
            ItineraryScheduler.travelMinutes(from: events[index], to: events[index + 1])
        }

        let candidates: [[Int]] = [
            events.map { min($0.resolvedDurationMinutes, maxPerStop) },
            events.map { min($0.resolvedDurationMinutes, max(50, maxPerStop - 15)) },
            events.map { min($0.resolvedDurationMinutes, 60) }
        ]

        for durations in candidates {
            let totalNeeded = durations.reduce(0, +) + buffers.reduce(0, +)
            guard totalNeeded <= slot.durationMinutes else { continue }

            if let pattern = finalizeSchedule(
                id: id,
                title: title,
                subtitle: subtitle,
                styleLabel: styleLabel,
                events: events,
                durations: durations,
                buffers: buffers,
                slot: slot
            ), hasAdequateTravel(pattern) {
                return pattern
            }
        }
        return nil
    }

    private static func finalizeSchedule(
        id: String,
        title: String,
        subtitle: String,
        styleLabel: String,
        events: [OutingEvent],
        durations: [Int],
        buffers: [Int],
        slot: TimeSlotRequest
    ) -> OutingPattern? {
        var cursor = slot.start
        var stops: [PatternStop] = []

        for (index, event) in events.enumerated() {
            let duration = durations[index]
            let end = cursor.addingTimeInterval(TimeInterval(duration * 60))
            // Never clip stays — if it doesn't fit, reject the whole schedule.
            guard end <= slot.end.addingTimeInterval(60) else { return nil }

            stops.append(
                PatternStop(
                    id: "\(id)-\(index)-\(event.id)",
                    event: event,
                    scheduledStart: cursor,
                    scheduledEnd: end
                )
            )
            cursor = end
            if index < buffers.count {
                cursor = cursor.addingTimeInterval(TimeInterval(buffers[index] * 60))
            }
        }

        guard let last = stops.last, last.scheduledEnd <= slot.end.addingTimeInterval(60) else {
            return nil
        }

        let route = stops.map(\.event.area).joined(separator: " → ")
        return OutingPattern(
            id: id,
            title: title,
            subtitle: "\(subtitle) / \(route)",
            styleLabel: styleLabel,
            stops: stops
        )
    }

    private static func hasAdequateTravel(_ pattern: OutingPattern) -> Bool {
        let editable = pattern.stops.map(EditableStop.init(from:))
        for index in 0..<(editable.count - 1) {
            let needed = ItineraryScheduler.requiredTravel(
                between: editable[index],
                and: editable[index + 1]
            )
            let gap = ItineraryScheduler.gapMinutes(
                between: editable[index],
                and: editable[index + 1]
            )
            if gap < needed { return false }
        }
        return true
    }

    private static func makeSingle(
        id: String,
        title: String,
        subtitle: String,
        styleLabel: String,
        event: OutingEvent,
        slot: TimeSlotRequest
    ) -> OutingPattern {
        let duration = min(event.resolvedDurationMinutes, slot.durationMinutes)
        let end = slot.start.addingTimeInterval(TimeInterval(duration * 60))
        return OutingPattern(
            id: id,
            title: title,
            subtitle: subtitle,
            styleLabel: styleLabel,
            stops: [
                PatternStop(
                    id: "\(id)-\(event.id)",
                    event: event,
                    scheduledStart: slot.start,
                    scheduledEnd: min(end, slot.end)
                )
            ]
        )
    }

    // MARK: - Area / pool helpers

    private static let areaGroups: [[String]] = [
        ["池袋", "雑司が谷", "目白", "南長崎"],
        // Keep Ueno and Asakusa separate so 「上野」plans don't drift to 浅草 as default.
        ["上野", "谷中", "御徒町", "湯島", "日暮里", "千駄木"],
        ["浅草", "蔵前", "両国", "押上"],
        ["秋葉原"],
        ["渋谷", "原宿", "表参道", "外苑", "代々木", "恵比寿", "代官山", "中目黒"],
        ["新宿", "中野", "高田馬場"],
        ["六本木", "麻布", "麻布台", "赤坂"],
        ["豊洲", "お台場", "有明"],
        ["丸の内", "銀座", "築地", "日本橋", "有楽町", "東京", "浜松町"],
        ["吉祥寺", "井の頭"],
        ["神楽坂", "飯田橋"],
        ["下北沢", "三軒茶屋", "自由が丘"],
        ["門前仲町", "清澄白河", "亀戸"],
        ["北千住"]
    ]

    private static func areaGroup(of area: String) -> Int? {
        areaGroups.firstIndex { group in
            group.contains { area.contains($0) }
        }
    }

    private static func isNearby(_ a: String, _ b: String) -> Bool {
        guard let ga = areaGroup(of: a), let gb = areaGroup(of: b) else {
            return a == b
        }
        return ga == gb
    }

    private static func maxStops(for durationMinutes: Int) -> Int {
        switch durationMinutes {
        case ..<150: return 2
        case 150..<240: return 2
        default: return 3
        }
    }

    private static func maxPackMinutes(for durationMinutes: Int, stops: Int) -> Int {
        let bufferReserve = max(0, stops - 1) * 20
        let share = max(45, (durationMinutes - bufferReserve) / max(stops, 1))
        return min(100, share)
    }

    private static func isCompatible(_ event: OutingEvent, with slot: TimeSlotRequest) -> Bool {
        if let eventStart = event.startAt, let eventEnd = event.endAt {
            return slot.start < eventEnd && eventStart < slot.end
        }
        return true
    }

    private static func score(_ event: OutingEvent, slot: TimeSlotRequest) -> Int {
        var value = timeOfDayScore(event, slot: slot)
        if isBudgetFriendly(event) { value += 6 }
        if areaGroup(of: event.area) != nil { value += 8 }
        if event.resolvedDurationMinutes <= 120 { value += 10 }
        value += OutingPurposeScorer.score(event, purpose: slot.purpose)

        let viralBoost = slot.resolvedStation == nil ? 14 : 4
        if event.genres.contains("映え") || event.source == .instagram || event.source == .trend {
            value += viralBoost
        }

        if let station = slot.resolvedStation {
            if event.area.contains(station.name) || station.name.contains(event.area) {
                value += 55
            }
            if let distance = GeoHelper.distanceKm(from: event, to: station) {
                switch distance {
                case ..<0.6: value += 100
                case ..<1.0: value += 85
                case ..<1.5: value += 65
                case ..<2.2: value += 35
                case ..<3.0: value += 10
                default: value -= 90
                }
            }
        }
        return value
    }

    private static let stationAnchorRadiusKm = 1.2
    private static let stationPrimaryRadiusKm = 1.6
    private static let stationExpandRadiusKm = 2.8
    private static let stationHardMaxKm = 4.0

    private static func prioritizedPool(
        _ events: [OutingEvent],
        station: TokyoStation?,
        slot: TimeSlotRequest
    ) -> [OutingEvent] {
        guard let station else {
            return events.sorted { score($0, slot: slot) > score($1, slot: slot) }
        }

        let scored = events.compactMap { event -> (OutingEvent, Double, Int)? in
            guard GeoHelper.hasReliableLocation(event),
                  let distance = GeoHelper.distanceKm(from: event, to: station) else {
                return nil
            }
            return (event, distance, score(event, slot: slot))
        }

        func sortedByDistance(_ items: [(OutingEvent, Double, Int)]) -> [OutingEvent] {
            items.sorted {
                if abs($0.1 - $1.1) > 0.2 { return $0.1 < $1.1 }
                return $0.2 > $1.2
            }.map(\.0)
        }

        let primary = scored.filter { $0.1 <= stationPrimaryRadiusKm }
        if primary.count >= 3 {
            return sortedByDistance(primary)
        }

        let expanded = scored.filter { $0.1 <= stationExpandRadiusKm }
        if expanded.count >= 2 {
            return sortedByDistance(expanded)
        }

        let hard = scored.filter { $0.1 <= stationHardMaxKm }
        if !hard.isEmpty {
            return Array(sortedByDistance(hard).prefix(16))
        }

        return Array(sortedByDistance(scored).prefix(8))
    }

    private static func isLocalEnough(_ pattern: OutingPattern, to station: TokyoStation) -> Bool {
        let distances = pattern.stops.compactMap { GeoHelper.distanceKm(from: $0.event, to: station) }
        guard distances.count == pattern.stops.count else { return false }
        guard distances.allSatisfy({ $0 <= stationHardMaxKm }) else { return false }
        guard let first = distances.first, first <= stationPrimaryRadiusKm + 0.4 else { return false }
        let average = distances.reduce(0, +) / Double(distances.count)
        return average <= 2.4
    }

    private static func anchored(_ pattern: OutingPattern, station: TokyoStation?) -> OutingPattern {
        var result = OutingPattern(
            id: pattern.id,
            title: pattern.title,
            subtitle: pattern.subtitle,
            styleLabel: pattern.styleLabel,
            stops: pattern.stops,
            anchorStationName: station?.name ?? pattern.anchorStationName,
            anchorStationCoordinate: station?.coordinate ?? pattern.anchorStationCoordinate,
            meetingPlace: pattern.meetingPlace
        )
        result.meetingPlace = MeetingPlaceSuggestor.primary(
            for: result,
            station: station ?? TokyoStationCatalog.resolve(result.anchorStationName ?? "")
        )
        return result
    }

    private static func isBudgetFriendly(_ event: OutingEvent) -> Bool {
        if event.priceText?.contains("無料") == true { return true }
        if let min = event.priceMin, min <= 1500 { return true }
        return false
    }

    private static func timeOfDayScore(_ event: OutingEvent, slot: TimeSlotRequest) -> Int {
        matchesTimeOfDay(event, slot: slot) ? 20 : 0
    }

    private static func matchesTimeOfDay(_ event: OutingEvent, slot: TimeSlotRequest) -> Bool {
        let hour = Calendar.current.component(.hour, from: slot.start)
        switch hour {
        case 9..<11:
            return event.genres.contains("自然") || event.genres.contains("アート")
        case 11..<15:
            return event.genres.contains("グルメ") || event.genres.contains("アート")
        case 15..<18:
            return event.genres.contains("ショッピング") || event.genres.contains("自然") || event.genres.contains("体験")
        default:
            return event.genres.contains("エンタメ") || event.genres.contains("グルメ")
                || event.title.contains("夜") || event.title.contains("ライトアップ")
        }
    }
}
