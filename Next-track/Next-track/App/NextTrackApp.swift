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
                .onAppear {
                    // Request location permissions on first launch
                    locationManager.requestPermissions()
                }
        }
    }
}
