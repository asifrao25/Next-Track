//
//  OnboardingView.swift
//  Next-track
//
//  Onboarding flow for first-time users
//  Explains app features and guides through initial setup
//

import SwiftUI
import CoreLocation
import UIKit
import LocalAuthentication

/// Main onboarding container with paged navigation
struct OnboardingView: View {

    @State private var currentPage = 0
    @Binding var hasCompletedOnboarding: Bool

    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var settingsManager = SettingsManager.shared

    private let totalPages = 11

    var body: some View {
        ZStack {
            // Dark background
            Color(red: 0.05, green: 0.05, blue: 0.08)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Page content
                TabView(selection: $currentPage) {
                    WelcomePage()
                        .tag(0)

                    FeaturesPage()
                        .tag(1)

                    // Feature screens
                    FeatureScreen(
                        image: "FeatureTravel",
                        title: "Track Your Travel",
                        line1: "Record every journey automatically.",
                        line2: "From daily commutes to world adventures.",
                        line3: "Your complete travel history."
                    ).tag(2)

                    FeatureScreen(
                        image: "FeatureAutoMark",
                        title: "Auto-Mark Cities",
                        line1: "Cities detected as you travel.",
                        line2: "Countries added automatically.",
                        line3: "No manual input needed."
                    ).tag(3)

                    FeatureScreen(
                        image: "FeatureManual",
                        title: "Add Manually",
                        line1: "Log past visits yourself.",
                        line2: "Add places you've been before.",
                        line3: "Complete your travel history."
                    ).tag(4)

                    FeatureScreen(
                        image: "FeatureSync",
                        title: "iCloud Sync",
                        line1: "Sync across all your devices.",
                        line2: "iPhone, iPad, seamlessly connected.",
                        line3: "Always up to date."
                    ).tag(5)

                    FeatureScreen(
                        image: "FeatureBackup",
                        title: "Auto Backup",
                        line1: "Automatic iCloud backup.",
                        line2: "Your data is always safe.",
                        line3: "Restore anytime, anywhere."
                    ).tag(6)

                    FeatureScreen(
                        image: "FeatureNextcloud",
                        title: "Nextcloud Server",
                        line1: "Stream to your own server.",
                        line2: "PhoneTrack integration built-in.",
                        line3: "Complete data ownership."
                    ).tag(7)

                    AppLockPage()
                        .tag(8)

                    LocationPermissionPage(locationManager: locationManager)
                        .tag(9)

                    RestoreDataPage(onComplete: completeOnboarding)
                        .tag(10)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)

                // Bottom navigation
                VStack(spacing: 16) {
                    // Page indicators
                    HStack(spacing: 8) {
                        ForEach(0..<totalPages, id: \.self) { index in
                            Circle()
                                .fill(index == currentPage ? Color.teal : Color.white.opacity(0.3))
                                .frame(width: 8, height: 8)
                                .animation(.easeInOut, value: currentPage)
                        }
                    }
                    .accessibilityLabel("Page \(currentPage + 1) of \(totalPages)")

                    // Navigation buttons
                    HStack {
                        if currentPage > 0 {
                            Button(action: previousPage) {
                                HStack {
                                    Image(systemName: "chevron.left")
                                    Text("Back")
                                }
                                .foregroundColor(.white.opacity(0.8))
                            }
                            .accessibilityLabel("Go back")
                        }

                        Spacer()

                        if currentPage < totalPages - 1 {
                            Button(action: nextPage) {
                                HStack {
                                    Text("Next")
                                    Image(systemName: "chevron.right")
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(
                                    LinearGradient(
                                        colors: [.teal, .purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(25)
                            }
                            .accessibilityLabel("Continue to next page")
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 40)
            }
        }
    }

    private func nextPage() {
        withAnimation {
            currentPage = min(currentPage + 1, totalPages - 1)
        }
    }

    private func previousPage() {
        withAnimation {
            currentPage = max(currentPage - 1, 0)
        }
    }

    private func completeOnboarding() {
        withAnimation {
            hasCompletedOnboarding = true
        }
    }
}

// MARK: - Welcome Page

struct WelcomePage: View {

    var body: some View {
        ZStack {
            // Dark gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.08, blue: 0.12),
                    Color(red: 0.08, green: 0.12, blue: 0.18),
                    Color(red: 0.05, green: 0.1, blue: 0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Compact app header at top
                OnboardingCompactHeader()

                Spacer()

                // Main content - centered
                VStack(spacing: 24) {
                    // Travel illustration
                    Image("OnboardingTravel")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 180)
                        .accessibilityHidden(true)

                    // Title
                    Text("Your Travel Diary,\nOn Autopilot")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)

                    // Body text
                    VStack(spacing: 12) {
                        Text("Automatic tracking of your journeys.")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))

                        Text("Every city. Every country. Every adventure.")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))

                        Text("Zero effort, 100% private.")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.teal, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                    .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)

                Spacer()
                Spacer()
            }
        }
    }
}

