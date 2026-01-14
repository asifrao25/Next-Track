//
//  TrackingSettings.swift
//  Next-track
//
//  User preferences for tracking behavior
//

import Foundation

// MARK: - Update Interval Presets
enum IntervalPreset: String, CaseIterable, Codable {
    case realtime = "10s"
    case high = "30s"
    case normal = "1m"
    case batterySaver = "5m"
    case extended = "15m"
    case minimal = "30m"
    case custom = "Custom"

    /// Presets displayed in the new card-based UI (5 options)
    static var displayedPresets: [IntervalPreset] {
        [.realtime, .normal, .batterySaver, .minimal, .custom]
    }

    var seconds: TimeInterval {
        switch self {
        case .realtime: return 10
        case .high: return 30
        case .normal: return 60
        case .batterySaver: return 300
        case .extended: return 900
        case .minimal: return 1800
        case .custom: return 0 // Uses customInterval
        }
    }

    var displayName: String {
        switch self {
        case .realtime: return "10s (Real-time)"
        case .high: return "30s (High)"
        case .normal: return "1 min (Normal)"
        case .batterySaver: return "5 min (Battery Saver)"
        case .extended: return "15 min (Extended)"
        case .minimal: return "30 min (Minimal)"
        case .custom: return "Custom"
        }
    }

    /// Short name for display
    var shortName: String {
        switch self {
        case .realtime: return "10s"
        case .high: return "30s"
        case .normal: return "1 min"
        case .batterySaver: return "5 min"
        case .extended: return "15 min"
        case .minimal: return "30 min"
        case .custom: return "Custom"
        }
    }

    /// Description for detail card
    var cardDescription: String {
        switch self {
        case .realtime: return "Real-time tracking with the smoothest, most accurate path on the map"
        case .high: return "High frequency tracking with excellent path detail"
        case .normal: return "Balanced tracking with good accuracy and reasonable battery use"
        case .batterySaver: return "Extended battery life with moderate path accuracy for longer trips"
        case .extended: return "Extended intervals with minimal battery impact"
        case .minimal: return "Maximum battery savings with basic waypoint tracking"
        case .custom: return "Set your own interval for fine-tuned control over tracking frequency"
        }
    }

    /// Estimated battery impact percentage
    var batteryImpact: String {
        switch self {
        case .realtime: return "~10%"
        case .high: return "~7%"
        case .normal: return "~5%"
        case .batterySaver: return "~2%"
        case .extended: return "~1%"
        case .minimal: return "<1%"
        case .custom: return "Varies"
        }
    }

    /// Number of dots to show in path preview graphic
    var dotDensity: Int {
        switch self {
        case .realtime: return 12
        case .high: return 10
        case .normal: return 8
        case .batterySaver: return 4
        case .extended: return 3
        case .minimal: return 2
        case .custom: return 6
        }
    }

    /// Accuracy label for detail card
    var accuracyLabel: String {
        switch self {
        case .realtime: return "Excellent"
        case .high: return "Very Good"
        case .normal: return "Good"
        case .batterySaver: return "Moderate"
        case .extended: return "Basic"
        case .minimal: return "Minimal"
        case .custom: return "Custom"
        }
    }

    /// Battery icon for detail card
    var batteryIcon: String {
        switch self {
        case .realtime: return "battery.25"
        case .high: return "battery.25"
        case .normal: return "battery.50"
        case .batterySaver: return "battery.75"
        case .extended: return "battery.100"
        case .minimal: return "battery.100"
        case .custom: return "battery.50"
        }
    }
}

// MARK: - Track Color Options
enum TrackColorOption: String, CaseIterable, Codable {
    case red = "Red"
    case blue = "Blue"
    case green = "Green"
    case orange = "Orange"
    case purple = "Purple"
    case teal = "Teal"
    case pink = "Pink"
    case yellow = "Yellow"

    var color: (red: Double, green: Double, blue: Double) {
        switch self {
        case .red: return (1.0, 0.23, 0.19)
        case .blue: return (0.0, 0.48, 1.0)
        case .green: return (0.2, 0.78, 0.35)
        case .orange: return (1.0, 0.58, 0.0)
        case .purple: return (0.69, 0.32, 0.87)
        case .teal: return (0.19, 0.69, 0.78)
        case .pink: return (1.0, 0.18, 0.33)
        case .yellow: return (1.0, 0.8, 0.0)
        }
    }
}

