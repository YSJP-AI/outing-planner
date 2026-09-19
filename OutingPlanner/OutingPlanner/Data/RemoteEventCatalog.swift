//
//  RemoteEventCatalog.swift
//  OutingPlanner
//

import Foundation

struct RemoteEventCatalogPayload: Codable, Equatable {
    var version: Int
    var updatedAt: Date?
    var note: String?
    var events: [OutingEvent]
}

enum RemoteEventCatalogConfig {
    /// Public GitHub raw JSON (no API key). Repo must be public for anonymous downloads.
    static let defaultCatalogURL = URL(
        string: "https://raw.githubusercontent.com/YSJP-AI/outing-planner/main/remote/events.json"
    )!

    static let jsDelivrCatalogURL = URL(
        string: "https://cdn.jsdelivr.net/gh/YSJP-AI/outing-planner@main/remote/events.json"
    )!

    private static let overrideKey = "outing.remoteCatalogURL"

    static var catalogURL: URL {
        if let raw = UserDefaults.standard.string(forKey: overrideKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !raw.isEmpty,
           let url = URL(string: raw) {
            return url
        }
        return defaultCatalogURL
    }

    static func setCatalogURLOverride(_ raw: String?) {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            UserDefaults.standard.removeObject(forKey: overrideKey)
        } else {
            UserDefaults.standard.set(trimmed, forKey: overrideKey)
        }
    }

    static var catalogURLOverride: String {
        UserDefaults.standard.string(forKey: overrideKey) ?? ""
    }
}

actor RemoteEventCatalogClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetch(preferredURL: URL? = nil) async throws -> RemoteEventCatalogPayload {
        var candidates: [URL] = []
        if let preferredURL {
            candidates.append(preferredURL)
        }
        let configured = RemoteEventCatalogConfig.catalogURL
        candidates.append(configured)
        if configured == RemoteEventCatalogConfig.defaultCatalogURL {
            candidates.append(RemoteEventCatalogConfig.jsDelivrCatalogURL)
        }

        var lastError: Error = RemoteCatalogError.invalidResponse
        var seen = Set<String>()
        for url in candidates where seen.insert(url.absoluteString).inserted {
            do {
                return try await fetch(url: url)
            } catch {
                lastError = error
            }
        }
        throw lastError
    }

    private func fetch(url: URL) async throws -> RemoteEventCatalogPayload {
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 30
        request.setValue("OutingPlanner/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw RemoteCatalogError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            if http.statusCode == 404 {
                throw RemoteCatalogError.notFound
            }
            throw RemoteCatalogError.httpStatus(http.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(RemoteEventCatalogPayload.self, from: data)
        } catch {
            let events = try decoder.decode([OutingEvent].self, from: data)
            return RemoteEventCatalogPayload(
                version: 1,
                updatedAt: .now,
                note: nil,
                events: events
            )
        }
    }
}

enum RemoteCatalogError: LocalizedError {
    case invalidResponse
    case httpStatus(Int)
    case notFound
    case emptyCatalog

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "サーバー応答を解釈できませんでした。"
        case .httpStatus(let code):
            return "更新に失敗しました（HTTP \(code)）。ネットワークを確認してください。"
        case .notFound:
            return "カタログが見つかりません。GitHubリポジトリが非公開の場合は公開するか、公開URLを設定してください。"
        case .emptyCatalog:
            return "取得したイベント一覧が空でした。"
        }
    }
}

/// Persists the last successful remote catalog on device.
final class EventCatalogStore {
    private let fileURL: URL
    private let metaURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default) {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let directory = appSupport.appendingPathComponent("OutingPlanner", isDirectory: true)
        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        fileURL = directory.appendingPathComponent("remote_events.json")
        metaURL = directory.appendingPathComponent("remote_events_meta.json")

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    struct Meta: Codable {
        var fetchedAt: Date
        var catalogUpdatedAt: Date?
        var eventCount: Int
        var version: Int
    }

    func loadPayload() -> RemoteEventCatalogPayload? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode(RemoteEventCatalogPayload.self, from: data)
        } catch {
            print("EventCatalogStore load failed: \(error)")
            return nil
        }
    }

    func loadMeta() -> Meta? {
        guard FileManager.default.fileExists(atPath: metaURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: metaURL)
            return try decoder.decode(Meta.self, from: data)
        } catch {
            return nil
        }
    }

    func save(_ payload: RemoteEventCatalogPayload) throws {
        guard !payload.events.isEmpty else { throw RemoteCatalogError.emptyCatalog }
        let data = try encoder.encode(payload)
        try data.write(to: fileURL, options: [.atomic])

        let meta = Meta(
            fetchedAt: .now,
            catalogUpdatedAt: payload.updatedAt,
            eventCount: payload.events.count,
            version: payload.version
        )
        let metaData = try encoder.encode(meta)
        try metaData.write(to: metaURL, options: [.atomic])
    }
}
