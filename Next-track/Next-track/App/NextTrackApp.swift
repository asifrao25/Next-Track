//
//  NextTrackApp.swift
//  Next-track
//
//  iOS app for streaming location to Nextcloud PhoneTrack
//

import SwiftUI

@main
struct NextTrackApp: App {
    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var settingsManager = SettingsManager.shared
    @StateObject private var phoneTrackAPI = PhoneTrackAPI.shared
    @StateObject private var geofenceManager = GeofenceManager.shared
    @StateObject private var historyManager = TrackingHistoryManager.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Register background tasks
        BackgroundTaskManager.shared.registerBackgroundTasks()
        // GeofenceManager.shared will auto-restore monitoring in its init
    }

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(locationManager)
                .environmentObject(settingsManager)
                .environmentObject(phoneTrackAPI)
                .environmentObject(geofenceManager)
                .environmentObject(historyManager)
                .onAppear {
                    // Request location permissions on first launch
                    locationManager.requestPermissions()
                }
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    handleScenePhaseChange(newPhase)
                }
        }
    }

    /// Handle app lifecycle changes to protect session data
    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .background:
            // Save current session when app goes to background
            print("[NextTrackApp] App entering background - saving session")
            historyManager.saveCurrentSessionToDisk()

            // Ensure auto-export task is scheduled
            if AutoExportManager.shared.isEnabled {
                AutoExportManager.shared.scheduleNextExport()
            }
        case .inactive:
            // Also save on inactive (switching apps, control center, etc.)
            historyManager.saveCurrentSessionToDisk()
        case .active:
            // App became active - check for missed exports
            print("[NextTrackApp] App became active")
            AutoExportManager.shared.checkAndPerformMissedExport()
        @unknown default:
            break
        }
    }
}
