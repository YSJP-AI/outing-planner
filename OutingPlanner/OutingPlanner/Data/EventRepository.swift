//
//  EventRepository.swift
//  OutingPlanner
//

import Foundation

protocol EventRepository {
    func loadEvents() throws -> [OutingEvent]
}

struct MockEventRepository: EventRepository {
    /// Bundled catalogs representing multiple information sources.
    private let resourceNames = [
        "tokyo_seasonal_events",
        "tokyo_events",
        "spots_ikebukuro",
        "spots_major",
        "spots_restaurants",
        "spots_restaurants_named",
        "spots_instagram_trends",
        "tokyo_events_live"
    ]

    func loadEvents() throws -> [OutingEvent] {
        var merged: [OutingEvent] = []
        var seen = Set<String>()

        for name in resourceNames {
            guard let url = Bundle.main.url(forResource: name, withExtension: "json") else {
                continue
            }
            guard let batch = try? decodeEvents(from: url) else { continue }
            for event in batch where !seen.contains(event.id) {
                seen.insert(event.id)
                merged.append(event)
            }
        }

        guard !merged.isEmpty else {
            throw RepositoryError.missingResource
        }
        return merged
    }

    private func decodeEvents(from url: URL) throws -> [OutingEvent] {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([OutingEvent].self, from: data)
    }
}

enum RepositoryError: LocalizedError {
    case missingResource

    var errorDescription: String? {
        switch self {
        case .missingResource:
            return "イベントデータの読み込みに失敗しました。"
        }
    }
}
