//
//  OutingPurpose.swift
//  OutingPlanner
//

import Foundation

enum OutingPurpose: String, CaseIterable, Identifiable, Equatable {
    case unspecified
    case family
    case withKids
    case withPartner

    var id: String { rawValue }

    var label: String {
        switch self {
        case .unspecified: "指定なし"
        case .family: "家族"
        case .withKids: "子供と"
        case .withPartner: "パートナーと"
        }
    }

    var shortHint: String {
        switch self {
        case .unspecified: "だれとでも"
        case .family: "みんなで楽しめる"
        case .withKids: "子ども向けを優先"
        case .withPartner: "二人向けを優先"
        }
    }

    var iconName: String {
        switch self {
        case .unspecified: "person"
        case .family: "figure.2.and.child.holdinghands"
        case .withKids: "figure.and.child.holdinghands"
        case .withPartner: "heart"
        }
    }
}

enum OutingPurposeScorer {
    /// Soft ranking boost/penalty for companion purpose. Does not hard-filter.
    static func score(_ event: OutingEvent, purpose: OutingPurpose) -> Int {
        guard purpose != .unspecified else { return 0 }

        let text = [
            event.title,
            event.summary ?? "",
            event.venue ?? "",
            event.area,
            event.genres.joined(separator: " ")
        ].joined(separator: " ").lowercased()

        switch purpose {
        case .unspecified:
            return 0
        case .family:
            return familyScore(event: event, text: text)
        case .withKids:
            return kidsScore(event: event, text: text)
        case .withPartner:
            return partnerScore(event: event, text: text)
        }
    }

    static func reasonSuffix(for event: OutingEvent, purpose: OutingPurpose) -> String? {
        guard purpose != .unspecified else { return nil }
        let boost = score(event, purpose: purpose)
        guard boost >= 12 else { return nil }
        switch purpose {
        case .family: return "家族向けに合いやすい"
        case .withKids: return "子どもと行きやすい"
        case .withPartner: return "パートナーと楽しめる"
        case .unspecified: return nil
        }
    }

    static func patternFlavor(purpose: OutingPurpose) -> (titlePrefix: String, styleHint: String)? {
        switch purpose {
        case .unspecified: return nil
        case .family: return ("家族で", "家族向け")
        case .withKids: return ("子どもと", "キッズ向け")
        case .withPartner: return ("二人で", "デート向け")
        }
    }

    // MARK: - Private

    private static func familyScore(event: OutingEvent, text: String) -> Int {
        var value = 0
        if containsAny(text, ["公園", "水族館", "動物園", "博物館", "科学", "プラネタリウム", "展望", "ピクニック"]) {
            value += 28
        }
        if event.genres.contains("自然") || event.genres.contains("体験") || event.genres.contains("エンタメ") {
            value += 16
        }
        if event.genres.contains("アート") { value += 6 }
        if containsAny(text, ["バー", "居酒屋", "クラブ", "夜景バー"]) { value -= 25 }
        if event.resolvedDurationMinutes <= 150 { value += 8 }
        if (event.priceMin ?? 0) <= 3000 { value += 6 }
        return value
    }

    private static func kidsScore(event: OutingEvent, text: String) -> Int {
        var value = 0
        if containsAny(text, ["水族館", "動物園", "子ども", "子供", "キッズ", "公園", "プレイ", "科学館", "電車", "のりもの", "サンシャイン", "ナンジャ"]) {
            value += 36
        }
        if event.genres.contains("体験") || event.genres.contains("自然") || event.genres.contains("エンタメ") {
            value += 18
        }
        if containsAny(text, ["美術館", "ギャラリー"]) { value -= 8 }
        if containsAny(text, ["バー", "居酒屋", "ディナー", "焼肉", "デート", "夜"]) { value -= 30 }
        if event.resolvedDurationMinutes <= 120 { value += 12 }
        if event.resolvedDurationMinutes > 180 { value -= 10 }
        if (event.priceMin ?? 0) <= 2500 { value += 8 }
        return value
    }

    private static func partnerScore(event: OutingEvent, text: String) -> Int {
        var value = 0
        if containsAny(text, ["夜景", "展望", "カフェ", "美術館", "ギャラリー", "ディナー", "寺", "庭園", "クルーズ", "恵比寿", "代官山", "六本木", "表参道"]) {
            value += 30
        }
        if event.genres.contains("アート") || event.genres.contains("グルメ") {
            value += 18
        }
        if event.genres.contains("映え") || event.source == .instagram || event.source == .trend {
            value += 14
        }
        if containsAny(text, ["子ども", "子供", "キッズ", "動物園", "遊園地"]) { value -= 22 }
        if containsAny(text, ["公園", "散策", "散歩", "インスタ", "映え", "夜景"]) { value += 8 }
        if event.resolvedDurationMinutes >= 60 && event.resolvedDurationMinutes <= 150 { value += 8 }
        return value
    }

    private static func containsAny(_ text: String, _ keywords: [String]) -> Bool {
        keywords.contains { text.contains($0.lowercased()) }
    }
}
