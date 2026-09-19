//
//  MapKitPlaceSearch.swift
//  OutingPlanner
//

import CoreLocation
import Foundation
import MapKit

/// Live place search via Apple MapKit (no API key). Used for restaurants and spot names.
enum MapKitPlaceSearch {
    private static let tokyoCenter = CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671)

    static func searchRestaurants(
        query: String,
        cuisine: FoodCuisine? = nil,
        near coordinate: CLLocationCoordinate2D?,
        areaHint: String? = nil,
        limit: Int = 20
    ) async -> [OutingEvent] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        var tokens: [String] = []
        if let cuisine { tokens.append(cuisine.rawValue) }
        if !trimmed.isEmpty {
            tokens.append(trimmed)
        } else if cuisine == nil {
            tokens.append("レストラン")
        } else {
            tokens.append("お店")
        }
        if let areaHint, !areaHint.isEmpty, trimmed.isEmpty {
            tokens.append(areaHint)
        }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = tokens.joined(separator: " ")
        request.resultTypes = [.pointOfInterest]
        let center = coordinate ?? tokyoCenter
        let meters: CLLocationDistance = trimmed.isEmpty ? 2200 : 3500
        request.region = MKCoordinateRegion(
            center: center,
            latitudinalMeters: meters,
            longitudinalMeters: meters
        )

        guard let response = try? await MKLocalSearch(request: request).start() else {
            return []
        }

        let foodCategories: Set<MKPointOfInterestCategory> = [
            .restaurant, .cafe, .bakery
        ]

        var results: [OutingEvent] = []
        for item in response.mapItems {
            let category = item.pointOfInterestCategory
            let name = item.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !name.isEmpty else { continue }

            let looksFood = category.map { foodCategories.contains($0) } ?? false
                || name.contains("食堂")
                || name.contains("料理")
                || name.contains("レストラン")
                || name.contains("カフェ")
                || name.contains("ラーメン")
                || name.contains("寿司")
                || name.contains("焼肉")
                || cuisine.map { name.contains($0.rawValue) } == true

            // When user typed a shop name, accept broader POI matches.
            if !trimmed.isEmpty {
                // keep
            } else if !looksFood {
                continue
            }

            if let event = makeEvent(
                from: item,
                cuisine: cuisine,
                areaHint: areaHint
            ) {
                results.append(event)
            }
            if results.count >= limit { break }
        }
        return results
    }

    static func searchSpots(
        query: String,
        near coordinate: CLLocationCoordinate2D?,
        areaHint: String? = nil,
        limit: Int = 20
    ) async -> [OutingEvent] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = [areaHint, trimmed]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        request.resultTypes = [.pointOfInterest, .address]
        let center = coordinate ?? tokyoCenter
        request.region = MKCoordinateRegion(
            center: center,
            latitudinalMeters: 4000,
            longitudinalMeters: 4000
        )

        guard let response = try? await MKLocalSearch(request: request).start() else {
            return []
        }

        return response.mapItems.prefix(limit).compactMap {
            makeEvent(from: $0, cuisine: nil, areaHint: areaHint, defaultGenre: "体験")
        }
    }

    private static func makeEvent(
        from item: MKMapItem,
        cuisine: FoodCuisine?,
        areaHint: String?,
        defaultGenre: String = "グルメ"
    ) -> OutingEvent? {
        guard let name = item.name?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty else { return nil }

        let coord = item.placemark.coordinate
        let area = areaHint
            ?? item.placemark.locality
            ?? item.placemark.subLocality
            ?? "東京"

        var genres = [defaultGenre]
        if let cuisine, !genres.contains(cuisine.rawValue) {
            genres.append(cuisine.rawValue)
        }

        var hasher = Hasher()
        hasher.combine(name)
        hasher.combine(coord.latitude)
        hasher.combine(coord.longitude)
        let digest = String(UInt(bitPattern: hasher.finalize()), radix: 16).prefix(10)

        let address = [
            item.placemark.administrativeArea,
            item.placemark.locality,
            item.placemark.thoroughfare
        ]
        .compactMap { $0 }
        .joined(separator: "")

        let url = item.url
            ?? RestaurantSearch.tabelogSearchURL(name: name, cuisine: cuisine, area: area)

        return OutingEvent(
            id: "mk-\(digest)",
            title: name,
            genres: genres,
            area: area,
            venue: address.isEmpty ? "Appleマップ" : address,
            startAt: nil,
            endAt: nil,
            durationMinutes: defaultGenre == "グルメ" ? 70 : 90,
            priceMin: nil,
            priceMax: nil,
            priceText: "料金は店舗で確認",
            source: .manual,
            sourceURL: url,
            summary: "Appleマップの検索結果です。詳細は地図・公式情報で確認してください。",
            lat: coord.latitude,
            lng: coord.longitude
        )
    }
}
