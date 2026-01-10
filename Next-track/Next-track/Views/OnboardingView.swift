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

/// Main onboarding container with paged navigation
struct OnboardingView: View {

    @State private var currentPage = 0
    @Binding var hasCompletedOnboarding: Bool

    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var settingsManager = SettingsManager.shared

    private let totalPages = 4

    var body: some View {
        ZStack {
            // Background
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Page content
                TabView(selection: $currentPage) {
                    WelcomePage()
                        .tag(0)

                    FeaturesPage()
                        .tag(1)

                    LocationPermissionPage(locationManager: locationManager)
                        .tag(2)

                    ServerSetupPage(
                        settingsManager: settingsManager,
                        onComplete: completeOnboarding
                    )
                    .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)

                // Bottom navigation
                VStack(spacing: 16) {
                    // Page indicators
                    HStack(spacing: 8) {
                        ForEach(0..<totalPages, id: \.self) { index in
                            Circle()
                                .fill(index == currentPage ? Color.accentColor : Color.gray.opacity(0.3))
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
                                .foregroundColor(.accentColor)
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
                                .background(Color.accentColor)
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
        VStack(spacing: 24) {
            Spacer()

            // App icon
            Image(systemName: "location.circle.fill")
                .font(.system(size: 100))
                .foregroundColor(.accentColor)
                .accessibilityHidden(true)

            // Welcome text
            VStack(spacing: 12) {
                Text("Welcome to")
                    .font(.title2)
                    .foregroundColor(.secondary)

                Text("Next Track")
                    .font(.largeTitle.bold())

                Text("Your personal location tracker")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Description
            VStack(spacing: 16) {
                FeatureRow(
                    icon: "location.fill",
                    title: "Track Your Journey",
                    description: "Record your location in real-time"
                )

                FeatureRow(
                    icon: "cloud.fill",
                    title: "Sync to Nextcloud",
                    description: "Stream data to your PhoneTrack server"
                )

                FeatureRow(
                    icon: "battery.100",
                    title: "Battery Optimized",
                    description: "Smart tracking that saves power"
                )
            }
            .padding(.horizontal, 32)

            Spacer()
        }
        .padding()
    }
}

// MARK: - Features Page

struct FeaturesPage: View {

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("What You Can Do")
                .font(.largeTitle.bold())

            Spacer()

            VStack(spacing: 20) {
                FeatureCard(
                    icon: "map.fill",
                    color: .blue,
                    title: "Places",
                    description: "Automatically detect and track places you visit frequently"
                )

                FeatureCard(
                    icon: "globe.europe.africa.fill",
                    color: .green,
                    title: "Countries & Cities",
                    description: "Keep track of cities and countries you've been to"
                )

                FeatureCard(
                    icon: "location.viewfinder",
                    color: .orange,
                    title: "Geofences",
                    description: "Auto-start tracking when entering specific zones"
                )

                FeatureCard(
                    icon: "square.and.arrow.up.fill",
                    color: .purple,
                    title: "Export",
                    description: "Export your data as GPX files automatically"
                )
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .padding()
    }
}

// MARK: - Location Permission Page

struct LocationPermissionPage: View {

    @ObservedObject var locationManager: LocationManager

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 120, height: 120)

                Image(systemName: "location.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.blue)
            }
            .accessibilityHidden(true)

            // Title
            Text("Location Access")
                .font(.largeTitle.bold())

            // Explanation
            VStack(spacing: 16) {
                Text("Next Track needs continuous location access to track your journeys, even when the app is in the background.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)

                // Why "Always" is needed
                VStack(alignment: .leading, spacing: 12) {
                    WhyRow(text: "Track your journey while you walk, drive, or travel")
                    WhyRow(text: "Continue tracking when you switch apps")
                    WhyRow(text: "Enable geofences to auto-start tracking")
                    WhyRow(text: "Detect places you visit automatically")
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }
            .padding(.horizontal, 24)

            Spacer()

            // Status and button
            VStack(spacing: 16) {
                if locationManager.hasFullPermission {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Always-on location enabled")
                            .foregroundColor(.green)
                    }
                    .font(.headline)
                } else if locationManager.hasAnyPermission {
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Limited location access")
                                .foregroundColor(.orange)
                        }
                        .font(.headline)

                        Text("For best experience, enable 'Always' in Settings")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Button(action: openSettings) {
                            Text("Open Settings")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 14)
                                .background(Color.orange)
                                .cornerRadius(25)
                        }
                    }
                } else {
                    Button(action: requestPermission) {
                        Text("Enable Location")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 14)
                            .background(Color.accentColor)
                            .cornerRadius(25)
                    }
                    .accessibilityLabel("Enable location access")
                    .accessibilityHint("Opens the location permission dialog")
                }
            }

            Spacer()
        }
        .padding()
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

// MARK: - Server Setup Page

struct ServerSetupPage: View {

    @ObservedObject var settingsManager: SettingsManager
    @State private var showingQRScanner = false
    @State private var showingManualSetup = false

    var onComplete: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.15))
                    .frame(width: 120, height: 120)

                Image(systemName: "server.rack")
                    .font(.system(size: 50))
                    .foregroundColor(.purple)
            }
            .accessibilityHidden(true)

            // Title
            Text("Connect Your Server")
                .font(.largeTitle.bold())

            // Explanation
            Text("Connect to your Nextcloud PhoneTrack server to start streaming your location data.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 24)

            Spacer()

            // Setup options
            VStack(spacing: 16) {
                // QR Code option
                Button(action: { showingQRScanner = true }) {
                    HStack {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.title2)
                        VStack(alignment: .leading) {
                            Text("Scan QR Code")
                                .font(.headline)
                            Text("Quick setup from PhoneTrack")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .foregroundColor(.primary)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                }
                .accessibilityLabel("Scan QR code for quick setup")

                // Manual setup option
                Button(action: { showingManualSetup = true }) {
                    HStack {
                        Image(systemName: "keyboard")
                            .font(.title2)
                        VStack(alignment: .leading) {
                            Text("Manual Setup")
                                .font(.headline)
                            Text("Enter server details manually")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .foregroundColor(.primary)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                }
                .accessibilityLabel("Set up manually with server URL and token")
            }
            .padding(.horizontal, 24)

            Spacer()

            // Skip / Get Started button
            VStack(spacing: 12) {
                if settingsManager.serverConfig.isValid {
                    Button(action: onComplete) {
                        Text("Get Started")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.accentColor)
                            .cornerRadius(25)
                    }
                    .padding(.horizontal, 24)
                    .accessibilityLabel("Complete setup and start using the app")
                }

                Button(action: onComplete) {
                    Text(settingsManager.serverConfig.isValid ? "I'll set up later" : "Skip for now")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .accessibilityLabel("Skip server setup")
            }

            Spacer()
        }
        .padding()
        .sheet(isPresented: $showingQRScanner) {
            QRScannerSheet(settingsManager: settingsManager, isPresented: $showingQRScanner)
        }
        .sheet(isPresented: $showingManualSetup) {
            ManualSetupSheet(settingsManager: settingsManager, isPresented: $showingManualSetup)
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
