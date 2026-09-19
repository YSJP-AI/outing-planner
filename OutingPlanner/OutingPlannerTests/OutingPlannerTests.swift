import Foundation
import Testing
@testable import OutingPlanner

struct OutingPlannerTests {

    @Test func mockEventsLoad() throws {
        let events = try MockEventRepository().loadEvents()
        #expect(events.count >= 25)
        #expect(events.contains { $0.title.contains("サンシャイン水族館") })
        #expect(events.contains { $0.isLimitedTime })
        #expect(events.allSatisfy { !$0.area.isEmpty })
    }

    @Test func tokyoFilterAndProposal() throws {
        let events = try MockEventRepository().loadEvents()
        var filters = OutingFilters()
        filters.selectedGenres = ["アート"]
        let filtered = EventFilterService.filter(events, with: filters)
        #expect(!filtered.isEmpty)
        #expect(filtered.allSatisfy { $0.genres.contains("アート") })

        let proposals = ProposalEngine.propose(from: events, filters: OutingFilters(), existingPlans: [])
        #expect((3...8).contains(proposals.count))
        #expect(proposals.allSatisfy {
            EventTiming.isWithinRecommendationWindow($0.event)
        })
        #expect(!proposals.contains { $0.event.title.contains("けやき坂") })
    }

    @Test func limitedTimeEventsSurfaceInRecommendations() throws {
        let events = try MockEventRepository().loadEvents()
        #expect(events.contains { $0.isLimitedTime })

        let reference = ISO8601DateFormatter().date(from: "2026-09-19T12:00:00+09:00")!
        let proposals = ProposalEngine.propose(
            from: events,
            filters: OutingFilters(),
            existingPlans: [],
            referenceDate: reference,
            limit: 8
        )
        #expect(proposals.contains { $0.event.isLimitedTime })
        let limited = events.filter {
            $0.isLimitedTime && EventTiming.isWithinRecommendationWindow($0, reference: reference)
        }
        #expect(limited.count >= 5)
    }

    @Test func eventInfoLinkPrefersSpecificPages() throws {
        let events = try MockEventRepository().loadEvents()
        let drone = try #require(events.first { $0.id == "season-odaiba-drone-2026" })
        let url = EventInfoLink.primaryURL(for: drone)
        #expect(url.host?.contains("odaibadrone") == true)

        let generic = OutingEvent(
            id: "tmp",
            title: "テスト展",
            genres: ["アート"],
            area: "上野",
            venue: nil,
            startAt: nil,
            endAt: nil,
            durationMinutes: 60,
            priceMin: nil,
            priceMax: nil,
            priceText: nil,
            source: .enjoytokyo,
            sourceURL: URL(string: "https://www.enjoytokyo.jp/")!,
            summary: nil,
            lat: nil,
            lng: nil
        )
        let resolved = EventInfoLink.primaryURL(for: generic)
        #expect(resolved.absoluteString.contains("search"))
    }

    @Test func farFutureEventExcludedFromRecommendations() throws {
        let events = try MockEventRepository().loadEvents()
        let reference = ISO8601DateFormatter().date(from: "2026-09-19T12:00:00+09:00")!
        let proposals = ProposalEngine.propose(
            from: events,
            filters: OutingFilters(),
            existingPlans: [],
            referenceDate: reference
        )
        #expect(!proposals.contains { $0.event.id == "trend-010" })
        #expect(proposals.allSatisfy {
            EventTiming.isWithinRecommendationWindow($0.event, reference: reference)
        })
    }

    @Test func scheduleSnapAndClamp() {
        let minutes = ScheduleHelper.minuteDelta(forTranslationY: 52, hourHeight: 52)
        #expect(minutes == 60)

        let day = Calendar.current.startOfDay(for: Date())
        let late = Calendar.current.date(byAdding: .hour, value: 21, to: day)!
        let slot = ScheduleHelper.clampedSlot(
            start: late,
            durationMinutes: 120,
            on: day,
            dayStartHour: 9,
            dayEndHour: 22
        )
        #expect(slot.end <= Calendar.current.date(byAdding: .hour, value: 22, to: day)!)
    }

    @Test func slotPatternsNearIkebukuroPreferLocal() throws {
        let events = try MockEventRepository().loadEvents()
        let start = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 20, hour: 12))!
        let end = start.addingTimeInterval(4 * 60 * 60)
        let request = TimeSlotRequest(start: start, end: end, preferredStation: "池袋")
        let patterns = SlotProposalEngine.proposePatterns(
            for: request,
            from: events,
            filters: OutingFilters(),
            existingPlans: []
        )
        #expect(patterns.count >= 2)
        #expect(patterns.contains { pattern in
            pattern.stops.contains { $0.event.title.contains("サンシャイン") }
        })
    }

    @Test func tokyoStationExcludesInokashira() throws {
        let events = try MockEventRepository().loadEvents()
        let station = try #require(TokyoStationCatalog.resolve("東京"))
        let inokashira = try #require(events.first { $0.title.contains("井の頭") })
        let distance = try #require(GeoHelper.distanceKm(from: inokashira, to: station))
        #expect(distance > 10)

        let start = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 20, hour: 12))!
        let end = start.addingTimeInterval(4 * 60 * 60)
        let patterns = SlotProposalEngine.proposePatterns(
            for: TimeSlotRequest(start: start, end: end, preferredStation: "東京"),
            from: events,
            filters: OutingFilters(),
            existingPlans: []
        )
        #expect(!patterns.isEmpty)
        #expect(patterns.allSatisfy { pattern in
            !pattern.stops.contains { $0.event.title.contains("井の頭") }
        })
    }

    @Test func slotPatternsNearUenoPreferUenoOverAsakusa() throws {
        let events = try MockEventRepository().loadEvents()
        let start = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 20, hour: 12))!
        let end = start.addingTimeInterval(4 * 60 * 60)
        let patterns = SlotProposalEngine.proposePatterns(
            for: TimeSlotRequest(start: start, end: end, preferredStation: "上野"),
            from: events,
            filters: OutingFilters(),
            existingPlans: []
        )
        #expect(!patterns.isEmpty)
        #expect(patterns.allSatisfy { pattern in
            guard let first = pattern.stops.first else { return false }
            let distance = GeoHelper.distanceKm(from: first.event, to: TokyoStationCatalog.resolve("上野")!)
            return (distance ?? 99) <= 2.0
        })
        // Majority of first stops should be Ueno-side, not Asakusa-only starts.
        let asakusaFirst = patterns.filter {
            $0.stops.first?.event.area.contains("浅草") == true
                && $0.stops.first?.event.area.contains("上野") != true
        }
        #expect(asakusaFirst.count <= patterns.count / 2)
    }

    @Test func proposedPatternsHaveTravelBuffers() throws {
        let events = try MockEventRepository().loadEvents()
        let start = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 20, hour: 12))!
        let end = start.addingTimeInterval(4 * 60 * 60)
        let patterns = SlotProposalEngine.proposePatterns(
            for: TimeSlotRequest(start: start, end: end, preferredStation: "池袋"),
            from: events,
            filters: OutingFilters(),
            existingPlans: []
        )
        #expect(!patterns.isEmpty)
        for pattern in patterns where pattern.stops.count >= 2 {
            let editable = pattern.stops.map(EditableStop.init(from:))
            for index in 0..<(editable.count - 1) {
                let gap = ItineraryScheduler.gapMinutes(between: editable[index], and: editable[index + 1])
                let needed = ItineraryScheduler.requiredTravel(between: editable[index], and: editable[index + 1])
                #expect(gap >= needed)
            }
        }

        // Variety: not all patterns should share the same first event.
        let firstIds = Set(patterns.compactMap { $0.stops.first?.event.id })
        #expect(firstIds.count >= min(2, patterns.count))
    }
}