// MARK: - Compact Onboarding Header

struct OnboardingCompactHeader: View {
    var body: some View {
        Image("HeaderImage")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .opacity(0.9)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.08, green: 0.1, blue: 0.15),
                        Color(red: 0.05, green: 0.08, blue: 0.12)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.teal.opacity(0.1),
                                Color.purple.opacity(0.1),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1)
                    .offset(y: 34)  // Bottom edge
            )
            .shadow(color: .teal.opacity(0.15), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Features Page (Privacy)

struct FeaturesPage: View {

    var body: some View {
        ZStack {
            // Dark gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.08, blue: 0.12),
                    Color(red: 0.08, green: 0.12, blue: 0.18),
                    Color(red: 0.05, green: 0.1, blue: 0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Compact app header at top
                OnboardingCompactHeader()

                Spacer()

                // Main content - centered
                VStack(spacing: 24) {
                    // Safe/vault illustration
                    Image("OnboardingPrivacy")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 160)
                        .accessibilityHidden(true)

                    // Title
                    Text("100% Private.\nGuaranteed.")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)

                    // Body text
                    VStack(spacing: 12) {
                        Text("Your location data never leaves your device.")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))

                        Text("Nothing is sent to us or anyone else.")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))

                        Text("Protected by world-class iOS security.")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.teal, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                    .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)

                Spacer()
                Spacer()
            }
        }
    }
}

// MARK: - Reusable Feature Screen

struct FeatureScreen: View {
    let image: String
    let title: String
    let line1: String
    let line2: String
    let line3: String

    var body: some View {
        ZStack {
            // Dark gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.08, blue: 0.12),
                    Color(red: 0.08, green: 0.12, blue: 0.18),
                    Color(red: 0.05, green: 0.1, blue: 0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Compact app header at top
                OnboardingCompactHeader()

                Spacer()

                // Main content - centered
                VStack(spacing: 24) {
                    // Feature image
                    Image(image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 160)
                        .accessibilityHidden(true)

                    // Title
                    Text(title)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)

                    // Body text
                    VStack(spacing: 12) {
                        Text(line1)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))

                        Text(line2)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))

                        Text(line3)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.teal, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                    .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)

                Spacer()
                Spacer()
            }
        }
    }
}

// MARK: - App Lock Page

struct AppLockPage: View {
    @State private var biometricEnabled = false
    @State private var biometricType: String = "Face ID"

