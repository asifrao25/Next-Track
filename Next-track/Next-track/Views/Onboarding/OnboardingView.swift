//
//  OnboardingView.swift
//  Next-track
//
//  Onboarding flow for first-time users
//  Explains app features and guides through initial setup
//

import SwiftUI
import CoreLocation
import UniformTypeIdentifiers

/// Main onboarding container with paged navigation
struct OnboardingView: View {

    @State private var currentPage = 0
    @Binding var hasCompletedOnboarding: Bool

    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var settingsManager = SettingsManager.shared

    private let totalPages = 5

    var body: some View {
        ZStack {
            // Dark background (pages have their own gradients)
            Color(red: 0.05, green: 0.05, blue: 0.1)
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
                        onComplete: { currentPage = 4 },  // Go to restore page
                        onSkipToApp: completeOnboarding   // Skip directly to app
                    )
                    .tag(3)

                    RestoreDataPage(onComplete: completeOnboarding)
                        .tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)

                // Bottom navigation
                VStack(spacing: 16) {
                    // Page indicators
                    HStack(spacing: 8) {
                        ForEach(0..<totalPages, id: \.self) { index in
                            Circle()
                                .fill(index == currentPage ? Color.cyan : Color.white.opacity(0.3))
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
                                        colors: [.cyan, .blue],
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
            // Travel-themed gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.1, blue: 0.2),
                    Color(red: 0.05, green: 0.15, blue: 0.25),
                    Color(red: 0.1, green: 0.2, blue: 0.3)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                // Header Image
                OnboardingHeader()

                Spacer()

                // Tagline
                VStack(spacing: 8) {
                    Text("Your Journey, Remembered")
                        .font(.title2.bold())
                        .foregroundColor(.white)

                    Text("Track everywhere you've been")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()

                // Feature list
                VStack(spacing: 16) {
                    FeatureRow(
                        icon: "location.fill",
                        title: "Track Your Journey",
                        description: "Record your location in real-time"
                    )

                    FeatureRow(
                        icon: "globe.europe.africa.fill",
                        title: "Countries & Cities",
                        description: "See everywhere you've traveled"
                    )

                    FeatureRow(
                        icon: "icloud.fill",
                        title: "Sync & Backup",
                        description: "Never lose your travel history"
                    )
                }
                .padding(.horizontal, 32)

                Spacer()
            }
            .padding()
        }
    }
}

// MARK: - Features Page

struct FeaturesPage: View {

    var body: some View {
        ZStack {
            // Sunset gradient for features
            LinearGradient(
                colors: [
                    Color(red: 0.15, green: 0.1, blue: 0.2),
                    Color(red: 0.2, green: 0.1, blue: 0.15),
                    Color(red: 0.15, green: 0.08, blue: 0.12)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                // Header Image
                OnboardingHeader()

                Text("What You Can Do")
                    .font(.title2.bold())
                    .foregroundColor(.white)

                Spacer()

                VStack(spacing: 16) {
                    FeatureCard(
                        icon: "map.fill",
                        color: .cyan,
                        title: "Places",
                        description: "Automatically detect places you visit"
                    )

                    FeatureCard(
                        icon: "globe.europe.africa.fill",
                        color: .green,
                        title: "Countries & Cities",
                        description: "Track cities and countries visited"
                    )

                    FeatureCard(
                        icon: "location.viewfinder",
                        color: .orange,
                        title: "Geofences",
                        description: "Auto-start tracking in specific zones"
                    )

                    FeatureCard(
                        icon: "square.and.arrow.up.fill",
                        color: .purple,
                        title: "Export & Backup",
                        description: "Export data as GPX or JSON"
                    )
                }
                .padding(.horizontal, 24)

                Spacer()
            }
            .padding()
        }
    }
}

// MARK: - Location Permission Page

struct LocationPermissionPage: View {

    @ObservedObject var locationManager: LocationManager

