//
//  UserDefaultsKeys.swift
//  Next-track
//
//  Centralized UserDefaults keys
//

import Foundation

enum UserDefaultsKeys {
    static let serverConfig = "serverConfig"
    static let trackingSettings = "trackingSettings"
    static let trackingStats = "trackingStats"
    static let pendingLocations = "pendingLocations"
    static let isFirstLaunch = "isFirstLaunch"
    static let lastAppVersion = "lastAppVersion"
}

// MARK: - App Storage Property Wrapper Extension

extension UserDefaults {
    var isFirstLaunch: Bool {
        get {
            !bool(forKey: UserDefaultsKeys.isFirstLaunch)
        }
        set {
            set(!newValue, forKey: UserDefaultsKeys.isFirstLaunch)
        }
    }
}
