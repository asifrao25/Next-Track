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
    @StateObject private var errorStateManager = ErrorStateManager.shared
    @Environment(\.scenePhase) private var scenePhase

    /// Whether the user has completed onboarding
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    /// Splash animation state
    @State private var showSplash = true
    @State private var shatter = false

    init() {
        // Register background tasks
        BackgroundTaskManager.shared.registerBackgroundTasks()
        // GeofenceManager.shared will auto-restore monitoring in its init
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                // Main content - always there
                Group {
                    if hasCompletedOnboarding {
                        MainView()
                            .environmentObject(locationManager)
                            .environmentObject(settingsManager)
                            .environmentObject(phoneTrackAPI)
                            .environmentObject(geofenceManager)
                            .environmentObject(historyManager)
                            .environmentObject(errorStateManager)
                            .withErrorBanner()
                            .onAppear {
                                if !locationManager.hasAnyPermission {
                                    locationManager.requestPermissions()
                                }
                            }
                            .onChange(of: scenePhase) { oldPhase, newPhase in
                                handleScenePhaseChange(newPhase)
                            }
                    } else {
                        OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
                            .environmentObject(locationManager)
                            .environmentObject(settingsManager)
                    }
                }

                // Splash with shatter effect
                if showSplash {
                    ShatterView(shatter: shatter) {
                        SplashScreenView()
                    }
                    .ignoresSafeArea()
                    .zIndex(1)
                }
            }
            .onAppear {
                // Video plays 3.5 sec, then shatter over 3 sec
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                    shatter = true

                    // Haptic + cleanup after shatter completes
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        HapticManager.shared.success()
                        showSplash = false
                    }
                }
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
