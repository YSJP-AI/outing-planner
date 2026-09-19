//
//  PurposePickerView.swift
//  OutingPlanner
//

import SwiftUI

struct PurposePickerView: View {
    @Binding var purpose: OutingPurpose
    var title: String = "だれと行く？"

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .fontDesign(.rounded)
                .foregroundStyle(DesignTokens.ink)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(OutingPurpose.allCases) { option in
                        purposeChip(option)
                    }
                }
            }

            Text(purpose.shortHint)
                .font(.caption2)
                .foregroundStyle(DesignTokens.muted)
        }
    }

    private func purposeChip(_ option: OutingPurpose) -> some View {
        let selected = purpose == option
        return Button {
            purpose = option
        } label: {
            HStack(spacing: 6) {
                Image(systemName: option.iconName)
                    .font(.caption.weight(.semibold))
                Text(option.label)
                    .font(.caption.weight(.semibold))
            }
            .softPill(selected: selected)
        }
        .buttonStyle(.plain)
    }
}