    var body: some View {
        ZStack {
            // Dark gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.08, blue: 0.12),
                    Color(red: 0.08, green: 0.12, blue: 0.18),
                    Color(red: 0.05, green: 0.1, blue: 0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Compact app header at top
                OnboardingCompactHeader()

                Spacer()

                // Main content
                VStack(spacing: 24) {
                    // Lock image
                    Image("FeatureLock")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 160)
                        .accessibilityHidden(true)

                    // Title
                    Text("App Lock")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)

                    // Body text
                    VStack(spacing: 12) {
                        Text("Secure with Face ID or Touch ID.")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))

                        Text("Passcode protection available.")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))

                        Text("Your data stays private.")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.teal, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                    .multilineTextAlignment(.center)

                    // Face ID Permission Button
                    VStack(spacing: 16) {
                        if biometricEnabled {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Biometric authentication enabled")
                                    .foregroundColor(.green)
                            }
                            .font(.headline)
                        } else {
                            Button(action: requestBiometricPermission) {
                                HStack {
                                    Image(systemName: "faceid")
                                        .font(.title2)
                                    Text("Enable Face ID")
                                        .font(.headline)
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 14)
                                .background(
                                    LinearGradient(
                                        colors: [.teal, .purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(25)
                            }
                            .accessibilityLabel("Enable Face ID authentication")
                        }
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 32)

                Spacer()
                Spacer()
            }
        }
        .onAppear {
            checkBiometricType()
        }
    }

    private func checkBiometricType() {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            switch context.biometryType {
            case .faceID:
                biometricType = "Face ID"
            case .touchID:
                biometricType = "Touch ID"
            default:
                biometricType = "Biometrics"
            }
        }
    }

    private func requestBiometricPermission() {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                                   localizedReason: "Enable biometric authentication for Been There") { success, _ in
                DispatchQueue.main.async {
                    if success {
                        biometricEnabled = true
                        HapticManager.shared.success()
                    }
                }
            }
        }
    }
}

// MARK: - Location Permission Page

struct LocationPermissionPage: View {

    @ObservedObject var locationManager: LocationManager

    var body: some View {
        ZStack {
            // Dark gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.08, blue: 0.12),
                    Color(red: 0.08, green: 0.12, blue: 0.18),
                    Color(red: 0.05, green: 0.1, blue: 0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Compact app header at top
                OnboardingCompactHeader()

                Spacer()

                // Main content
                VStack(spacing: 20) {
                    // Location icon with gradient glow
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.teal.opacity(0.3),
                                        Color.purple.opacity(0.1),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 20,
                                    endRadius: 60
                                )
                            )
                            .frame(width: 120, height: 120)

                        Image(systemName: "location.fill")
                            .font(.system(size: 50, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.teal, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .accessibilityHidden(true)

                    // Title
                    Text("Location Access")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    // Explanation
                    Text("\"Always\" permission is required for automatic tracking, even when the app is in the background.")
                        .font(.system(size: 15))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 8)

                    // Why points
                    VStack(alignment: .leading, spacing: 10) {
                        OnboardingWhyRow(icon: "figure.walk", text: "Track while you walk, drive, or travel")
                        OnboardingWhyRow(icon: "arrow.triangle.swap", text: "Continue when you switch apps")
                        OnboardingWhyRow(icon: "location.viewfinder", text: "Auto-start with geofences")
                        OnboardingWhyRow(icon: "mappin.and.ellipse", text: "Detect places automatically")
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.08))
                    )

                    // Battery note
                    HStack(spacing: 8) {
                        Image(systemName: "battery.100.bolt")
                            .font(.system(size: 14))
                            .foregroundColor(.green)
                        Text("Minimal battery impact with smart tracking")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.top, 4)

                    // Status and button
                    VStack(spacing: 12) {
                        if locationManager.hasFullPermission {
                            // ✅ Always permission granted
                            VStack(spacing: 8) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Always-on location enabled")
                                        .foregroundColor(.green)
                                }
                                .font(.headline)

                                Text("You're all set for automatic tracking!")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        } else if locationManager.hasAnyPermission {
                            // ⚠️ Only "When In Use" - need "Always"
                            VStack(spacing: 12) {
                                // Warning badge
                                HStack(spacing: 6) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                    Text("\"When In Use\" Selected")
                                        .foregroundColor(.orange)
                                }
                                .font(.subheadline.bold())

                                // Explanation
                                Text("Background tracking won't work.\nPlease select \"Always\" in Settings for full functionality.")
                                    .font(.system(size: 13))
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.white.opacity(0.7))
                                    .padding(.horizontal, 8)

                                // Settings button
                                Button(action: openSettings) {
                                    HStack {
                                        Image(systemName: "gear")
                                        Text("Open Settings")
                                    }
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.orange)
                                    .cornerRadius(25)
                                }
                                .padding(.horizontal, 20)

