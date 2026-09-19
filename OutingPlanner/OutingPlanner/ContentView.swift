//
//  ContentView.swift
//  OutingPlanner
//
//  Created by 庄司吉希 on 2026/09/19.
//

import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @Environment(ThemeStore.self) private var themeStore

    var body: some View {
        @Bindable var model = model

        ZStack(alignment: .bottom) {
            Group {
                switch model.selectedTab {
                case .proposals:
                    ProposalsView()
                case .slot:
                    SlotProposalView()
                case .calendar:
                    WeekCalendarView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            FloatingTabBar(selection: $model.selectedTab)
        }
        .tint(themeStore.palette.sky)
        .preferredColorScheme(.light)
    }
}

#Preview {
    ContentView()
        .environment(AppModel())
        .environment(ThemeStore())
}
