//
//  TokyoStationCatalog.swift
//  OutingPlanner
//

import CoreLocation
import Foundation

struct TokyoStation: Identifiable, Hashable {
    let id: String
    let name: String
    let coordinate: CLLocationCoordinate2D

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: TokyoStation, rhs: TokyoStation) -> Bool {
        lhs.id == rhs.id
    }
}

enum TokyoStationCatalog {
    static let stations: [TokyoStation] = [
        .init(id: "ikebukuro", name: "池袋", coordinate: .init(latitude: 35.7295, longitude: 139.7109)),
        .init(id: "shinjuku", name: "新宿", coordinate: .init(latitude: 35.6909, longitude: 139.7003)),
        .init(id: "shibuya", name: "渋谷", coordinate: .init(latitude: 35.6580, longitude: 139.7016)),
        .init(id: "ueno", name: "上野", coordinate: .init(latitude: 35.7141, longitude: 139.7774)),
        .init(id: "tokyo", name: "東京", coordinate: .init(latitude: 35.6812, longitude: 139.7671)),
        .init(id: "akihabara", name: "秋葉原", coordinate: .init(latitude: 35.6984, longitude: 139.7731)),
        .init(id: "asakusa", name: "浅草", coordinate: .init(latitude: 35.7110, longitude: 139.7967)),
        .init(id: "ginza", name: "銀座", coordinate: .init(latitude: 35.6717, longitude: 139.7649)),
        .init(id: "roppongi", name: "六本木", coordinate: .init(latitude: 35.6627, longitude: 139.7310)),
        .init(id: "omotesando", name: "表参道", coordinate: .init(latitude: 35.6652, longitude: 139.7125)),
        .init(id: "harajuku", name: "原宿", coordinate: .init(latitude: 35.6702, longitude: 139.7027)),
        .init(id: "ebisu", name: "恵比寿", coordinate: .init(latitude: 35.6467, longitude: 139.7100)),
        .init(id: "meguro", name: "目黒", coordinate: .init(latitude: 35.6333, longitude: 139.7157)),
        .init(id: "shinagawa", name: "品川", coordinate: .init(latitude: 35.6284, longitude: 139.7387)),
        .init(id: "toyosu", name: "豊洲", coordinate: .init(latitude: 35.6545, longitude: 139.7968)),
        .init(id: "odaiba", name: "お台場海浜公園", coordinate: .init(latitude: 35.6294, longitude: 139.7794)),
        .init(id: "kichijoji", name: "吉祥寺", coordinate: .init(latitude: 35.7031, longitude: 139.5797)),
        .init(id: "nakano", name: "中野", coordinate: .init(latitude: 35.7057, longitude: 139.6650)),
        .init(id: "kagurazaka", name: "神楽坂", coordinate: .init(latitude: 35.7022, longitude: 139.7400)),
        .init(id: "tsukiji", name: "築地", coordinate: .init(latitude: 35.6654, longitude: 139.7707)),
        .init(id: "yurakucho", name: "有楽町", coordinate: .init(latitude: 35.6751, longitude: 139.7633)),
        .init(id: "nippori", name: "日暮里", coordinate: .init(latitude: 35.7278, longitude: 139.7706)),
        .init(id: "sendagi", name: "千駄木", coordinate: .init(latitude: 35.7254, longitude: 139.7631)),
        .init(id: "okachimachi", name: "御徒町", coordinate: .init(latitude: 35.7074, longitude: 139.7745)),
        .init(id: "yushima", name: "湯島", coordinate: .init(latitude: 35.7137, longitude: 139.7690)),
        .init(id: "kuramae", name: "蔵前", coordinate: .init(latitude: 35.7081, longitude: 139.7913)),
        .init(id: "ryogoku", name: "両国", coordinate: .init(latitude: 35.6960, longitude: 139.7925)),
        .init(id: "oshiage", name: "押上", coordinate: .init(latitude: 35.7101, longitude: 139.8107)),
        .init(id: "mejiro", name: "目白", coordinate: .init(latitude: 35.7212, longitude: 139.7068)),
        .init(id: "takadanobaba", name: "高田馬場", coordinate: .init(latitude: 35.7126, longitude: 139.7038)),
        .init(id: "iidabashi", name: "飯田橋", coordinate: .init(latitude: 35.7021, longitude: 139.7450)),
        .init(id: "nakameguro", name: "中目黒", coordinate: .init(latitude: 35.6441, longitude: 139.6988)),
        .init(id: "daikanyama", name: "代官山", coordinate: .init(latitude: 35.6480, longitude: 139.7032)),
        .init(id: "shimokitazawa", name: "下北沢", coordinate: .init(latitude: 35.6616, longitude: 139.6683)),
        .init(id: "sangenjaya", name: "三軒茶屋", coordinate: .init(latitude: 35.6435, longitude: 139.6701)),
        .init(id: "jiyugaoka", name: "自由が丘", coordinate: .init(latitude: 35.6076, longitude: 139.6688)),
        .init(id: "kitasenju", name: "北千住", coordinate: .init(latitude: 35.7496, longitude: 139.8051)),
        .init(id: "kameido", name: "亀戸", coordinate: .init(latitude: 35.6973, longitude: 139.8263)),
        .init(id: "monzennakacho", name: "門前仲町", coordinate: .init(latitude: 35.6727, longitude: 139.7960)),
        .init(id: "kiyosumishirakawa", name: "清澄白河", coordinate: .init(latitude: 35.6821, longitude: 139.7988)),
        .init(id: "hamamatsucho", name: "浜松町", coordinate: .init(latitude: 35.6554, longitude: 139.7571)),
        .init(id: "yoyogi", name: "代々木", coordinate: .init(latitude: 35.6831, longitude: 139.7022))
    ]

