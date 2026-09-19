//
//  RestaurantSearch.swift
//  OutingPlanner
//

import CoreLocation
import Foundation

struct MealSearchContext {
    var before: OutingEvent?
    var after: OutingEvent?
    var mealDurationMinutes: Int
    var availableGapMinutes: Int?

    static let empty = MealSearchContext(
        before: nil,
        after: nil,
        mealDurationMinutes: 70,
        availableGapMinutes: nil
    )
}

enum RestaurantSearch {
    /// Search local restaurant catalog by shop name / cuisine / itinerary fit.
    static func search(
        query: String,
        cuisine: FoodCuisine? = nil,
        in restaurants: [OutingEvent],
        nearStation: TokyoStation? = nil,
        itinerary: MealSearchContext = .empty,
        limit: Int = 20
    ) -> [OutingEvent] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidates = restaurants.filter { event in
            guard event.genres.contains("グルメ")
                    || event.source == .tabelog
                    || event.id.hasPrefix("rst-")
                    || event.id.hasPrefix("custom-")
                    || event.id.hasPrefix("mk-") else {
                return false
            }
            if let cuisine {
                return FoodCuisine.detected(in: event).contains(cuisine)
                    || event.genres.contains(cuisine.rawValue)
                    || event.title.contains(cuisine.rawValue)
                    || (event.summary?.contains(cuisine.rawValue) ?? false)
            }
            return true
        }

        let ranked = candidates.map { event -> (OutingEvent, Int) in
            var score = itineraryFitScore(event, context: itinerary)

            if !trimmed.isEmpty {
                let textScore = nameScore(event, query: trimmed)
                if textScore == 0 {
                    return (event, 0)
                }
                score += textScore
            }

            if let station = nearStation,
               let distance = GeoHelper.distanceKm(from: event, to: station),
               distance < 3 {
                score += 8
            }

            return (event, score)
        }
        .filter { $0.1 > 0 }
        .sorted { $0.1 > $1.1 }
        .map(\.0)

        if ranked.isEmpty, trimmed.isEmpty, cuisine == nil {
            return Array(
                candidates
                    .sorted {
                        itineraryFitScore($0, context: itinerary)
                            > itineraryFitScore($1, context: itinerary)
                    }
                    .prefix(limit)
            )
        }

