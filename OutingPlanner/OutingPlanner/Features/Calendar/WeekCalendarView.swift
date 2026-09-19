//
//  WeekCalendarView.swift
//  OutingPlanner
//

import SwiftUI

struct WeekCalendarView: View {
    @Environment(AppModel.self) private var model
    @State private var dragTranslation: [UUID: CGSize] = [:]

    private let hourHeight: CGFloat = 60
    private let dayWidth: CGFloat = 118
    private let gutterWidth: CGFloat = 52
    private let dayHeaderHeight: CGFloat = 52
    private let dayStartHour = 9
    private let dayEndHour = 22

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                BlueHeroBanner(
                    eyebrow: "WEEKLY",
                    title: "週間カレンダー",
                    subtitle: weekTitle,
                    trailing: AnyView(
                        HStack(spacing: 8) {
                            ThemePickerButton(compact: true, onHero: true)
                            Button("今週") {
                                model.selectedWeekDate = .now
                            }
                            .font(.caption.weight(.bold))
                            .foregroundStyle(DesignTokens.sky)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.white)
                            .clipShape(Capsule(style: .continuous))
                        }
                    )
                )

                weekHeader
                hintBar
                Divider().overlay(DesignTokens.border.opacity(0.6))
                ScrollView(.vertical, showsIndicators: true) {
                    HStack(alignment: .top, spacing: 0) {
                        timeGutter
                        ScrollView(.horizontal, showsIndicators: true) {
                            HStack(alignment: .top, spacing: 0) {
                                ForEach(model.weekDates, id: \.self) { day in
                                    dayColumn(for: day)
                                }
                            }
                            .padding(.trailing, 12)
                        }
                    }
                    .padding(.bottom, 110)
                }
            }
            .flatCanvasBackground()
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var weekHeader: some View {
        HStack(spacing: 12) {
            Button {
                shiftWeek(by: -7)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(DesignTokens.sky)
                    .frame(width: 36, height: 36)
                    .background(DesignTokens.mist)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            VStack(spacing: 2) {
                Text("予定 \(model.plans.count)件")
                    .font(.subheadline.weight(.bold))
                    .fontDesign(.rounded)
                    .foregroundStyle(DesignTokens.ink)
                Text("ブロックをドラッグして時間・曜日を変更")
                    .font(.caption2)
                    .foregroundStyle(DesignTokens.muted)
            }
            .frame(maxWidth: .infinity)

            Button {
                shiftWeek(by: 7)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(DesignTokens.sky)
                    .frame(width: 36, height: 36)
                    .background(DesignTokens.mist)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(DesignTokens.card.opacity(0.92))
    }

    private var hintBar: some View {
        EmptyView()
    }

    private var weekTitle: String {
        guard let first = model.weekDates.first, let last = model.weekDates.last else {
            return "週間"
        }
        let style = Date.FormatStyle(date: .abbreviated, time: .omitted).locale(Locale(identifier: "ja_JP"))
        return "\(first.formatted(style)) – \(last.formatted(style))"
    }

    private var timeGutter: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Color.clear.frame(width: gutterWidth, height: dayHeaderHeight)
            ForEach(dayStartHour..<dayEndHour, id: \.self) { hour in
                Text(hourLabel(hour))
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Color(red: 0.12, green: 0.14, blue: 0.18))
                    .frame(width: gutterWidth, height: hourHeight, alignment: .topTrailing)
                    .padding(.trailing, 8)
                    .offset(y: -7)
            }
        }
        .frame(width: gutterWidth)
        .background(DesignTokens.canvas)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(DesignTokens.border)
                .frame(width: 1)
        }
        .zIndex(2)
    }

    private func dayColumn(for day: Date) -> some View {
        let calendar = Calendar.current
        let isToday = calendar.isDateInToday(day)
        let dayPlans = model.plans(on: day)

        return VStack(spacing: 0) {
            dayHeader(day: day, isToday: isToday)

            ZStack(alignment: .topLeading) {
                hourGrid(isToday: isToday)

                if dayPlans.isEmpty {
                    Text("予定なし")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(DesignTokens.muted)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .padding(.top, 12)
                }

                ForEach(dayPlans) { plan in
                    planBlock(plan: plan, event: model.event(for: plan), day: day)
                }
            }
            .frame(
                width: dayWidth,
                height: CGFloat(dayEndHour - dayStartHour) * hourHeight,
                alignment: .top
            )
            .background(isToday ? DesignTokens.sky.opacity(0.06) : DesignTokens.card)
            .overlay(alignment: .trailing) {
                Rectangle()
                    .fill(DesignTokens.border)
                    .frame(width: 1)
            }
        }
    }

    private func dayHeader(day: Date, isToday: Bool) -> some View {
        VStack(spacing: 2) {
            Text(day.formatted(.dateTime.weekday(.wide).locale(Locale(identifier: "ja_JP"))))
                .font(.caption2.weight(.bold))
                .foregroundStyle(isToday ? DesignTokens.onAccent.opacity(0.9) : DesignTokens.muted)
            Text(day.formatted(.dateTime.day()))
                .font(.title3.weight(.bold))
                .fontDesign(.rounded)
                .foregroundStyle(isToday ? DesignTokens.onAccent : DesignTokens.ink)
        }
        .frame(width: dayWidth, height: dayHeaderHeight)
        .background {
            if isToday {
                DesignTokens.accentGradient
            } else {
                DesignTokens.mist
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.bottom, 4)
    }

    private func hourGrid(isToday: Bool) -> some View {
        VStack(spacing: 0) {
            ForEach(Array((dayStartHour..<dayEndHour).enumerated()), id: \.element) { index, _ in
                ZStack(alignment: .top) {
                    Rectangle()
                        .fill(index.isMultiple(of: 2) ? Color.clear : DesignTokens.mist.opacity(0.55))
                    Rectangle()
                        .fill(DesignTokens.border)
                        .frame(height: 1)
                        .opacity(0.9)
                }
                .frame(width: dayWidth, height: hourHeight)
            }
        }
    }

    private func planBlock(plan: OutingPlan, event: OutingEvent?, day: Date) -> some View {
        let translation = dragTranslation[plan.id] ?? .zero
        let offset = yOffset(for: plan.scheduledStart, on: day) + translation.height
        let height = max(blockHeight(for: plan), 36)
        let conflict = ScheduleHelper.conflicts(among: model.plans, candidate: plan)
        let tint = conflict ? DesignTokens.coral : DesignTokens.genreColor(event?.genres.first ?? "")
        let title = event?.title ?? model.displayTitle(for: plan)
        let isDragging = translation != .zero

        return HStack(alignment: .top, spacing: 0) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(tint)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(DesignTokens.ink)
                    .lineLimit(height < 50 ? 1 : 2)
                Text(timeRangeLabel(plan))
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(DesignTokens.ink.opacity(0.75))
                if height >= 70, let area = event?.area {
                    Text(area)
                        .font(.caption2)
                        .foregroundStyle(DesignTokens.muted)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: dayWidth - 8, height: height, alignment: .topLeading)
        .background(DesignTokens.card)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(tint, lineWidth: conflict ? 2 : 1.5)
        )
        .shadow(color: DesignTokens.ink.opacity(isDragging ? 0.18 : 0.06), radius: isDragging ? 8 : 2, y: isDragging ? 4 : 1)
        .padding(.leading, 4)
        .offset(x: translation.width, y: offset)
        .zIndex(isDragging ? 10 : 1)
        .highPriorityGesture(dragGesture(for: plan))
        .contextMenu {
            Button(role: .destructive) {
                model.removePlan(plan)
            } label: {
                Label("削除", systemImage: "trash")
            }
        }
        .accessibilityHint("ドラッグして時間を変更")
    }

    private func dragGesture(for plan: OutingPlan) -> some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                dragTranslation[plan.id] = value.translation
            }
            .onEnded { value in
                let minuteDelta = ScheduleHelper.minuteDelta(
                    forTranslationY: value.translation.height,
                    hourHeight: hourHeight
                )
                let dayDelta = ScheduleHelper.dayDelta(
                    forTranslationX: value.translation.width,
                    dayWidth: dayWidth
                )
                dragTranslation[plan.id] = nil
                guard minuteDelta != 0 || dayDelta != 0 else { return }
                model.reschedule(
                    plan,
                    minuteDelta: minuteDelta,
                    dayDelta: dayDelta,
                    dayStartHour: dayStartHour,
                    dayEndHour: dayEndHour
                )
            }
    }

    private func hourLabel(_ hour: Int) -> String {
        String(format: "%d:00", hour)
    }

    private func yOffset(for date: Date, on day: Date) -> CGFloat {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: day)
        let minutes = calendar.dateComponents([.minute], from: startOfDay, to: date).minute ?? 0
        let relative = CGFloat(minutes - dayStartHour * 60)
        return max(0, relative / 60 * hourHeight)
    }

    private func blockHeight(for plan: OutingPlan) -> CGFloat {
        let minutes = max(30, plan.scheduledEnd.timeIntervalSince(plan.scheduledStart) / 60)
        return CGFloat(minutes / 60) * hourHeight
    }

    private func timeRangeLabel(_ plan: OutingPlan) -> String {
        let style = Date.FormatStyle(date: .omitted, time: .shortened).locale(Locale(identifier: "ja_JP"))
        return "\(plan.scheduledStart.formatted(style))–\(plan.scheduledEnd.formatted(style))"
    }

    private func shiftWeek(by days: Int) {
        if let next = Calendar.current.date(byAdding: .day, value: days, to: model.selectedWeekDate) {
            model.selectedWeekDate = next
        }
    }
}
