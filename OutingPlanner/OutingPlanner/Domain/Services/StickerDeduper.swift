//
//  StickerDeduper.swift
//  OutingPlanner
//

import Foundation

/// Removes duplicate sticker candidates that share an id or the same display title.
enum StickerDeduper {
    static func unique(_ events: [OutingEvent]) -> [OutingEvent] {
        var seenIDs = Set<String>()
        var seenTitles = Set<String>()
        return events.filter { event in
            let title = normalizedTitle(event.title)
            guard !title.isEmpty else { return false }
            guard seenIDs.insert(event.id).inserted else { return false }
            guard seenTitles.insert(title).inserted else { return false }
            return true
        }
    }

    /// Keep items whose titles are not already reserved (e.g. other stops / other trays).
    static func unique(
        _ events: [OutingEvent],
        excludingTitles reserved: Set<String>
    ) -> [OutingEvent] {
        var reserved = Set(reserved.map(normalizedTitle).filter { !$0.isEmpty })
        return unique(events).filter { event in
            let title = normalizedTitle(event.title)
            return reserved.insert(title).inserted
        }
    }

    static func normalizedTitle(_ title: String) -> String {
        title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "　", with: "")
            .replacingOccurrences(of: " ", with: "")
            .lowercased()
    }
}
