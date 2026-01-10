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

    /// Whether to show the splash screen
    @State private var showSplash = true

    init() {
        // Register background tasks
        BackgroundTaskManager.shared.registerBackgroundTasks()
        // GeofenceManager.shared will auto-restore monitoring in its init
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                // Main content (loads in background while splash shows)
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
                                // Request location permissions if not already granted
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
                .opacity(showSplash ? 0 : 1)

                // Splash screen overlay
                if showSplash {
                    SplashScreenView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .onAppear {
                // Dismiss splash after 4 seconds (video fades out mid-playback)
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                    withAnimation(.easeInOut(duration: 0.5)) {
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
