//
//  PatternDetailView.swift
//  OutingPlanner
//

import MapKit
import SwiftUI

struct PatternDetailView: View {
    @Environment(AppModel.self) private var model
    @State private var draft: PatternDraft
    @State private var applyMessage: String?
    @State private var cameraPosition: MapCameraPosition
    @State private var searchTarget: SearchTarget?

    private enum SearchTarget: Identifiable {
        case meal(MealKind)
        case stop(Int)

        var id: String {
            switch self {
            case .meal(let kind): "meal-\(kind.rawValue)"
            case .stop(let index): "stop-\(index)"
            }
        }
    }

    init(pattern: OutingPattern, window: TimeSlotRequest, restaurants: [OutingEvent] = []) {
        _draft = State(initialValue: PatternDraft(pattern: pattern, window: window, restaurants: restaurants))
        _cameraPosition = State(initialValue: Self.initialCamera(for: pattern))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                if !draft.allWarnings.isEmpty {
                    warningBanner
                }
                meetingPlaceSection
                mealSections
                itineraryMap
                timelineEditor
                applyButton
                if let applyMessage {
                    Text(applyMessage)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(draft.isFeasible ? DesignTokens.leaf : DesignTokens.coral)
                }
            }
            .padding(16)
            .padding(.bottom, 24)
        }
        .flatCanvasBackground()
        .navigationTitle("プラン詳細")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ThemePickerButton()
            }
        }
        .onChange(of: draft.stops) { _, _ in
            cameraPosition = Self.initialCamera(for: draft.toPattern())
        }
        .sheet(item: $searchTarget) { target in
            switch target {
            case .meal(let kind):
                RestaurantSearchSheet(
                    restaurants: model.restaurants,
                    station: draft.window.resolvedStation
                        ?? TokyoStationCatalog.resolve(draft.anchorStationName ?? ""),
                    areaHint: draft.anchorStationName,
                    allowsCustomTabelog: true,
                    showsCuisineFilter: true,
                    itinerary: draft.mealSearchContext(for: kind),
                    navigationTitleText: "\(kind.label)をジャンル・店名で探す",
                    placeholder: "店名で検索（例: 叙々苑、AFURI、ラーメン凪）"
                ) { restaurant in
                    draft.addMealSticker(restaurant, kind: kind)
                    draft.applyMeal(restaurant, kind: kind)
                }
            case .stop:
                RestaurantSearchSheet(
                    restaurants: model.events,
                    station: draft.window.resolvedStation
                        ?? TokyoStationCatalog.resolve(draft.anchorStationName ?? ""),
                    areaHint: draft.anchorStationName,
                    allowsCustomTabelog: false,
                    searchesRestaurants: false,
                    navigationTitleText: "スポット検索",
                    placeholder: "スポット名・店名で検索"
                ) { event in
                    if case .stop(let index) = target {
                        draft.addStopSticker(event, at: index)
                        draft.swap(at: index, with: event)
                    }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(draft.styleLabel)
                .font(.caption.weight(.bold))
                .foregroundStyle(DesignTokens.sky)
            Text(draft.title)
                .font(.title2.weight(.bold))
                .foregroundStyle(DesignTokens.ink)
            Text(draft.subtitle)
                .font(.subheadline)
                .foregroundStyle(DesignTokens.muted)

            HStack(spacing: 12) {
                Label("\(draft.totalDurationMinutes)分", systemImage: "clock")
                if let station = draft.anchorStationName {
                    Label("\(station)駅の近く", systemImage: "tram.fill")
                }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(DesignTokens.muted)

            if let meeting = draft.meetingPlace {
                Label("集合場所: \(meeting.name)", systemImage: "person.3.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DesignTokens.leaf)
                if let meetingTime = draft.meetingTime {
                    Label("集合時間 \(timeLabel(meetingTime))", systemImage: "clock.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DesignTokens.sky)
                }
                Text(meeting.detail)
                    .font(.caption)
                    .foregroundStyle(DesignTokens.muted)
            }

            Text("各スポットの開始時刻を変えられます。移動に足りない場合は自動で後ろへずらします。")
                .font(.caption)
                .foregroundStyle(DesignTokens.muted)
        }
    }

    private var meetingPlaceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("集合場所")
                .font(.headline)
                .foregroundStyle(DesignTokens.ink)
            Text("場所を選ぶと、最初のスポットに間に合う集合時間が表示されます。")
                .font(.caption)
                .foregroundStyle(DesignTokens.muted)

            if let meeting = draft.meetingPlace, let meetingTime = draft.meetingTime {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Label(timeLabel(meetingTime), systemImage: "clock.fill")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(DesignTokens.sky)
                        Text("集合")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(DesignTokens.sky)
                    }
                    Text(meeting.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DesignTokens.ink)
                    let travel = draft.meetingTravelMinutes(for: meeting)
                    if let target = draft.meetingTargetLabel(for: meeting) {
                        Text(
                            travel <= 5
                                ? "\(target)のすぐ近くで合流"
                                : "\(target)まで移動 約\(travel)分"
                        )
                        .font(.caption)
                        .foregroundStyle(DesignTokens.muted)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DesignTokens.mist)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(DesignTokens.border, lineWidth: 1)
                )
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(draft.meetingPlaceOptions) { place in
                        VStack(alignment: .leading, spacing: 6) {
                            Button {
                                draft.selectMeetingPlace(place)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(place.name)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(DesignTokens.ink)
                                        .lineLimit(2)
                                    if let time = draft.meetingTime(for: place) {
                                        Text("\(timeLabel(time)) 集合")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(DesignTokens.sky)
                                    }
                                    Text(place.reason)
                                        .font(.caption2)
                                        .foregroundStyle(DesignTokens.muted)
                                        .lineLimit(2)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .frame(width: 160, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(DesignTokens.card)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(
                                            draft.meetingPlace?.id == place.id
                                                ? DesignTokens.leaf
                                                : DesignTokens.border,
                                            lineWidth: draft.meetingPlace?.id == place.id ? 2 : 1
                                        )
                                )
                            }
                            .buttonStyle(.plain)

                            Button {
                                draft.removeMeetingPlaceSticker(place)
                            } label: {
                                Text("外す")
                                    .font(.caption2)
                                    .foregroundStyle(DesignTokens.muted)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("集合場所ステッカーを削除")
                        }
                    }
                }
            }
        }
        .padding(12)
        .flatCard(cornerRadius: 14)
    }

    private var mealSections: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(MealKind.allCases) { kind in
                if draft.mealEnabled(kind) {
                    MealSuggestionSection(
                        kind: kind,
                        draft: draft,
                        restaurants: model.restaurants
                    ) {
                        searchTarget = .meal(kind)
                    }
                }
            }
        }
    }

    private var warningBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("スケジュール調整", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DesignTokens.coral)
            ForEach(draft.allWarnings, id: \.self) { note in
                Text("・\(note)")
                    .font(.caption)
                    .foregroundStyle(DesignTokens.ink)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.coral.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var itineraryMap: some View {
        let pattern = draft.toPattern()
        return VStack(alignment: .leading, spacing: 8) {
            Text("行程マップ")
                .font(.headline)
                .foregroundStyle(DesignTokens.ink)

            Map(position: $cameraPosition) {
                if let meeting = draft.meetingPlace, let coordinate = meeting.coordinate {
                    Annotation(
                        draft.meetingTime.map { "集合 \(timeLabel($0))" } ?? "集合 \(meeting.name)",
                        coordinate: coordinate
                    ) {
                        Image(systemName: "person.3.sequence.fill")
                            .font(.title3)
                            .foregroundStyle(DesignTokens.leaf)
                            .padding(6)
                            .background(DesignTokens.card, in: Circle())
                            .overlay(Circle().stroke(DesignTokens.border, lineWidth: 1))
                    }
                } else if let stationName = pattern.anchorStationName,
                          let coordinate = pattern.anchorStationCoordinate {
                    Annotation("\(stationName)駅", coordinate: coordinate) {
                        Image(systemName: "tram.circle.fill")
                            .font(.title2)
                            .foregroundStyle(DesignTokens.leaf)
                            .padding(4)
                            .background(DesignTokens.card, in: Circle())
                            .overlay(Circle().stroke(DesignTokens.border, lineWidth: 1))
                    }
                }

                ForEach(Array(pattern.stops.enumerated()), id: \.element.id) { index, stop in
                    if let coordinate = stop.coordinate {
                        Annotation("\(index + 1). \(stop.event.area)", coordinate: coordinate) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(DesignTokens.sky)
                                    .frame(width: 28, height: 28)
                                Text("\(index + 1)")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(DesignTokens.onAccent)
                            }
                        }
                    }
                }

                if pattern.mapCoordinates.count >= 2 {
                    MapPolyline(coordinates: routeCoordinates(for: pattern))
                        .stroke(
                            DesignTokens.sky,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                        )
                }
            }
            .frame(height: 240)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .mapStyle(.standard(elevation: .realistic))
        }
    }

    private var timelineEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("行程の編集")
                .font(.headline)
                .foregroundStyle(DesignTokens.ink)

            ForEach(Array(draft.stops.enumerated()), id: \.element.id) { index, stop in
                stopEditor(index: index, stop: stop)

                if index < draft.stops.count - 1 {
                    travelGapLabel(from: index)
                }
            }
        }
    }

    private func stopEditor(index: Int, stop: EditableStop) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Text("\(index + 1)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(DesignTokens.onAccent)
                    .frame(width: 24, height: 24)
                    .background(DesignTokens.sky)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(stop.event.title)
                            .font(.headline)
                            .foregroundStyle(DesignTokens.ink)
                        if stop.isMealStop {
                            Text("食事")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(DesignTokens.softFill(DesignTokens.sun))
                                .foregroundStyle(DesignTokens.sun)
                                .clipShape(Capsule())
                        }
                    }
                    Text("\(stop.event.area)\(stop.event.venue.map { " · \($0)" } ?? "")")
                        .font(.caption)
                        .foregroundStyle(DesignTokens.muted)
                    Text("滞在 \(stop.durationMinutes)分 · \(stop.event.priceLabel)")
                        .font(.caption2)
                        .foregroundStyle(DesignTokens.muted)
                }

                Spacer(minLength: 0)

                if draft.stops.count > 1 {
                    Button {
                        draft.removeStop(at: index)
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(DesignTokens.coral)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("スポットを削除")
                }
            }

            DatePicker(
                "開始時刻",
                selection: Binding(
                    get: { draft.stops[index].scheduledStart },
                    set: { draft.setStart(at: index, to: $0) }
                ),
                in: draft.window.start...draft.window.end,
                displayedComponents: [.hourAndMinute]
            )
            .environment(\.locale, Locale(identifier: "ja_JP"))

            Text("終了予定 \(timeLabel(stop.scheduledEnd))")
                .font(.caption.weight(.semibold))
                .foregroundStyle(DesignTokens.sky)

            AlternativeStickerBar(
                alternatives: draft.stickers(forStop: index, catalog: model.events),
                currentID: stop.event.id,
                title: "代替ステッカー",
                onSelect: { event in
                    draft.swap(at: index, with: event)
                },
                onDelete: { event in
                    draft.removeStopSticker(event, at: index)
                },
                onAdd: {
                    if stop.isMealStop {
                        if stop.id.contains(MealKind.dinner.rawValue) {
                            searchTarget = .meal(.dinner)
                        } else {
                            searchTarget = .meal(.lunch)
                        }
                    } else {
                        searchTarget = .stop(index)
                    }
                }
            )

            Link(destination: EventInfoLink.primaryURL(for: stop.event)) {
                Label(
                    "公式・詳細ページを開く",
                    systemImage: "safari"
                )
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(DesignTokens.mist)
                .foregroundStyle(DesignTokens.sky)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(DesignTokens.border, lineWidth: 1)
                )
            }
        }
        .padding(12)
        .flatCard(cornerRadius: 14)
    }

    private func travelGapLabel(from index: Int) -> some View {
        let current = draft.stops[index]
        let next = draft.stops[index + 1]
        let needed = ItineraryScheduler.requiredTravel(between: current, and: next)
        let gap = ItineraryScheduler.gapMinutes(between: current, and: next)
        let ok = gap >= needed

        return HStack(spacing: 8) {
            Image(systemName: ok ? "figure.walk" : "exclamationmark.triangle.fill")
                .foregroundStyle(ok ? DesignTokens.leaf : DesignTokens.coral)
            Text("移動 \(needed)分 · 空き \(gap)分")
                .font(.caption.weight(.semibold))
                .foregroundStyle(ok ? DesignTokens.muted : DesignTokens.coral)
            if !ok {
                Text("不足")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(DesignTokens.coral)
            }
        }
        .padding(.leading, 34)
    }

    private var applyButton: some View {
        Button {
            guard draft.isFeasible else {
                applyMessage = "移動時間が足りないか、希望時間を超えています。時刻か代替案を調整してください。"
                return
            }
            let added = model.applyPattern(draft.toPattern())
            if added == 0 {
                applyMessage = "既存予定と重なるため追加できませんでした。"
            } else if added < draft.stops.count {
                applyMessage = "\(added)件追加（一部は重複のためスキップ）"
            } else {
                applyMessage = "\(added)件をカレンダーに追加しました。"
            }
        } label: {
            Label("このプランをカレンダーへ追加", systemImage: "calendar.badge.plus")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(draft.isFeasible ? DesignTokens.leaf : DesignTokens.coral.opacity(0.55))
                .foregroundStyle(DesignTokens.onAccent)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(DesignTokens.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func routeCoordinates(for pattern: OutingPattern) -> [CLLocationCoordinate2D] {
        var coords: [CLLocationCoordinate2D] = []
        if let station = pattern.anchorStationCoordinate {
            coords.append(station)
        }
        coords.append(contentsOf: pattern.mapCoordinates)
        return coords
    }

    private func timeLabel(_ date: Date) -> String {
        date.formatted(
            Date.FormatStyle(date: .omitted, time: .shortened)
                .locale(Locale(identifier: "ja_JP"))
        )
    }

    private static func initialCamera(for pattern: OutingPattern) -> MapCameraPosition {
        var coords = pattern.mapCoordinates
        if let station = pattern.anchorStationCoordinate {
            coords.insert(station, at: 0)
        }
        guard let first = coords.first else {
            return .region(
                MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: 35.68, longitude: 139.76),
                    span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
                )
            )
        }
        guard coords.count > 1 else {
            return .region(
                MKCoordinateRegion(
                    center: first,
                    span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
                )
            )
        }

        let lats = coords.map(\.latitude)
        let lons = coords.map(\.longitude)
        let minLat = lats.min()!
        let maxLat = lats.max()!
        let minLon = lons.min()!
        let maxLon = lons.max()!
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.8, 0.03),
            longitudeDelta: max((maxLon - minLon) * 1.8, 0.03)
        )
        return .region(MKCoordinateRegion(center: center, span: span))
    }
}
