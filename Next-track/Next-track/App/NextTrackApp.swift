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

    /// Restart detection state
    @AppStorage("lastBackgroundTimestamp") private var lastBackgroundTimestamp: Double = 0
    @AppStorage("appHasLaunchedBefore") private var appHasLaunchedBefore: Bool = false
    @State private var showRestartBanner = false
    @State private var timeSinceBackground: TimeInterval = 0

    /// Splash animation state
    @State private var showSplash = true
    @State private var shatter = false

    /// App lock state
    @State private var isUnlocked = true  // Start unlocked - only lock when returning from background
    @State private var lockBackgroundTime: Date?
    @State private var hasEnteredBackgroundOnce = false  // Track if app has been backgrounded

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

                // Restart banner overlay
                if showRestartBanner {
                    RestartBannerView(
                        timeSinceBackground: timeSinceBackground,
                        isShowing: $showRestartBanner
                    )
                    .zIndex(2)
                }

                // App lock overlay - only show after app has been backgrounded at least once
                if settingsManager.securitySettings.isEnabled && !isUnlocked && !showSplash && hasEnteredBackgroundOnce {
                    AppLockView(
                        isUnlocked: $isUnlocked,
                        securitySettings: settingsManager.securitySettings
                    )
                    .transition(.opacity)
                    .zIndex(3)
                }
            }
            .onAppear {
                // Check for app restart
                checkForAppRestart()
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

            // Save timestamp for restart detection
            lastBackgroundTimestamp = Date().timeIntervalSince1970

            // Save time for lock delay check
            lockBackgroundTime = Date()
            hasEnteredBackgroundOnce = true  // Mark that app has been backgrounded

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

            // Check if we need to lock the app based on delay setting
            checkAndApplyLock()
        @unknown default:
            break
        }
    }

    /// Check if app should be locked based on background time and lock delay
    private func checkAndApplyLock() {
        let settings = settingsManager.securitySettings
        guard settings.isEnabled else { return }

        // If already locked, nothing to do
        guard isUnlocked else { return }

        // Check time since background
        if let backgroundTime = lockBackgroundTime {
            let elapsed = Date().timeIntervalSince(backgroundTime)
            let delaySeconds = Double(settings.lockDelay.rawValue)

            if elapsed > delaySeconds {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isUnlocked = false
                }
                print("[NextTrackApp] App locked after \(Int(elapsed))s in background")
            }
        }
    }

    /// Check if app was restarted after being terminated
    private func checkForAppRestart() {
        let now = Date().timeIntervalSince1970

        // Only check if app has launched before and we have a background timestamp
        if appHasLaunchedBefore && lastBackgroundTimestamp > 0 {
            let elapsed = now - lastBackgroundTimestamp

            // If more than 30 seconds since background, app was likely killed
            // (normal app switching is usually < 30 seconds)
            if elapsed > 30 {
                timeSinceBackground = elapsed
                print("[NextTrackApp] App restarted after \(Int(elapsed)) seconds")

                // Delay banner to show after splash screen
                DispatchQueue.main.asyncAfter(deadline: .now() + 7.0) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showRestartBanner = true
                    }
                }
            }
        }

        // Mark that app has launched
        appHasLaunchedBefore = true
    }
}
