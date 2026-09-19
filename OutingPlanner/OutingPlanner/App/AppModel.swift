//
//  AppModel.swift
//  OutingPlanner
//

import Foundation
import Observation

@Observable
@MainActor
final class AppModel {
    private(set) var events: [OutingEvent] = []
    private(set) var loadError: String?
    private(set) var isRefreshingEvents = false
    private(set) var eventsRefreshMessage: String?
    private(set) var lastEventsRefreshAt: Date?
    private(set) var remoteEventCount = 0
    var filters = OutingFilters()
    var plans: [OutingPlan] = []
    var selectedWeekDate: Date = .now
    var selectedTab: AppTab = .proposals
    var slotRequest = TimeSlotRequest.defaultRequest()
    private(set) var slotPatterns: [OutingPattern] = []
    private(set) var slotPatternMessage: String?

    private let repository: EventRepository
    private let planStore: PlanStore
    private let catalogStore: EventCatalogStore
    private let remoteClient: RemoteEventCatalogClient

    init(
        repository: EventRepository = MockEventRepository(),
        planStore: PlanStore = PlanStore(),
        catalogStore: EventCatalogStore = EventCatalogStore(),
        remoteClient: RemoteEventCatalogClient = RemoteEventCatalogClient()
    ) {
        self.repository = repository
        self.planStore = planStore
        self.catalogStore = catalogStore
        self.remoteClient = remoteClient
        reload()
        plans = planStore.loadAll()
        if let meta = catalogStore.loadMeta() {
            lastEventsRefreshAt = meta.fetchedAt
            remoteEventCount = meta.eventCount
        }
    }

    var restaurants: [OutingEvent] {
        events.filter {
            $0.genres.contains("グルメ")
                || $0.id.hasPrefix("rst-")
                || $0.id.hasPrefix("custom-")
                || $0.source == .tabelog
        }
    }

    var filteredEvents: [OutingEvent] {
        EventFilterService.filter(events, with: filters)
    }

    var proposals: [OutingProposal] {
        ProposalEngine.propose(from: events, filters: filters, existingPlans: plans)
    }

    var weekDates: [Date] {
        ScheduleHelper.weekDates(containing: selectedWeekDate)
    }

    func reload() {
        do {
            let bundled = try repository.loadEvents()
            let remote = catalogStore.loadPayload()?.events ?? []
            events = Self.mergeEvents(bundled: bundled, remote: remote)
            remoteEventCount = remote.count
            loadError = nil
        } catch {
            events = []
            loadError = error.localizedDescription
        }
    }

    /// Downloads the free GitHub JSON catalog and merges it into the local list.
    func refreshEventsFromRemote() async {
        guard !isRefreshingEvents else { return }
        isRefreshingEvents = true
        eventsRefreshMessage = nil
        defer { isRefreshingEvents = false }

        do {
            let payload = try await remoteClient.fetch()
            try catalogStore.save(payload)
            reload()
            lastEventsRefreshAt = .now
            remoteEventCount = payload.events.count
            eventsRefreshMessage = "イベントを更新しました（追加・上書き \(payload.events.count)件）"
        } catch {
            eventsRefreshMessage = error.localizedDescription
        }
    }

    /// Remote events override bundled ones with the same id; new ids are appended.
    private static func mergeEvents(bundled: [OutingEvent], remote: [OutingEvent]) -> [OutingEvent] {
        var byID: [String: OutingEvent] = [:]
        for event in bundled {
            byID[event.id] = event
        }
        for event in remote {
            byID[event.id] = event
        }
        return byID.values.sorted {
            ($0.startAt ?? .distantFuture) < ($1.startAt ?? .distantFuture)
        }
    }

    func event(for plan: OutingPlan) -> OutingEvent? {
        events.first { $0.id == plan.eventId }
    }

    /// Fallback title when the source event list changed after a plan was saved.
    func displayTitle(for plan: OutingPlan) -> String {
        event(for: plan)?.title ?? "保存済みのお出かけ"
    }

    func plans(on day: Date) -> [OutingPlan] {
        let calendar = Calendar.current
        return plans
            .filter { calendar.isDate($0.scheduledStart, inSameDayAs: day) }
            .sorted { $0.scheduledStart < $1.scheduledStart }
    }

    @discardableResult
    func addToCalendar(_ event: OutingEvent, on day: Date? = nil) -> Bool {
        let targetDay = day ?? suggestedDay(for: event)
        let slot = ScheduleHelper.defaultSlot(for: event, on: targetDay)
        let plan = OutingPlan(
            eventId: event.id,
            scheduledStart: slot.start,
            scheduledEnd: slot.end
        )

        if ScheduleHelper.conflicts(among: plans, candidate: plan) {
            for weekDay in weekDates {
                let alt = ScheduleHelper.defaultSlot(for: event, on: weekDay)
                let altPlan = OutingPlan(
                    eventId: event.id,
                    scheduledStart: alt.start,
                    scheduledEnd: alt.end
                )
                if !ScheduleHelper.conflicts(among: plans, candidate: altPlan) {
                    insertPlan(altPlan)
                    selectedWeekDate = weekDay
                    selectedTab = .calendar
                    return true
                }
            }
            return false
        }

        insertPlan(plan)
        selectedWeekDate = targetDay
        selectedTab = .calendar
        return true
    }

    func removePlan(_ plan: OutingPlan) {
        plans.removeAll { $0.id == plan.id }
        persistPlans()
    }

