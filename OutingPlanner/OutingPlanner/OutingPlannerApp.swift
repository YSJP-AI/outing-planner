//
//  OutingPlannerApp.swift
//  OutingPlanner
//
//  Created by 庄司吉希 on 2026/09/19.
//

import SwiftUI

@main
struct OutingPlannerApp: App {
    @State private var model = AppModel()
    @State private var themeStore = ThemeStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
                .environment(themeStore)
                .id(themeStore.selectedID)
                .tint(themeStore.palette.sky)
                .onAppear {
                    ThemeStoreBridge.store = themeStore
                }
                .onChange(of: themeStore.selectedID) { _, _ in
                    ThemeStoreBridge.store = themeStore
                }
                .preferredColorScheme(.light)
        }
    }
}
