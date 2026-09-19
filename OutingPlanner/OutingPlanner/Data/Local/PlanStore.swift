//
//  PlanStore.swift
//  OutingPlanner
//

import Foundation

/// File-based persistence for calendar plans (Application Support/plans.json).
final class PlanStore {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default) {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let directory = appSupport.appendingPathComponent("OutingPlanner", isDirectory: true)
        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        fileURL = directory.appendingPathComponent("plans.json")

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func loadAll() -> [OutingPlan] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        do {
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode([OutingPlan].self, from: data)
                .sorted { $0.scheduledStart < $1.scheduledStart }
        } catch {
            print("PlanStore load failed: \(error)")
            return []
        }
    }

    func saveAll(_ plans: [OutingPlan]) {
        do {
            let data = try encoder.encode(plans)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            print("PlanStore save failed: \(error) path=\(fileURL.path)")
        }
    }

    var debugPath: String { fileURL.path }
}
