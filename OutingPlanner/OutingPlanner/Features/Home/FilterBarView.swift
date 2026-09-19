//
//  FilterBarView.swift
//  OutingPlanner
//

import SwiftUI

struct FilterBarView: View {
    @Binding var filters: OutingFilters

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PurposePickerView(purpose: $filters.purpose)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(GenreDefaults.knownGenres, id: \.self) { genre in
                        let selected = filters.selectedGenres.contains(genre)
                        Button {
                            if selected {
                                filters.selectedGenres.remove(genre)
                            } else {
                                filters.selectedGenres.insert(genre)
                            }
                        } label: {
                            Text(genre)
                                .font(.caption.weight(.semibold))
                                .softPill(selected: selected)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)
            }

            HStack(spacing: 10) {
                TextField("エリア（例: 上野, 渋谷）", text: $filters.areaQuery)
                    .textFieldStyle(.roundedBorder)

                Menu {
                    Button("指定なし") { filters.maxBudget = nil }
                    Button("〜¥2,000") { filters.maxBudget = 2000 }
                    Button("〜¥4,000") { filters.maxBudget = 4000 }
                    Button("〜¥8,000") { filters.maxBudget = 8000 }
                } label: {
                    Label(
                        filters.maxBudget.map { "〜¥\($0.formatted())" } ?? "予算",
                        systemImage: "yensign.circle"
                    )
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(DesignTokens.card)
                    .foregroundStyle(DesignTokens.ink)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(DesignTokens.border, lineWidth: 1)
                    )
                }

                Toggle(isOn: $filters.weekendOnly) {
                    Text("週末")
                        .font(.caption.weight(.semibold))
                }
                .toggleStyle(.button)
            }

            if !filters.isEmpty {
                Button("フィルターをクリア") {
                    filters.reset()
                }
                .font(.caption)
                .foregroundStyle(DesignTokens.coral)
            }
        }
    }
}
