//
//  RestaurantSearchSheet.swift
//  OutingPlanner
//

import SwiftUI

struct RestaurantSearchSheet: View {
    let restaurants: [OutingEvent]
    let station: TokyoStation?
    var areaHint: String?
    var allowsCustomTabelog: Bool = true
    var showsCuisineFilter: Bool = false
    /// When false, search general POIs (spots) via MapKit instead of restaurants only.
    var searchesRestaurants: Bool = true
    var itinerary: MealSearchContext = .empty
    var navigationTitleText: String = "食事の店名検索"
    var placeholder: String = "店名で検索（例: 叙々苑、AFURI）"
    var onPick: (OutingEvent) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var customName = ""
    @State private var selectedCuisine: FoodCuisine?
    @State private var results: [OutingEvent] = []
    @State private var isSearching = false
    @State private var searchError: String?

    var body: some View {
        NavigationStack {
            List {
                if showsCuisineFilter {
                    Section {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                cuisineChip(nil, label: "すべて")
                                ForEach(FoodCuisine.allCases) { cuisine in
                                    cuisineChip(cuisine, label: cuisine.rawValue)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                    } header: {
                        Text("ジャンル")
                    } footer: {
                        Text("ジャンルと店名を組み合わせて探せます。Appleマップとアプリ内カタログから候補を出します。")
                    }
                }

                Section {
                    TextField(placeholder, text: $query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                } header: {
                    Text(showsCuisineFilter ? "店名" : "名前検索")
                } footer: {
                    Text(
                        allowsCustomTabelog
                            ? "店名を入力するとAppleマップでも検索します。見つからない場合は下から食べログ検索用に追加できます。"
                            : "スポット名やエリア名で候補を絞り込めます。"
                    )
                }

                Section {
                    if isSearching {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("マップで検索中…")
                                .foregroundStyle(DesignTokens.muted)
                        }
                    } else if let searchError {
                        Text(searchError)
                            .foregroundStyle(DesignTokens.coral)
                    } else if results.isEmpty {
                        Text(emptyResultsText)
                            .foregroundStyle(DesignTokens.muted)
                    } else {
                        ForEach(results) { restaurant in
                            Button {
                                onPick(restaurant)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(restaurant.title)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(DesignTokens.ink)
                                    HStack(spacing: 6) {
                                        Text(restaurant.area)
                                        if let cuisine = FoodCuisine.labels(for: restaurant).first {
                                            Text("·")
                                            Text(cuisine)
                                        }
                                        Text("·")
                                        Text(sourceLabel(for: restaurant))
                                    }
                                    .font(.caption)
                                    .foregroundStyle(DesignTokens.muted)
                                    if let note = RestaurantSearch.travelNote(for: restaurant, context: itinerary) {
                                        Text(note)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(DesignTokens.leaf)
                                    }
                                    if let summary = restaurant.summary {
                                        Text(summary)
                                            .font(.caption2)
                                            .foregroundStyle(DesignTokens.muted)
                                            .lineLimit(2)
                                    }
                                }
                            }
                        }
                    }
                } header: {
                    Text("検索結果")
                }

                if allowsCustomTabelog {
                    Section {
                        TextField("追加する店名", text: $customName)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Button {
                            if let custom = RestaurantSearch.makeCustomRestaurant(
                                name: customName.isEmpty ? query : customName,
                                cuisine: selectedCuisine,
                                area: areaHint ?? station?.name,
                                station: station,
                                nearEvent: itinerary.before ?? itinerary.after
                            ) {
                                onPick(custom)
                                dismiss()
                            }
                        } label: {
                            Label("食べログ検索用として追加", systemImage: "plus.circle.fill")
                        }
                        .disabled((customName.isEmpty ? query : customName).trimmingCharacters(in: .whitespacesAndNewlines).count < 2)

                        if let url = optionalTabelogURL {
                            Link("食べログで「\(query.isEmpty ? customName : query)」を開く", destination: url)
                        }
                    } header: {
                        Text("見つからないとき")
                    } footer: {
                        Text("店名を追加すると、食べログの検索ページへ飛べるステッカーになります。")
                    }
                }
            }
            .navigationTitle(navigationTitleText)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .task(id: searchTaskID) {
                await refreshResults()
            }
        }
    }

    private var searchTaskID: String {
        "\(query)|\(selectedCuisine?.rawValue ?? "")|\(station?.id ?? "")"
    }

    private var emptyResultsText: String {
        if !query.isEmpty || selectedCuisine != nil {
            return "条件に合う候補が見つかりません。別の店名で試すか、下から食べログ用に追加できます。"
        }
        return "近くの候補を表示中…"
    }

    private var optionalTabelogURL: URL? {
        let name = (customName.isEmpty ? query : customName)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.count >= 2 else { return nil }
        return RestaurantSearch.tabelogSearchURL(
            name: name,
            cuisine: selectedCuisine,
            area: areaHint ?? station?.name
        )
    }

    private func sourceLabel(for event: OutingEvent) -> String {
        if event.id.hasPrefix("mk-") { return "Appleマップ" }
        return event.source.displayName
    }

    private func refreshResults() async {
        isSearching = true
        searchError = nil
        // Debounce typing slightly.
        try? await Task.sleep(nanoseconds: 280_000_000)
        guard !Task.isCancelled else { return }

        let found: [OutingEvent]
        if searchesRestaurants {
            found = await RestaurantSearch.searchWithMaps(
                query: query,
                cuisine: showsCuisineFilter ? selectedCuisine : nil,
                in: restaurants,
                nearStation: station,
                areaHint: areaHint,
                itinerary: itinerary,
                limit: 24
            )
        } else {
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            let catalog: [OutingEvent]
            if trimmed.isEmpty {
                catalog = Array(restaurants.prefix(12))
            } else {
                catalog = restaurants.filter {
                    $0.title.localizedCaseInsensitiveContains(trimmed)
                        || $0.area.localizedCaseInsensitiveContains(trimmed)
                        || ($0.venue?.localizedCaseInsensitiveContains(trimmed) ?? false)
                }
            }
            let liveQuery = trimmed.isEmpty
                ? (areaHint ?? station?.name ?? "観光スポット")
                : trimmed
            let live = await MapKitPlaceSearch.searchSpots(
                query: liveQuery,
                near: station?.coordinate,
                areaHint: areaHint ?? station?.name,
                limit: 20
            )
            var seen = Set<String>()
            var merged: [OutingEvent] = []
            for event in live + catalog {
                let key = event.title.lowercased()
                if seen.contains(key) { continue }
                seen.insert(key)
                merged.append(event)
                if merged.count >= 24 { break }
            }
            found = merged
        }
        guard !Task.isCancelled else { return }
        results = found
        isSearching = false
        if found.isEmpty, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            searchError = nil
        }
    }

    private func cuisineChip(_ cuisine: FoodCuisine?, label: String) -> some View {
        let selected = selectedCuisine == cuisine
        return Button {
            selectedCuisine = cuisine
        } label: {
            Text(label)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .foregroundStyle(selected ? DesignTokens.onAccent : DesignTokens.ink)
                .background(selected ? DesignTokens.sky : DesignTokens.mist)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(DesignTokens.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
