//
//  StationGeocoder.swift
//  OutingPlanner
//

import CoreLocation
import Foundation
import MapKit

/// Resolves free-text station names via catalog first, then MapKit for any Tokyo-area station.
enum StationGeocoder {
    private static let tokyoCenter = CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671)

    static func resolve(_ query: String) async -> TokyoStation? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let catalog = TokyoStationCatalog.resolve(trimmed) {
            return catalog
        }

        return await geocodeStation(trimmed)
    }

    private static func geocodeStation(_ query: String) async -> TokyoStation? {
        let normalized = query
            .replacingOccurrences(of: "　", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let searchName = normalized.contains("駅") ? normalized : "\(normalized)駅"

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchName
        request.resultTypes = [.pointOfInterest, .address]
        request.region = MKCoordinateRegion(
            center: tokyoCenter,
            span: MKCoordinateSpan(latitudeDelta: 0.55, longitudeDelta: 0.55)
        )

        guard let response = try? await MKLocalSearch(request: request).start() else {
            return nil
        }

        let candidates = response.mapItems.filter { item in
            let name = item.name ?? ""
            let lat = item.placemark.coordinate.latitude
            let lng = item.placemark.coordinate.longitude
            guard (35.45...35.90).contains(lat), (139.40...139.95).contains(lng) else {
                return false
            }
            return name.contains("駅")
                || name.contains(normalized)
                || item.pointOfInterestCategory == .publicTransport
        }

        let best = candidates.first { ($0.name ?? "").contains("駅") }
            ?? candidates.first
            ?? response.mapItems.first

        guard let best, let name = best.name else { return nil }

        let shortName = name
            .replacingOccurrences(of: "駅", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let idSeed = shortName.isEmpty ? name : shortName

        return TokyoStation(
            id: "geo-\(idSeed.lowercased())",
            name: shortName.isEmpty ? name : shortName,
            coordinate: best.placemark.coordinate
        )
    }
}