        return Array(ranked.prefix(limit))
    }

    /// Catalog + Apple Maps live results. Use this from search UI.
    static func searchWithMaps(
        query: String,
        cuisine: FoodCuisine? = nil,
        in restaurants: [OutingEvent],
        nearStation: TokyoStation? = nil,
        nearCoordinate: CLLocationCoordinate2D? = nil,
        areaHint: String? = nil,
        itinerary: MealSearchContext = .empty,
        limit: Int = 20
    ) async -> [OutingEvent] {
        let catalog = search(
            query: query,
            cuisine: cuisine,
            in: restaurants,
            nearStation: nearStation,
            itinerary: itinerary,
            limit: limit
        )

        let center = nearCoordinate
            ?? nearStation?.coordinate
            ?? itinerary.before.flatMap(GeoHelper.coordinate(for:))
            ?? itinerary.after.flatMap(GeoHelper.coordinate(for:))

        let live = await MapKitPlaceSearch.searchRestaurants(
            query: query,
            cuisine: cuisine,
            near: center,
            areaHint: areaHint ?? nearStation?.name,
            limit: limit
        )

        var seen = Set<String>()
        var merged: [OutingEvent] = []
        // Prefer live MapKit hits when the user typed a name; otherwise catalog-first.
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let primary = trimmed.isEmpty && cuisine == nil ? catalog + live : live + catalog
        for event in primary {
            let key = event.title.lowercased()
            if seen.contains(key) { continue }
            seen.insert(key)
            merged.append(event)
            if merged.count >= limit { break }
        }

        if merged.isEmpty {
            return catalog
        }
        return merged
    }

    /// Build a custom restaurant entry from a typed shop name (links to Tabelog search).
    static func makeCustomRestaurant(
        name: String,
        cuisine: FoodCuisine? = nil,
        area: String?,
        station: TokyoStation?,
        nearEvent: OutingEvent? = nil
    ) -> OutingEvent? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return nil }

        let resolvedArea = area?.isEmpty == false
            ? area!
            : (nearEvent?.area ?? station?.name ?? "東京")
        let keywords = [resolvedArea, cuisine?.rawValue, trimmed]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
        let query = keywords.joined(separator: " ")
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
        let url = URL(string: "https://tabelog.com/rstLst/?vs=1&sw=\(encoded)")
            ?? URL(string: "https://tabelog.com/")!

        let lat: Double?
        let lng: Double?
        if let near = nearEvent, let c = GeoHelper.coordinate(for: near) {
            lat = c.latitude
            lng = c.longitude
        } else {
            lat = station?.coordinate.latitude
            lng = station?.coordinate.longitude
        }

        let idSeed = "\(resolvedArea)-\(cuisine?.rawValue ?? "")-\(trimmed)".lowercased()
        var hasher = Hasher()
        hasher.combine(idSeed)
        let digest = String(UInt(bitPattern: hasher.finalize()), radix: 16).prefix(10)

        var genres = ["グルメ"]
        if let cuisine { genres.append(cuisine.rawValue) }

        return OutingEvent(
            id: "custom-\(digest)",
            title: trimmed,
            genres: genres,
            area: resolvedArea,
            venue: cuisine.map { "\($0.rawValue) · 食べログで検索" } ?? "食べログで検索",
            startAt: nil,
            endAt: nil,
            durationMinutes: 70,
            priceMin: nil,
            priceMax: nil,
            priceText: "料金は食べログで確認",
            source: .tabelog,
            sourceURL: url,
            summary: cuisine.map {
                "「\(trimmed)」（\($0.rawValue)）を食べログで探す候補です。"
            } ?? "「\(trimmed)」を食べログで探すための候補です。",
            lat: lat,
            lng: lng
        )
    }

    static func tabelogSearchURL(name: String, cuisine: FoodCuisine? = nil, area: String?) -> URL {
        let query = [area, cuisine?.rawValue, name]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
        return URL(string: "https://tabelog.com/rstLst/?vs=1&sw=\(encoded)")
            ?? URL(string: "https://tabelog.com/")!
    }

    /// Short travel note for UI (e.g. "前の予定から約15分").
    static func travelNote(for event: OutingEvent, context: MealSearchContext) -> String? {
        var parts: [String] = []
        if let before = context.before {
            let minutes = ItineraryScheduler.travelMinutes(from: before, to: event)
            parts.append("前から約\(minutes)分")
        }
        if let after = context.after {
            let minutes = ItineraryScheduler.travelMinutes(from: event, to: after)
            parts.append("次まで約\(minutes)分")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    // MARK: - Scoring

    private static func nameScore(_ event: OutingEvent, query: String) -> Int {
        var score = 0
        let title = event.title
        let area = event.area
        let venue = event.venue ?? ""
        let summary = event.summary ?? ""
        let cuisineText = FoodCuisine.labels(for: event).joined(separator: " ")

        if title == query { score += 100 }
        if title.contains(query) { score += 60 }
        if query.contains(title), title.count >= 2 { score += 40 }
        if area.contains(query) { score += 25 }
        if venue.contains(query) { score += 20 }
        if summary.contains(query) { score += 15 }
        if cuisineText.contains(query) { score += 35 }

        for token in query.split(whereSeparator: { $0.isWhitespace || $0 == "　" }) {
            let t = String(token)
            if title.contains(t) { score += 15 }
            if area.contains(t) { score += 8 }
            if cuisineText.contains(t) { score += 20 }
            if summary.contains(t) { score += 6 }
        }
        return score
    }

    /// Prefer restaurants that sit naturally between previous/next stops.
    static func itineraryFitScore(_ event: OutingEvent, context: MealSearchContext) -> Int {
        var score = 12
        let before = context.before
        let after = context.after

        let fromBefore = before.map { ItineraryScheduler.travelMinutes(from: $0, to: event) }
        let toAfter = after.map { ItineraryScheduler.travelMinutes(from: event, to: $0) }

        if let fromBefore {
            switch fromBefore {
            case ...10: score += 40
            case ...15: score += 30
            case ...25: score += 18
            case ...35: score += 5
            default: score -= 45
            }
        }

        if let toAfter {
            switch toAfter {
            case ...10: score += 40
            case ...15: score += 30
            case ...25: score += 18
            case ...35: score += 5
            default: score -= 45
            }
        }

        if let before, let after, let fromBefore, let toAfter {
            let direct = ItineraryScheduler.travelMinutes(from: before, to: after)
            let via = fromBefore + toAfter
            let detour = via - direct
            switch detour {
            case ...5: score += 35
            case ...15: score += 20
            case ...25: score += 5
            case ...40: score -= 25
            default: score -= 60
            }

            let needed = fromBefore + context.mealDurationMinutes + toAfter
            if let gap = context.availableGapMinutes, gap > 0, needed > gap + 10 {
                score -= 50
            }
        }

        // Same area as neighbors is a strong natural fit.
        if let before, event.area == before.area { score += 12 }
        if let after, event.area == after.area { score += 12 }

        return score
    }
}
