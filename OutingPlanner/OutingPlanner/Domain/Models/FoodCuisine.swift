//
//  FoodCuisine.swift
//  OutingPlanner
//

import Foundation

enum FoodCuisine: String, CaseIterable, Identifiable {
    case ramen = "ラーメン"
    case yakiniku = "焼肉"
    case sushi = "寿司"
    case washoku = "和食"
    case soba = "そば"
    case udon = "うどん"
    case tempura = "天ぷら"
    case yakitori = "焼鳥"
    case teishoku = "定食"
    case italian = "イタリアン"
    case cafe = "カフェ"
    case seafood = "海鮮"
    case curry = "カレー"

    var id: String { rawValue }

    var aliases: [String] {
        switch self {
        case .ramen: ["らーめん", "拉麺", "AFURI"]
        case .yakiniku: ["焼肉", "叙々苑"]
        case .sushi: ["すし", "寿司"]
        case .washoku: ["和食", "日本料理"]
        case .soba: ["そば", "蕎麦"]
        case .udon: ["うどん"]
        case .tempura: ["天ぷら", "天麩羅"]
        case .yakitori: ["焼鳥", "焼き鳥", "いせや"]
        case .teishoku: ["定食", "食堂"]
        case .italian: ["イタリアン", "パスタ", "ピザ"]
        case .cafe: ["カフェ", "coffee", "Coffee"]
        case .seafood: ["海鮮", "魚", "羽田市場"]
        case .curry: ["カレー", "ぶらじる"]
        }
    }

    /// Detect cuisine tags from title/summary/genres.
    static func detected(in event: OutingEvent) -> [FoodCuisine] {
        let haystack = [
            event.title,
            event.summary ?? "",
            event.venue ?? "",
            event.genres.joined(separator: " ")
        ].joined(separator: " ")

        return allCases.filter { cuisine in
            event.genres.contains(cuisine.rawValue)
                || haystack.contains(cuisine.rawValue)
                || cuisine.aliases.contains(where: { haystack.contains($0) })
        }
    }

    static func labels(for event: OutingEvent) -> [String] {
        let detected = detected(in: event).map(\.rawValue)
        if !detected.isEmpty { return detected }
        return event.genres.filter { $0 != "グルメ" }
    }
}