                                // How to change
                                Text("Settings → Location → Always")
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.orange.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        } else if locationManager.authorizationStatus == .denied {
                            // ❌ Permission denied
                            VStack(spacing: 12) {
                                HStack(spacing: 6) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                    Text("Location Access Denied")
                                        .foregroundColor(.red)
                                }
                                .font(.subheadline.bold())

                                Text("Please enable location access in Settings to use this app.")
                                    .font(.system(size: 13))
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.white.opacity(0.7))

                                Button(action: openSettings) {
                                    HStack {
                                        Image(systemName: "gear")
                                        Text("Open Settings")
                                    }
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.red.opacity(0.8))
                                    .cornerRadius(25)
                                }
                                .padding(.horizontal, 20)
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.red.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        } else {
                            // 🔵 Not yet requested
                            Button(action: requestPermission) {
                                HStack {
                                    Image(systemName: "location.fill")
                                    Text("Enable Location")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 14)
                                .background(
                                    LinearGradient(
                                        colors: [.teal, .purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(25)
                            }
                            .accessibilityLabel("Enable location access")
                        }
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 24)

                Spacer()
                Spacer()
            }
        }
    }

    private func requestPermission() {
        locationManager.requestPermissions()
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Onboarding Why Row

struct OnboardingWhyRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.teal, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 20)
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.8))
        }
    }
}

// MARK: - Restore Data Page

struct RestoreDataPage: View {
    var onComplete: () -> Void

    @State private var showRestoreFilePicker = false
    @State private var showRestoreResult = false
    @State private var isRestoring = false
    @State private var restoreError: String?
    @State private var dontShowAgain = false

    @StateObject private var backupManager = FullBackupManager.shared
    @StateObject private var iCloudSync = iCloudSyncManager.shared

    var body: some View {
        ZStack {
            // Dark gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.08, blue: 0.12),
                    Color(red: 0.08, green: 0.12, blue: 0.18),
                    Color(red: 0.05, green: 0.1, blue: 0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Compact app header at top
                OnboardingCompactHeader()

                Spacer()

                // Main content
                VStack(spacing: 20) {
                    // Backup image
                    Image("FeatureBackup")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 140)
                        .accessibilityHidden(true)

                    // Title
                    Text("Restore Your Data")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    // Subtitle
                    Text("Reinstalling? Restore from a backup or sync from iCloud.")
                        .font(.system(size: 15))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 8)

                    // Restore options
                    VStack(spacing: 12) {
                        // Restore from file
                        Button(action: { showRestoreFilePicker = true }) {
                            HStack {
                                Image(systemName: "doc.zipper")
                                    .font(.title2)
                                    .foregroundStyle(
                                        LinearGradient(colors: [.orange, .yellow], startPoint: .top, endPoint: .bottom)
                                    )
                                    .frame(width: 32)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Restore from Backup")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.white)
                                    Text("Select a JSON backup file")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                                Spacer()
                                if isRestoring {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.white.opacity(0.4))
                                }
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.white.opacity(0.08))
                            )
                        }
                        .disabled(isRestoring)

                        // Restore from iCloud
                        Button(action: restoreFromICloud) {
                            HStack {
                                Image(systemName: "icloud.and.arrow.down")
                                    .font(.title2)
                                    .foregroundStyle(
                                        LinearGradient(colors: [.cyan, .teal], startPoint: .top, endPoint: .bottom)
                                    )
                                    .frame(width: 32)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Restore from iCloud")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.white)
                                    Text("Sync data from other devices")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                                Spacer()
                                if iCloudSync.isSyncing {
                                    ProgressView()
                                        .tint(.white)
                                } else if !iCloudSync.iCloudAvailable {
                                    Text("Unavailable")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                } else {
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.white.opacity(0.4))
                                }
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.white.opacity(0.08))
                            )
                        }
                        .disabled(!iCloudSync.iCloudAvailable || iCloudSync.isSyncing || isRestoring)
                    }

                    // Error message
                    if let error = restoreError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    // Divider
                    HStack {
                        Rectangle()
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 1)
                        Text("or")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.4))
                        Rectangle()
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 1)
                    }
                    .padding(.vertical, 4)

                    // Let's Travel button
                    Button {
                        print("[Onboarding] Let's Travel tapped")
                        HapticManager.shared.success()
                        if dontShowAgain {
                            UserDefaults.standard.set(true, forKey: "skipOnboardingNextTime")
                        }
                        onComplete()
                    } label: {
                        HStack {
                            Image(systemName: "airplane.departure")
                            Text("Let's Travel")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [.teal, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(25)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    // Don't show again checkbox
                    Button(action: { dontShowAgain.toggle() }) {
                        HStack(spacing: 10) {
                            Image(systemName: dontShowAgain ? "checkmark.square.fill" : "square")
                                .font(.system(size: 18))
                                .foregroundStyle(
                                    dontShowAgain ?
                                    AnyShapeStyle(LinearGradient(colors: [.teal, .purple], startPoint: .leading, endPoint: .trailing)) :
                                    AnyShapeStyle(Color.white.opacity(0.4))
                                )
                            Text("Don't show this again")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                }
                .padding(.horizontal, 24)

                Spacer()
            }
        }
        .fileImporter(
            isPresented: $showRestoreFilePicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result)
        }
    }

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            guard url.startAccessingSecurityScopedResource() else {
                restoreError = "Cannot access the selected file"
                return
            }

            defer { url.stopAccessingSecurityScopedResource() }

            isRestoring = true
            restoreError = nil

            do {
                let data = try Data(contentsOf: url)
                let restoreResult = backupManager.restoreFromBackup(data, mergeMode: .merge)
                isRestoring = false

                if restoreResult.success {
                    HapticManager.shared.success()
                    onComplete()
                } else {
                    restoreError = "Failed to restore backup"
                    HapticManager.shared.error()
                }
            } catch {
                isRestoring = false
                restoreError = "Error reading file: \(error.localizedDescription)"
                HapticManager.shared.error()
            }

        case .failure(let error):
            restoreError = error.localizedDescription
        }
    }

    private func restoreFromICloud() {
        restoreError = nil
        Task {
            await iCloudSync.syncAllData()

            await MainActor.run {
                if iCloudSync.lastSyncDate != nil {
                    HapticManager.shared.success()
                    onComplete()
                }
            }
        }
    }
}

