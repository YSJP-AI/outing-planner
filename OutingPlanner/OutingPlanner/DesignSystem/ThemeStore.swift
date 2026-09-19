//
//  ThemeStore.swift
//  OutingPlanner
//

import Foundation
import Observation

@Observable
@MainActor
final class ThemeStore {
    private static let storageKey = "outing.colorTheme"

    var selectedID: ColorThemeID {
        didSet {
            UserDefaults.standard.set(selectedID.rawValue, forKey: Self.storageKey)
        }
    }

    var palette: ThemePalette {
        selectedID.palette
    }

    init() {
        if let raw = UserDefaults.standard.string(forKey: Self.storageKey),
           let saved = ColorThemeID(rawValue: raw) {
            selectedID = saved
        } else {
            selectedID = .azure
        }
    }
}