    var body: some View {
        ZStack {
            // Ocean/sky gradient
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.1, blue: 0.2),
                    Color(red: 0.1, green: 0.15, blue: 0.3),
                    Color(red: 0.05, green: 0.2, blue: 0.35)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                // Header Image
                OnboardingHeader()

                // Title
                Text("Location Access")
                    .font(.title2.bold())
                    .foregroundColor(.white)

                // Explanation
                VStack(spacing: 16) {
                    Text("Been There needs continuous location access to track your journeys.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white.opacity(0.8))

                    // Why "Always" is needed
                    VStack(alignment: .leading, spacing: 12) {
                        WhyRow(text: "Track while you walk, drive, or travel")
                        WhyRow(text: "Continue when you switch apps")
                        WhyRow(text: "Auto-start tracking with geofences")
                        WhyRow(text: "Detect places automatically")
                    }
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding(.horizontal, 24)

                Spacer()

                // Status and button
                VStack(spacing: 16) {
                    if locationManager.hasAlwaysPermission {
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
                                .foregroundColor(.white.opacity(0.7))

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
                                .background(
                                    LinearGradient(
                                        colors: [.cyan, .blue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(25)
                        }
                        .accessibilityLabel("Enable location access")
                    }
                }

                Spacer()
            }
            .padding()
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

// MARK: - Server Setup Page

struct ServerSetupPage: View {

    @ObservedObject var settingsManager: SettingsManager
    @State private var showingQRScanner = false
    @State private var showingManualSetup = false

    var onComplete: () -> Void
    var onSkipToApp: (() -> Void)?  // Skip directly to app

    var body: some View {
        ZStack {
            // Purple/teal gradient for server
            LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.08, blue: 0.2),
                    Color(red: 0.1, green: 0.12, blue: 0.25),
                    Color(red: 0.08, green: 0.15, blue: 0.22)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                // Header Image
                OnboardingHeader()

                // Title
                Text("Connect Your Server")
                    .font(.title2.bold())
                    .foregroundColor(.white)

                // Optional badge
                Text("OPTIONAL")
                    .font(.caption.bold())
                    .foregroundColor(.cyan)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.cyan.opacity(0.2))
                    .cornerRadius(8)

                // Explanation
                Text("Connect to your Nextcloud PhoneTrack server to stream location data. You can set this up later in Settings.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 24)

                Spacer()

                // Setup options
                VStack(spacing: 16) {
                    // QR Code option
                    Button(action: { showingQRScanner = true }) {
                        HStack {
                            Image(systemName: "qrcode.viewfinder")
                                .font(.title2)
                                .foregroundColor(.cyan)
                            VStack(alignment: .leading) {
                                Text("Scan QR Code")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text("Quick setup from PhoneTrack")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                    }

                    // Manual setup option
                    Button(action: { showingManualSetup = true }) {
                        HStack {
                            Image(systemName: "keyboard")
                                .font(.title2)
                                .foregroundColor(.purple)
                            VStack(alignment: .leading) {
                                Text("Manual Setup")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text("Enter server details manually")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                // Bottom buttons
                VStack(spacing: 16) {
                    if settingsManager.serverConfig != nil {
                        // Server configured - show Continue button
                        Button(action: onComplete) {
                            Text("Continue")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    LinearGradient(
                                        colors: [.purple, .cyan],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(25)
                        }
                        .padding(.horizontal, 24)
                    }

                    // Skip button - always visible and prominent
                    Button(action: {
                        if let skipToApp = onSkipToApp {
                            skipToApp()
                        } else {
                            onComplete()
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.right.circle.fill")
                            Text("Skip & Start Using App")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(25)
                        .overlay(
                            RoundedRectangle(cornerRadius: 25)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 24)

                    Text("You can configure server later in Settings")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }

                Spacer()
            }
            .padding()
        }
        .sheet(isPresented: $showingQRScanner) {
            QRScannerSheet(settingsManager: settingsManager, isPresented: $showingQRScanner)
        }
        .sheet(isPresented: $showingManualSetup) {
            ManualSetupSheet(settingsManager: settingsManager, isPresented: $showingManualSetup)
        }
    }
}

// MARK: - Onboarding Header

struct OnboardingHeader: View {
    var body: some View {
        Image("HeaderImage")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(height: 120)
            .frame(maxWidth: .infinity)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.4), .cyan.opacity(0.3), .white.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: .cyan.opacity(0.3), radius: 15, x: 0, y: 5)
            .shadow(color: .blue.opacity(0.2), radius: 25, x: 0, y: 10)
            .padding(.horizontal, 20)
            .padding(.top, 20)
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
                .foregroundColor(.cyan)
                .frame(width: 40)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))
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
                    .fill(color.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()
        }
        .padding()
        .background(Color.white.opacity(0.08))
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
                .foregroundColor(.white.opacity(0.9))
        }
    }
}

// MARK: - QR Scanner Sheet

struct QRScannerSheet: View {
    @ObservedObject var settingsManager: SettingsManager
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            QRCodeScanner { code in
                // Parse the QR code
                if let config = ServerConfig.parse(from: code) {
                    settingsManager.serverConfig = config
                    isPresented = false
                }
            }
            .navigationTitle("Scan QR Code")
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
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .accessibilityLabel("Server URL")

                    TextField("Token", text: $token)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
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

// MARK: - Restore Data Page

struct RestoreDataPage: View {
    var onComplete: () -> Void

    @StateObject private var backupManager = FullBackupManager.shared
    @StateObject private var iCloudSync = iCloudSyncManager.shared

    @State private var showRestoreFilePicker = false
    @State private var showRestoreResult = false
    @State private var restoreResult: RestoreResult?
    @State private var isRestoring = false
    @State private var restoreError: String?

    var body: some View {
        ZStack {
            // Teal/green gradient for restore
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.12, blue: 0.15),
                    Color(red: 0.08, green: 0.18, blue: 0.2),
                    Color(red: 0.05, green: 0.15, blue: 0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                // Header Image
                OnboardingHeader()

                // Title
                Text("Restore Your Data")
                    .font(.title2.bold())
                    .foregroundColor(.white)

                // Subtitle
                Text("Reinstalling? Restore from a backup or sync from iCloud.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 24)

                Spacer()

                // Restore options
                VStack(spacing: 16) {
                    // Restore from file
                    Button(action: { showRestoreFilePicker = true }) {
                        HStack {
                            Image(systemName: "doc.zipper")
                                .font(.title2)
                                .foregroundColor(.orange)
                            VStack(alignment: .leading) {
                                Text("Restore from Backup")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text("Select a JSON backup file")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            Spacer()
                            if isRestoring {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .disabled(isRestoring)

                    // Restore from iCloud
                    Button(action: restoreFromICloud) {
                        HStack {
                            Image(systemName: "icloud.and.arrow.down")
                                .font(.title2)
                                .foregroundColor(.cyan)
                            VStack(alignment: .leading) {
                                Text("Restore from iCloud")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text("Sync data from other devices")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.6))
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
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .disabled(!iCloudSync.iCloudAvailable || iCloudSync.isSyncing || isRestoring)
                }
                .padding(.horizontal, 24)

                // Error message
                if let error = restoreError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }

                Spacer()

                // Divider with "or"
                HStack {
                    Rectangle()
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 1)
                    Text("or")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.5))
                    Rectangle()
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 1)
                }
                .padding(.horizontal, 40)

                // Start Fresh button
                Button(action: onComplete) {
                    Text("Start Fresh")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [.teal, .cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(25)
                }
                .padding(.horizontal, 24)

                Text("You can always restore later from Settings")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))

                Spacer()
            }
            .padding()
        }
        .fileImporter(
            isPresented: $showRestoreFilePicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result)
        }
        .alert("Restore Complete", isPresented: $showRestoreResult) {
            Button("Continue") {
                onComplete()
            }
        } message: {
            if let result = restoreResult {
                Text("Restored \(result.totalItemsRestored) items:\n• \(result.sessionsRestored) sessions\n• \(result.countriesRestored) countries\n• \(result.citiesRestored) cities\n• \(result.placesRestored) places")
            }
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
                restoreResult = backupManager.restoreFromBackup(data, mergeMode: .merge)
                isRestoring = false

                if restoreResult?.success == true {
                    showRestoreResult = true
                } else {
                    restoreError = "Failed to restore backup"
                }
            } catch {
                isRestoring = false
                restoreError = "Error reading file: \(error.localizedDescription)"
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
                    onComplete()
                }
            }
        }
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