// MARK: - Helper Views

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 40)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .accessibilityElement(children: .combine)
    }
}

struct FeatureCard: View {
    let icon: String
    let color: Color
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.15))
                    .frame(width: 50, height: 50)

                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .accessibilityElement(children: .combine)
    }
}

struct WhyRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .accessibilityHidden(true)
            Text(text)
                .font(.subheadline)
        }
    }
}

// MARK: - QR Scanner Sheet

struct QRScannerSheet: View {
    @ObservedObject var settingsManager: SettingsManager
    @Binding var isPresented: Bool

    var body: some View {
        QRScannerView { code in
            // Parse the QR code
            if let config = ServerConfig.parse(from: code) {
                settingsManager.serverConfig = config
                isPresented = false
            }
        }
    }
}

// MARK: - Manual Setup Sheet

struct ManualSetupSheet: View {
    @ObservedObject var settingsManager: SettingsManager
    @Binding var isPresented: Bool

    @State private var serverURL = ""
    @State private var token = ""
    @State private var deviceName = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Server Details")) {
                    TextField("Server URL", text: $serverURL)
                        .textContentType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityLabel("Server URL")

                    TextField("Token", text: $token)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityLabel("Authentication token")
                }

                Section(header: Text("Device")) {
                    TextField("Device Name (optional)", text: $deviceName)
                        .accessibilityLabel("Device name")
                }

                Section {
                    Button(action: save) {
                        Text("Save Configuration")
                    }
                    .disabled(serverURL.isEmpty || token.isEmpty)
                }
            }
            .navigationTitle("Manual Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }

    private func save() {
        let name = deviceName.isEmpty ? UIDevice.current.name : deviceName
        let config = ServerConfig(
            serverURL: serverURL,
            token: token,
            deviceName: name
        )
        settingsManager.serverConfig = config
        isPresented = false
    }
}

// MARK: - Preview

#if DEBUG
struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(hasCompletedOnboarding: .constant(false))
    }
}
#endif
