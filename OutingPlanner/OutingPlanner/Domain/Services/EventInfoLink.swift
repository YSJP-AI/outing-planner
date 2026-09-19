//
//  EventInfoLink.swift
//  OutingPlanner
//

import Foundation

/// Picks the best outbound URL for an event: specific page > search on a known directory.
enum EventInfoLink {
    struct Destination: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let url: URL
        let isPrimary: Bool
    }

    /// Primary destinations shown on the detail screen.
    static func destinations(for event: OutingEvent) -> [Destination] {
        var items: [Destination] = []
        let primary = primaryURL(for: event)
        items.append(
            Destination(
                id: "primary",
                title: primaryLabel(for: event, url: primary),
                subtitle: hostLabel(primary),
                url: primary,
                isPrimary: true
            )
        )

        if isGenericHomepage(event.sourceURL),
           let search = directorySearchURL(for: event),
           search.absoluteString != primary.absoluteString {
            items.append(
                Destination(
                    id: "search",
                    title: "イベント情報を検索",
                    subtitle: hostLabel(search),
                    url: search,
                    isPrimary: false
                )
            )
        }

        return items
    }

    static func primaryURL(for event: OutingEvent) -> URL {
        if !isGenericHomepage(event.sourceURL) {
            return event.sourceURL
        }
        return directorySearchURL(for: event) ?? event.sourceURL
    }

    static func isGenericHomepage(_ url: URL) -> Bool {
        let host = (url.host ?? "").lowercased()
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let genericHosts: Set<String> = [
            "www.gotokyo.org",
            "gotokyo.org",
            "www.enjoytokyo.jp",
            "enjoytokyo.jp",
            "www.walkerplus.com",
            "walkerplus.com"
        ]
        guard genericHosts.contains(host) else { return false }
        if path.isEmpty { return true }
        let shallow = ["event", "spot", "jp", "en", "ja", "event_list"]
        let parts = path.split(separator: "/")
        return shallow.contains(path) || parts.count <= 1
    }

    static func directorySearchURL(for event: OutingEvent) -> URL? {
        let query = [event.title, event.area]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? event.title

        switch event.source {
        case .enjoytokyo:
            return URL(string: "https://www.enjoytokyo.jp/search/?q=\(encoded)")
        case .walkerplus:
            return URL(string: "https://www.walkerplus.com/search/?keyword=\(encoded)")
        case .gotokyo:
            return URL(string: "https://www.gotokyo.org/jp/search/index.html?q=\(encoded)")
        case .tabelog:
            return RestaurantSearch.tabelogSearchURL(name: event.title, area: event.area)
        default:
            return URL(string: "https://www.google.com/search?q=\(encoded)+公式")
        }
    }

    private static func primaryLabel(for event: OutingEvent, url: URL) -> String {
        if (url.host ?? "").contains("tabelog") {
            return "食べログで詳細を見る"
        }
        if event.source == .official || !isGenericHomepage(event.sourceURL) {
            return "公式・詳細ページを開く"
        }
        return "\(event.source.displayName)で詳細を見る"
    }

    private static func hostLabel(_ url: URL) -> String {
        url.host ?? url.absoluteString
    }
}
