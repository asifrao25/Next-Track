//
//  SettingsManager.swift
//  Next-track
//
//  Centralized settings management
//

import Foundation
import Combine

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    @Published var serverConfig: ServerConfig {
        didSet {
            serverConfig.save()
            iCloudSyncManager.shared.syncSettingsNow()
        }
    }

    @Published var trackingSettings: TrackingSettings {
        didSet {
            trackingSettings.save()
            iCloudSyncManager.shared.syncSettingsNow()
        }
    }

    @Published var trackingStats: TrackingStats {
        didSet { trackingStats.save() }
    }

    @Published var isConfigured: Bool = false

    private init() {
        self.serverConfig = ServerConfig.load()
        self.trackingSettings = TrackingSettings.load()
        self.trackingStats = TrackingStats.load()
        self.isConfigured = serverConfig.isValid
    }

    func updateServerConfig(_ config: ServerConfig) {
        serverConfig = config
        isConfigured = config.isValid
    }

    func updateTrackingSettings(_ settings: TrackingSettings) {
        trackingSettings = settings
    }

    func recordSuccessfulSend(distance: Double = 0) {
        trackingStats.pointsSentToday += 1
        trackingStats.lastSentTimestamp = Date()
        trackingStats.lastSuccessfulSend = Date()
        trackingStats.totalDistanceToday += distance
        trackingStats.save()
    }

    func recordFailedSend() {
        trackingStats.failedAttemptsToday += 1
        trackingStats.lastSentTimestamp = Date()
        trackingStats.save()
    }

    func startSession() {
        trackingStats.sessionStartTime = Date()
        trackingStats.save()
    }

    func resetDailyStats() {
        trackingStats.reset()
        trackingStats.save()
    }
}
