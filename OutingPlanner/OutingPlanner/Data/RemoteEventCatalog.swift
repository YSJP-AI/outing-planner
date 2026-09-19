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
    /// Public GitHub raw JSON (no API key, no paid hosting).
    static let catalogURL = URL(
        string: "https://raw.githubusercontent.com/YSJP-AI/outing-planner/main/remote/events.json"
    )!
}

actor RemoteEventCatalogClient {
    private let session: URLSession
    private let url: URL

    init(
        url: URL = RemoteEventCatalogConfig.catalogURL,
        session: URLSession = .shared
    ) {
        self.url = url
        self.session = session
    }

    func fetch() async throws -> RemoteEventCatalogPayload {
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 30
        request.setValue("OutingPlanner/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw RemoteCatalogError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw RemoteCatalogError.httpStatus(http.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(RemoteEventCatalogPayload.self, from: data)
        } catch {
            // Allow plain array payloads too.
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
    case emptyCatalog

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "サーバー応答を解釈できませんでした。"
        case .httpStatus(let code):
            return "更新に失敗しました（HTTP \(code)）。ネットワークと GitHub 公開設定を確認してください。"
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