    func generateSlotPatterns() {
        Task { @MainActor in
            await generateSlotPatternsAsync()
        }
    }

    @MainActor
    func generateSlotPatternsAsync() async {
        guard slotRequest.isValid else {
            slotPatterns = []
            slotPatternMessage = "終了日時は開始より後にしてください（30分以上）。"
            return
        }

        let query = slotRequest.preferredStation.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            slotRequest.resolvedStationOverride = nil
        } else if TokyoStationCatalog.resolve(query) != nil {
            slotRequest.resolvedStationOverride = nil
        } else {
            slotPatternMessage = "「\(query)」の位置を調べています…"
            let resolved = await StationGeocoder.resolve(query)
            // Ignore stale results if the user changed the station while searching.
            guard slotRequest.preferredStation.trimmingCharacters(in: .whitespacesAndNewlines) == query else {
                return
            }
            slotRequest.resolvedStationOverride = resolved
            if resolved == nil {
                slotPatternMessage = "最寄駅「\(query)」を認識できませんでした。別の駅名で試すか、空欄でも提案できます。"
            }
        }

        // Keep purpose in sync between filters and slot request.
        if slotRequest.purpose == .unspecified, filters.purpose != .unspecified {
            slotRequest.purpose = filters.purpose
        } else if filters.purpose == .unspecified, slotRequest.purpose != .unspecified {
            filters.purpose = slotRequest.purpose
        } else {
            filters.purpose = slotRequest.purpose
        }

        let patterns = SlotProposalEngine.proposePatterns(
            for: slotRequest,
            from: events,
            filters: filters,
            existingPlans: plans
        )
        slotPatterns = patterns
        if patterns.isEmpty {
            slotPatternMessage = "この条件に収まる候補がありません。時間を延ばすか駅を変えてください。"
        } else if let station = slotRequest.resolvedStation {
            let purposeNote = slotRequest.purpose == .unspecified
                ? ""
                : "（\(slotRequest.purpose.label)向け）"
            slotPatternMessage = "\(station.name)駅の近くで回れるプランを \(patterns.count)件提案しました\(purposeNote)。カードをタップして詳細・地図を確認できます。"
        } else {
            let purposeNote = slotRequest.purpose == .unspecified
                ? ""
                : "（\(slotRequest.purpose.label)向け）"
            slotPatternMessage = "\(patterns.count)件のパターンを提案しました\(purposeNote)。カードをタップして詳細・地図を確認できます。"
        }
    }

    /// Places all stops of a pattern onto the calendar (skips conflicting stops).
    @discardableResult
    func applyPattern(_ pattern: OutingPattern) -> Int {
        var added = 0
        for stop in pattern.stops {
            let plan = OutingPlan(
                eventId: stop.event.id,
                scheduledStart: stop.scheduledStart,
                scheduledEnd: stop.scheduledEnd
            )
            if ScheduleHelper.conflicts(among: plans, candidate: plan) {
                continue
            }
            insertPlan(plan)
            added += 1
        }
        if added > 0 {
            selectedWeekDate = pattern.stops.first?.scheduledStart ?? selectedWeekDate
            selectedTab = .calendar
        }
        return added
    }

    /// Drag-reschedule: vertical minutes + optional day shift.
    func reschedule(
        _ plan: OutingPlan,
        minuteDelta: Int,
        dayDelta: Int = 0,
        dayStartHour: Int = 9,
        dayEndHour: Int = 22
    ) {
        guard let index = plans.firstIndex(where: { $0.id == plan.id }) else { return }

        let calendar = Calendar.current
        let duration = max(
            30,
            Int(plan.scheduledEnd.timeIntervalSince(plan.scheduledStart) / 60)
        )

        let baseDay = calendar.startOfDay(for: plan.scheduledStart)
        let targetDay = calendar.date(byAdding: .day, value: dayDelta, to: baseDay) ?? baseDay
        let shiftedStart = calendar.date(
            byAdding: .minute,
            value: minuteDelta,
            to: plan.scheduledStart
        ) ?? plan.scheduledStart

        let timeComponents = calendar.dateComponents(
            [.hour, .minute],
            from: shiftedStart
        )
        var dayComponents = calendar.dateComponents([.year, .month, .day], from: targetDay)
        dayComponents.hour = timeComponents.hour
        dayComponents.minute = timeComponents.minute
        let combinedStart = calendar.date(from: dayComponents) ?? shiftedStart

        let slot = ScheduleHelper.clampedSlot(
            start: combinedStart,
            durationMinutes: duration,
            on: targetDay,
            dayStartHour: dayStartHour,
            dayEndHour: dayEndHour
        )

        var updated = plans[index]
        updated.scheduledStart = slot.start
        updated.scheduledEnd = slot.end
        plans[index] = updated
        persistPlans()
        selectedWeekDate = targetDay
    }

    private func insertPlan(_ plan: OutingPlan) {
        plans.append(plan)
        persistPlans()
    }

    private func persistPlans() {
        planStore.saveAll(plans)
    }

    private func suggestedDay(for event: OutingEvent) -> Date {
        if let startAt = event.startAt {
            return Calendar.current.startOfDay(for: startAt)
        }
        return Calendar.current.startOfDay(for: selectedWeekDate)
    }
}

enum AppTab: Hashable {
    case proposals
    case slot
    case calendar
}