    /// Resolve free-text station input to a known station (optional).
    static func resolve(_ query: String) -> TokyoStation? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let normalized = trimmed
            .replacingOccurrences(of: "駅", with: "")
            .replacingOccurrences(of: "　", with: "")

        if let exact = stations.first(where: { $0.name == normalized || $0.name == trimmed }) {
            return exact
        }
        if let prefix = stations.first(where: {
            $0.name.hasPrefix(normalized) || normalized.hasPrefix($0.name)
        }) {
            return prefix
        }
        return stations.first(where: { $0.name.contains(normalized) || normalized.contains($0.name) })
    }

    static func suggestions(matching query: String, limit: Int = 8) -> [TokyoStation] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "駅", with: "")
        if trimmed.isEmpty {
            return Array(stations.prefix(limit))
        }
        return stations
            .filter { $0.name.contains(trimmed) || trimmed.contains($0.name) }
            .prefix(limit)
            .map { $0 }
    }
}

enum AreaCoordinates {
    static let centers: [String: CLLocationCoordinate2D] = [
        "上野": .init(latitude: 35.7141, longitude: 139.7774),
        "谷中": .init(latitude: 35.7268, longitude: 139.7699),
        "豊洲": .init(latitude: 35.6545, longitude: 139.7968),
        "原宿": .init(latitude: 35.6702, longitude: 139.7027),
        "外苑": .init(latitude: 35.6745, longitude: 139.7173),
        "築地": .init(latitude: 35.6654, longitude: 139.7707),
        "浅草": .init(latitude: 35.7110, longitude: 139.7967),
        "渋谷": .init(latitude: 35.6580, longitude: 139.7016),
        "六本木": .init(latitude: 35.6627, longitude: 139.7310),
        "お台場": .init(latitude: 35.6294, longitude: 139.7794),
        "神楽坂": .init(latitude: 35.7022, longitude: 139.7400),
        "丸の内": .init(latitude: 35.6812, longitude: 139.7671),
        "吉祥寺": .init(latitude: 35.7031, longitude: 139.5797),
        "井の頭": .init(latitude: 35.7000, longitude: 139.5730),
        "銀座": .init(latitude: 35.6717, longitude: 139.7649),
        "新宿": .init(latitude: 35.6909, longitude: 139.7003),
        "池袋": .init(latitude: 35.7295, longitude: 139.7109),
        "雑司が谷": .init(latitude: 35.7200, longitude: 139.7145),
        "代々木": .init(latitude: 35.6710, longitude: 139.6950),
        "押上": .init(latitude: 35.7101, longitude: 139.8107),
        "麻布台": .init(latitude: 35.6608, longitude: 139.7400),
        "南長崎": .init(latitude: 35.7280, longitude: 139.6855),
        "有楽町": .init(latitude: 35.6751, longitude: 139.7633),
        "秋葉原": .init(latitude: 35.6984, longitude: 139.7731),
        "品川": .init(latitude: 35.6284, longitude: 139.7387)
    ]

    /// Too broad to use as a map pin (would pin everything to Tokyo Station).
    private static let genericAreas: Set<String> = ["東京", "東京都", "都内", "関東"]

    static func coordinate(forArea area: String) -> CLLocationCoordinate2D? {
        let trimmed = area.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !genericAreas.contains(trimmed) else { return nil }
        if let exact = centers[trimmed] { return exact }
        // Prefer longer key matches ("井の頭" before accidentally matching nothing).
        let matches = centers.keys.filter { trimmed.contains($0) || $0.contains(trimmed) }
        guard let best = matches.max(by: { $0.count < $1.count }) else { return nil }
        return centers[best]
    }

    static func inferredArea(fromTitle title: String) -> String? {
        let keys = centers.keys.sorted { $0.count > $1.count }
        return keys.first { title.contains($0) }
    }
}

enum GeoHelper {
    static func coordinate(for event: OutingEvent) -> CLLocationCoordinate2D? {
        if let lat = event.lat, let lng = event.lng {
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }
        if let fromArea = AreaCoordinates.coordinate(forArea: event.area) {
            return fromArea
        }
        if let inferred = AreaCoordinates.inferredArea(fromTitle: event.title),
           let coord = AreaCoordinates.coordinate(forArea: inferred) {
            return coord
        }
        return nil
    }

    /// Events without a trustworthy location must not enter station-local pools.
    static func hasReliableLocation(_ event: OutingEvent) -> Bool {
        coordinate(for: event) != nil
    }

    /// Great-circle distance in kilometers.
    static func distanceKm(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) -> Double {
        let earthRadius = 6371.0
        let dLat = (to.latitude - from.latitude) * .pi / 180
        let dLon = (to.longitude - from.longitude) * .pi / 180
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return earthRadius * c
    }

    static func distanceKm(from event: OutingEvent, to station: TokyoStation) -> Double? {
        guard let coord = coordinate(for: event) else { return nil }
        return distanceKm(from: station.coordinate, to: coord)
    }
}
