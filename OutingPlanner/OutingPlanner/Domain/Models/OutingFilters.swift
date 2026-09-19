//
//  OutingFilters.swift
//  OutingPlanner
//

import Foundation

struct OutingFilters: Equatable {
    var purpose: OutingPurpose = .unspecified
    var selectedGenres: Set<String> = []
    var areaQuery: String = ""
    var maxBudget: Int? = nil
    var maxDurationMinutes: Int? = nil
    var weekendOnly: Bool = false

    var isEmpty: Bool {
        purpose == .unspecified
            && selectedGenres.isEmpty
            && areaQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && maxBudget == nil
            && maxDurationMinutes == nil
            && !weekendOnly
    }

    mutating func reset() {
        self = OutingFilters()
    }
}