// MARK: - Track Width Options
enum TrackWidthOption: Int, CaseIterable, Codable {
    case thin = 2
    case medium = 4
    case thick = 6
    case extraThick = 8

    var displayName: String {
        switch self {
        case .thin: return "Thin (2pt)"
        case .medium: return "Medium (4pt)"
        case .thick: return "Thick (6pt)"
        case .extraThick: return "Extra Thick (8pt)"
        }
    }
}

// MARK: - Track Appearance Settings
struct TrackAppearanceSettings: Codable, Equatable {
    // Today's track
    var todayColor: TrackColorOption = .red
    var todayWidth: TrackWidthOption = .thick

    // Last week's tracks
    var lastWeekColor: TrackColorOption = .orange
    var lastWeekWidth: TrackWidthOption = .medium

    // Older tracks
    var olderColor: TrackColorOption = .green
    var olderWidth: TrackWidthOption = .thin

    static var `default`: TrackAppearanceSettings {
        TrackAppearanceSettings()
    }
}

// MARK: - Tracking Settings Model
struct TrackingSettings: Codable, Equatable {
    // Update frequency
    var intervalPreset: IntervalPreset = .normal
    var customIntervalSeconds: TimeInterval = 120 // 2 minutes default

    // Battery optimization
    var smartModeEnabled: Bool = true
    var smartModeBatteryThreshold: Int = 20
    var pauseOnCriticalBattery: Bool = true
    var criticalBatteryThreshold: Int = 10

    var significantLocationEnabled: Bool = false
    var motionAwareEnabled: Bool = true
    var stationaryDelayMinutes: Int = 5

    // Smart Movement Tracking - reduces frequency when stationary
    var smartMovementTrackingEnabled: Bool = true

    // Data to send
    var sendAltitude: Bool = true
    var sendSpeed: Bool = true
    var sendBearing: Bool = true
    var sendBatteryLevel: Bool = true
    var sendAccuracy: Bool = true

    // Advanced
    var retryFailedSends: Bool = true
    var maxRetryAttempts: Int = 3
    var debugLogging: Bool = false
    var minimumAccuracyMeters: Double = 100 // Ignore locations with accuracy > this

    // Track Appearance
    var trackAppearance: TrackAppearanceSettings = .default

    // Computed property for effective interval
    var effectiveInterval: TimeInterval {
        if intervalPreset == .custom {
            return customIntervalSeconds
        }
        return intervalPreset.seconds
    }

    // Default settings
    static var `default`: TrackingSettings {
        TrackingSettings()
    }
}

// MARK: - UserDefaults Storage
extension TrackingSettings {
    private static let storageKey = "trackingSettings"

    static func load() -> TrackingSettings {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let settings = try? JSONDecoder().decode(TrackingSettings.self, from: data) else {
            return .default
        }
        return settings
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: TrackingSettings.storageKey)
        }
    }
}

// MARK: - Tracking Statistics
struct TrackingStats: Codable {
    var pointsSentToday: Int = 0
    var lastSentTimestamp: Date?
    var lastSuccessfulSend: Date?
    var failedAttemptsToday: Int = 0
    var totalDistanceToday: Double = 0 // meters
    var sessionStartTime: Date?

    mutating func reset() {
        pointsSentToday = 0
        failedAttemptsToday = 0
        totalDistanceToday = 0
        sessionStartTime = nil
    }

    private static let storageKey = "trackingStats"

    static func load() -> TrackingStats {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let stats = try? JSONDecoder().decode(TrackingStats.self, from: data) else {
            return TrackingStats()
        }

        // Reset if it's a new day
        if let lastSent = stats.lastSentTimestamp,
           !Calendar.current.isDateInToday(lastSent) {
            var newStats = TrackingStats()
            newStats.lastSuccessfulSend = stats.lastSuccessfulSend
            return newStats
        }

        return stats
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: TrackingStats.storageKey)
        }
    }
}
