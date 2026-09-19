//
//  OutingPlan.swift
//  OutingPlanner
//

import Foundation

struct OutingPlan: Identifiable, Codable, Hashable {
    let id: UUID
    let eventId: String
    var scheduledStart: Date
    var scheduledEnd: Date
    var note: String?

    init(
        id: UUID = UUID(),
        eventId: String,
        scheduledStart: Date,
        scheduledEnd: Date,
        note: String? = nil
    ) {
        self.id = id
        self.eventId = eventId
        self.scheduledStart = scheduledStart
        self.scheduledEnd = scheduledEnd
        self.note = note
    }

    func overlaps(_ other: OutingPlan) -> Bool {
        scheduledStart < other.scheduledEnd && other.scheduledStart < scheduledEnd
    }
}
