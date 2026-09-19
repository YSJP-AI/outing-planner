//
//  OutingEvent.swift
//  OutingPlanner
//

import Foundation

enum EventSource: String, Codable, CaseIterable, Identifiable {
    case walkerplus
    case enjoytokyo
    case gotokyo
    case official
    case hotspot
    case tabelog
    case instagram
    case trend
    case manual

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .walkerplus: "Walkerplus"
        case .enjoytokyo: "EnjoyTokyo"
        case .gotokyo: "GO TOKYO"
        case .official: "公式サイト"
        case .hotspot: "人気スポット"
        case .tabelog: "食べログ"
        case .instagram: "Instagram話題"
        case .trend: "最新トレンド"
        case .manual: "キュレーション"
        }
    }
}

struct OutingEvent: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let genres: [String]
    let area: String
    let venue: String?
    let startAt: Date?
    let endAt: Date?
    let durationMinutes: Int?
    let priceMin: Int?
    let priceMax: Int?
    let priceText: String?
    let source: EventSource
    let sourceURL: URL
    let summary: String?
    let lat: Double?
    let lng: Double?

    var resolvedDurationMinutes: Int {
        if let durationMinutes { return durationMinutes }
        if let startAt, let endAt {
            return max(30, Int(endAt.timeIntervalSince(startAt) / 60))
        }
        return GenreDefaults.durationMinutes(for: genres)
    }

    var priceLabel: String {
        if let priceText, !priceText.isEmpty { return priceText }
        switch (priceMin, priceMax) {
        case (0, 0), (0, nil):
            return "無料"
        case let (min?, max?) where min == max:
            return "¥\(min.formatted())"
        case let (min?, max?):
            return "¥\(min.formatted())〜¥\(max.formatted())"
        case let (min?, nil):
            return "¥\(min.formatted())〜"
        default:
            return "料金未定"
        }
    }

    var timeLabel: String {
        let dateFormatter = Date.FormatStyle(date: .abbreviated, time: .omitted)
            .locale(Locale(identifier: "ja_JP"))
        let timeFormatter = Date.FormatStyle(date: .omitted, time: .shortened)
            .locale(Locale(identifier: "ja_JP"))

        if let startAt, let endAt {
            let calendar = Calendar.current
            let multiDay = !calendar.isDate(startAt, inSameDayAs: endAt)
            if multiDay {
                return "\(startAt.formatted(dateFormatter))〜\(endAt.formatted(dateFormatter))"
            }
            return "\(startAt.formatted(timeFormatter))〜\(endAt.formatted(timeFormatter))"
        }
        if let startAt {
            return "\(startAt.formatted(dateFormatter))〜"
        }
        return "時間自由 / 開館時間内"
    }

    /// True when the event has a concrete schedule window (festival, show, exhibition dates).
    var isLimitedTime: Bool {
        startAt != nil || endAt != nil
    }
}

enum GenreDefaults {
    static let knownGenres = [
        "アート", "グルメ", "自然", "エンタメ", "体験", "ショッピング", "祭り", "映え"
    ]

    static func durationMinutes(for genres: [String]) -> Int {
        if genres.contains("祭り") { return 180 }
        if genres.contains("自然") { return 150 }
        if genres.contains("アート") { return 120 }
        if genres.contains("映え") { return 100 }
        if genres.contains("グルメ") { return 90 }
        if genres.contains("エンタメ") { return 150 }
        if genres.contains("体験") { return 120 }
        if genres.contains("ショッピング") { return 120 }
        return 120
    }
}
