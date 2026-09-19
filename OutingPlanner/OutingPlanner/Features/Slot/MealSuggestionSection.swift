//
//  MealSuggestionSection.swift
//  OutingPlanner
//

import SwiftUI

/// Meal suggestions with inline cuisine + shop-name search.
struct MealSuggestionSection: View {
    let kind: MealKind
    @Bindable var draft: PatternDraft
    let restaurants: [OutingEvent]
    var onOpenFullSearch: () -> Void

    @State private var selectedCuisine: FoodCuisine?
    @State private var shopQuery = ""
    @State private var liveResults: [OutingEvent] = []
    @State private var isSearchingLive = false

    private var itinerary: MealSearchContext {
        draft.mealSearchContext(for: kind)
    }

    private var currentMealID: String {
        draft.stops.first {
            $0.isMealStop && $0.id.contains(kind.rawValue)
        }?.event.id ?? ""
    }

    private var nearStation: TokyoStation? {
        draft.window.resolvedStation
            ?? TokyoStationCatalog.resolve(draft.anchorStationName ?? "")
    }

    private var displayedRestaurants: [OutingEvent] {
        if searchActive {
            return liveResults
        }

        let stickers = draft.mealStickers(for: kind)
        if !stickers.isEmpty { return stickers }

        return RestaurantSearch.search(
            query: "",
            cuisine: nil,
            in: restaurants,
            nearStation: nearStation,
            itinerary: itinerary,
            limit: 8
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(kind.label)の提案")
                    .font(.headline)
                    .foregroundStyle(DesignTokens.ink)
                Spacer()
                Text(timeLabel(draft.mealTime(kind)))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DesignTokens.sky)
            }

            Text("ジャンルや店名で絞り込めます。店名検索はAppleマップも使います。")
                .font(.caption)
                .foregroundStyle(DesignTokens.muted)

            cuisineRow

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(DesignTokens.muted)
                TextField("店名で検索（例: 叙々苑、AFURI）", text: $shopQuery)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if isSearchingLive {
                    ProgressView()
                        .controlSize(.small)
                }
                if !shopQuery.isEmpty {
                    Button {
                        shopQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(DesignTokens.muted)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(DesignTokens.mist)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(DesignTokens.border, lineWidth: 1)
            )

            Button(action: onOpenFullSearch) {
                Label("ジャンル・店名で詳しく探す", systemImage: "slider.horizontal.3")
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(DesignTokens.sky)
                    .foregroundStyle(DesignTokens.onAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(DesignTokens.border, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            if displayedRestaurants.isEmpty {
                Text(emptyMessage)
                    .font(.caption)
                    .foregroundStyle(DesignTokens.muted)
                    .padding(.vertical, 4)
            } else {
                AlternativeStickerBar(
                    alternatives: displayedRestaurants,
                    currentID: currentMealID,
                    title: searchActive ? "検索結果" : "食事ステッカー",
                    onSelect: { restaurant in
                        draft.addMealSticker(restaurant, kind: kind)
                        draft.applyMeal(restaurant, kind: kind)
                    },
                    onDelete: { restaurant in
                        draft.removeMealSticker(restaurant, kind: kind)
                        if currentMealID == restaurant.id {
                            draft.removeMeal(kind: kind)
                        }
                    },
                    onAdd: onOpenFullSearch
                )
            }

            if !currentMealID.isEmpty {
                Button {
                    draft.removeMeal(kind: kind)
                } label: {
                    Label("行程から\(kind.label)を外す", systemImage: "trash")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DesignTokens.coral)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .flatCard(cornerRadius: 14)
        .task(id: "\(shopQuery)|\(selectedCuisine?.rawValue ?? "")") {
            await refreshLiveResults()
        }
    }

    private var searchActive: Bool {
        !shopQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || selectedCuisine != nil
    }

    private var emptyMessage: String {
        if searchActive {
            return "条件に合う店が見つかりません。「詳しく探す」からマップ検索・食べログ追加ができます。"
        }
        return "近くの食事候補がありません。「詳しく探す」から店名で追加してください。"
    }

    private func refreshLiveResults() async {
        guard searchActive else {
            liveResults = []
            isSearchingLive = false
            return
        }
        isSearchingLive = true
        try? await Task.sleep(nanoseconds: 280_000_000)
        guard !Task.isCancelled else { return }

        let found = await RestaurantSearch.searchWithMaps(
            query: shopQuery,
            cuisine: selectedCuisine,
            in: restaurants,
            nearStation: nearStation,
            areaHint: nearStation?.name ?? draft.stops.first?.event.area,
            itinerary: itinerary,
            limit: 12
        )
        guard !Task.isCancelled else { return }
        liveResults = found
        isSearchingLive = false
    }

    private var cuisineRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ジャンル")
                .font(.caption.weight(.semibold))
                .foregroundStyle(DesignTokens.muted)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    cuisineChip(nil, label: "すべて")
                    ForEach(FoodCuisine.allCases) { cuisine in
                        cuisineChip(cuisine, label: cuisine.rawValue)
                    }
                }
            }
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
                .background(selected ? DesignTokens.sky : DesignTokens.card)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(selected ? DesignTokens.sky : DesignTokens.border, lineWidth: selected ? 2 : 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func timeLabel(_ date: Date) -> String {
        date.formatted(
            Date.FormatStyle(date: .omitted, time: .shortened)
                .locale(Locale(identifier: "ja_JP"))
        )
    }
}
