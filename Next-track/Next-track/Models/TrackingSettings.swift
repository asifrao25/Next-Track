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
