//
//  SlotProposalView.swift
//  OutingPlanner
//

import SwiftUI
import UIKit

struct SlotProposalView: View {
    @Environment(AppModel.self) private var model
    @FocusState private var isStationFieldFocused: Bool

    var body: some View {
        @Bindable var model = model

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    BlueHeroBanner(
                        eyebrow: "TIME SLOT",
                        title: "日時と最寄駅からプラン提案",
                        subtitle: "駅は任意。指定すると、その駅から近いスポットを優先します。",
                        trailing: AnyView(ThemePickerButton(compact: true, onHero: true))
                    )

                    VStack(alignment: .leading, spacing: 18) {
                        inputCard
                        actionRow

                        if let message = model.slotPatternMessage {
                            Text(message)
                                .font(.footnote)
                                .foregroundStyle(DesignTokens.muted)
                        }

                        if !model.slotPatterns.isEmpty {
                            Text("提案パターン")
                                .font(.headline)
                                .fontDesign(.rounded)
                                .foregroundStyle(DesignTokens.ink)

                            LazyVStack(spacing: 12) {
                                ForEach(model.slotPatterns) { pattern in
                                    NavigationLink {
                                        PatternDetailView(
                                            pattern: pattern,
                                            window: model.slotRequest,
                                            restaurants: model.restaurants
                                        )
                                    } label: {
                                        PatternCardView(pattern: pattern)
                                    }
                                    .buttonStyle(.plain)
                                    .simultaneousGesture(TapGesture().onEnded { dismissKeyboard() })
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 18)
                    .padding(.bottom, 100)
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .flatCanvasBackground()
            .toolbar(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完了") {
                        dismissKeyboard()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                if model.slotPatterns.isEmpty {
                    model.generateSlotPatterns()
                }
            }
        }
    }

    private func dismissKeyboard() {
        isStationFieldFocused = false
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

    private var inputCard: some View {
        @Bindable var model = model

        return VStack(alignment: .leading, spacing: 14) {
            labeledDatePicker(
                title: "開始",
                selection: $model.slotRequest.start,
                components: [.date, .hourAndMinute]
            )

            labeledDatePicker(
                title: "終了",
                selection: $model.slotRequest.end,
                components: [.date, .hourAndMinute],
                lowerBound: model.slotRequest.start
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("希望の最寄駅（任意）")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DesignTokens.ink)
                TextField("駅名を入力（例: 上野、下北沢、北千住）", text: $model.slotRequest.preferredStation)
                    .textFieldStyle(.roundedBorder)
                    .foregroundStyle(DesignTokens.ink)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($isStationFieldFocused)
                    .submitLabel(.done)
                    .onSubmit { dismissKeyboard() }
                    .onChange(of: model.slotRequest.preferredStation) { _, newValue in
                        // Clear stale MapKit override when editing; regenerate will re-resolve.
                        if TokyoStationCatalog.resolve(newValue) != nil
                            || newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            model.slotRequest.resolvedStationOverride = nil
                        }
                    }

                if let resolved = model.slotRequest.resolvedStation {
                    Label("認識: \(resolved.name)駅", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DesignTokens.leaf)
                } else if !model.slotRequest.preferredStation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("候補にない駅名は、提案時にマップから位置を調べます。サジェストからも選べます。")
                        .font(.caption2)
                        .foregroundStyle(DesignTokens.muted)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(TokyoStationCatalog.suggestions(matching: model.slotRequest.preferredStation)) { station in
                            Button(station.name) {
                                model.slotRequest.preferredStation = station.name
                                model.slotRequest.resolvedStationOverride = nil
                                dismissKeyboard()
                            }
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                model.slotRequest.resolvedStation?.id == station.id
                                    ? DesignTokens.leaf.opacity(0.35)
                                    : DesignTokens.mist
                            )
                            .foregroundStyle(DesignTokens.ink)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(DesignTokens.border, lineWidth: 1)
                            )
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                PurposePickerView(
                    purpose: Binding(
                        get: { model.slotRequest.purpose },
                        set: {
                            dismissKeyboard()
                            model.slotRequest.purpose = $0
                            model.filters.purpose = $0
                        }
                    )
                )
            }

            HStack {
                Label(durationLabel, systemImage: "clock")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DesignTokens.sky)
                Spacer()
                durationPresets
            }

            mealOptions
        }
        .padding(16)
        .foregroundStyle(DesignTokens.ink)
        .tint(DesignTokens.sky)
        .flatCard(cornerRadius: 20)
        .onChange(of: model.slotRequest.start) { _, _ in
            model.slotRequest.syncMealTimesToStartDay()
        }
    }

    private var mealOptions: some View {
        @Bindable var model = model

        return VStack(alignment: .leading, spacing: 12) {
            Text("食事の希望（任意）")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DesignTokens.ink)

            labeledToggle(title: "昼食を入れる", isOn: $model.slotRequest.lunchEnabled)
            if model.slotRequest.lunchEnabled {
                labeledDatePicker(
                    title: "昼食の時間",
                    selection: $model.slotRequest.lunchTime,
                    components: [.hourAndMinute]
                )
            }

            labeledToggle(title: "夕食を入れる", isOn: $model.slotRequest.dinnerEnabled)
            if model.slotRequest.dinnerEnabled {
                labeledDatePicker(
                    title: "夕食の時間",
                    selection: $model.slotRequest.dinnerTime,
                    components: [.hourAndMinute]
                )
            }

            Text("ONにすると、プラン詳細でジャンル・店名検索から食事場所を選べます。")
                .font(.caption2)
                .foregroundStyle(DesignTokens.muted)
        }
    }

    private func labeledToggle(title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: Binding(
            get: { isOn.wrappedValue },
            set: { newValue in
                dismissKeyboard()
                isOn.wrappedValue = newValue
            }
        )) {
            Text(title)
                .font(.body.weight(.medium))
                .foregroundStyle(DesignTokens.ink)
        }
        .tint(DesignTokens.sky)
    }

    private func labeledDatePicker(
        title: String,
        selection: Binding<Date>,
        components: DatePickerComponents,
        lowerBound: Date? = nil
    ) -> some View {
        HStack {
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(DesignTokens.ink)
            Spacer(minLength: 8)
            Group {
                if let lowerBound {
                    DatePicker(
                        "",
                        selection: selection,
                        in: lowerBound...,
                        displayedComponents: components
                    )
                } else {
                    DatePicker(
                        "",
                        selection: selection,
                        displayedComponents: components
                    )
                }
            }
            .labelsHidden()
            .environment(\.locale, Locale(identifier: "ja_JP"))
            .tint(DesignTokens.sky)
            .colorScheme(.light)
            .onTapGesture { dismissKeyboard() }
        }
        .padding(.vertical, 4)
    }

    private var durationPresets: some View {
        @Bindable var model = model

        return HStack(spacing: 6) {
            ForEach([120, 180, 240, 300], id: \.self) { minutes in
                Button(minutes >= 60 ? "\(minutes / 60)h" : "\(minutes)分") {
                    dismissKeyboard()
                    model.slotRequest.end = model.slotRequest.start.addingTimeInterval(TimeInterval(minutes * 60))
                }
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(DesignTokens.mist)
                .foregroundStyle(DesignTokens.ink)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(DesignTokens.border, lineWidth: 1)
                )
                .buttonStyle(.plain)
            }
        }
    }

    private var actionRow: some View {
        Button {
            dismissKeyboard()
            model.generateSlotPatterns()
        } label: {
            Label("この条件でパターン提案", systemImage: "sparkles")
        }
        .buttonStyle(BluePrimaryButtonStyle())
    }

    private var durationLabel: String {
        let minutes = model.slotRequest.durationMinutes
        if minutes < 60 { return "\(minutes)分" }
        let hours = minutes / 60
        let rem = minutes % 60
        return rem == 0 ? "\(hours)時間" : "\(hours)時間\(rem)分"
    }
}
