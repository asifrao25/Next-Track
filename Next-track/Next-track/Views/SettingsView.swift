//
//  SettingsView.swift
//  Next-track
//
//  All configuration options
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settingsManager: SettingsManager

    @State private var serverConfig: ServerConfig = .default
    @State private var trackingSettings: TrackingSettings = .default
    @State private var showQRScanner = false
    @State private var isTestingConnection = false
    @State private var connectionTestResult: String?
    @State private var connectionTestSuccess: Bool?
    @State private var showImportAlert = false
    @State private var importAlertMessage = ""
    @State private var showInstructions = false

    var body: some View {
        NavigationStack {
            Form {
                // Setup Instructions Section
                setupInstructionsSection

                // Connection Section (Server Settings)
                connectionSection

                // Update Frequency Section
                frequencySection

                // Battery Optimization Section
                batterySection

                // Data Options Section
                dataSection

                // Advanced Section
                advancedSection

                // Countries Data Section
                countriesSection

                // About Section
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        HapticManager.shared.success()
                        saveSettings()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showQRScanner) {
                QRScannerView { scannedURL in
                    if let config = ServerConfig.parse(from: scannedURL) {
                        serverConfig = config
                    }
                    showQRScanner = false
                }
            }
            .onAppear {
                loadSettings()
            }
            .alert("Import Complete", isPresented: $showImportAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(importAlertMessage)
            }
        }
    }

    // MARK: - Setup Instructions Section

    private var setupInstructionsSection: some View {
        Section {
            // Collapsible Header
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showInstructions.toggle()
                }
                HapticManager.shared.light()
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .cyan],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)

                        Image(systemName: "questionmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Setup Instructions")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("How to connect to PhoneTrack")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(showInstructions ? 90 : 0))
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)

            // Expanded Instructions
            if showInstructions {
                VStack(alignment: .leading, spacing: 20) {
                    // Introduction
                    Text("This app works with Nextcloud PhoneTrack to log your location. Follow these steps to get started:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 4)

                    // Step 1
                    InstructionStepView(
                        number: 1,
                        title: "Install PhoneTrack on Nextcloud",
                        description: "Log into your Nextcloud server as an admin. Go to Apps (top-right menu) → search for \"PhoneTrack\" → click Download and Enable. PhoneTrack will appear in your Nextcloud navigation menu.",
                        icon: "arrow.down.app.fill",
                        color: .blue
                    )

                    // Step 2
                    InstructionStepView(
                        number: 2,
                        title: "Create a Tracking Session",
                        description: "Open PhoneTrack from your Nextcloud menu. Click the \"+\" button to create a new session. Enter a name (e.g., \"My iPhone\") and optionally set a token. This session will store all your location data.",
                        icon: "plus.circle.fill",
                        color: .green
                    )

                    // Step 3
                    InstructionStepView(
                        number: 3,
                        title: "Get the Logging URL or QR Code",
                        description: "In PhoneTrack, find your session and click the share/link icon (🔗). Select \"Logging URL (GET)\" - this shows a URL and QR code. The QR code contains all the connection info you need.",
                        icon: "link.circle.fill",
                        color: .orange
                    )

                    // QR Code Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "qrcode")
                                .font(.title3)
                                .foregroundColor(.purple)
                            Text("Using QR Code (Easiest)")
                                .font(.subheadline)
                                .fontWeight(.bold)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            QRInstructionRow(step: "1", text: "On your computer, display the QR code from PhoneTrack")
                            QRInstructionRow(step: "2", text: "In this app, tap \"Scan QR Code\" button below")
                            QRInstructionRow(step: "3", text: "Point your camera at the QR code on screen")
                            QRInstructionRow(step: "4", text: "The Server URL, Token, and Device Name will auto-fill!")
                        }

                        Text("💡 Tip: Make sure the QR code is fully visible and well-lit for best scanning results.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.purple.opacity(0.1))
                            )
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(UIColor.tertiarySystemGroupedBackground))
                    )

                    // Step 4 - Manual Entry
                    InstructionStepView(
                        number: 4,
                        title: "Manual Entry (Alternative)",
                        description: "If QR scanning doesn't work, manually enter the details:\n\n• Server URL: Your Nextcloud address\n  (e.g., https://cloud.example.com)\n\n• Token: The long code from the URL after \"logGet/\"\n  (e.g., abc123def456)\n\n• Device Name: Any name for this phone\n  (e.g., \"iPhone\" or \"My Phone\")",
                        icon: "keyboard",
                        color: .indigo
                    )

                    // Step 5
                    InstructionStepView(
                        number: 5,
                        title: "Test Your Connection",
                        description: "Tap the \"Test Connection\" button to verify everything is set up correctly. You should see a green checkmark if successful. If it fails, double-check your server URL and token.",
                        icon: "antenna.radiowaves.left.and.right",
                        color: .cyan
                    )

                    // Step 6
                    InstructionStepView(
                        number: 6,
                        title: "Start Tracking!",
                        description: "Go to the Track tab and tap the big button to start logging your location. Your position will be sent to PhoneTrack where you can view it on a map in real-time!",
                        icon: "location.fill",
                        color: .green
                    )

                    // URL Format Info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("📋 URL Format Reference")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text("The logging URL follows this pattern:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("https://your-server.com/index.php/apps/phonetrack/logGet/SESSION_TOKEN/DEVICE_NAME")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.orange)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(UIColor.tertiarySystemGroupedBackground))
                            )

                        Text("The app automatically extracts the server URL, token, and device name from this URL when you scan the QR code.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 8)

                    // Help Link
                    HStack {
                        Image(systemName: "questionmark.circle")
                            .foregroundColor(.blue)
                        Text("Need more help? Visit the PhoneTrack documentation on your Nextcloud server.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 4)
                }
                .padding(.vertical, 8)
            }
        } header: {
            Label("Getting Started", systemImage: "book.fill")
        }
    }

    // MARK: - Connection Section

    private var connectionSection: some View {
        Section {
            // Server URL
            VStack(alignment: .leading, spacing: 4) {
                Text("Server URL")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("https://your-nextcloud.com", text: $serverConfig.serverURL)
                    .textContentType(.URL)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
            }

            // Token
            VStack(alignment: .leading, spacing: 4) {
                Text("PhoneTrack Token")
                    .font(.caption)
                    .foregroundColor(.secondary)
                SecureField("Session token", text: $serverConfig.token)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
            }

            // Device Name
            VStack(alignment: .leading, spacing: 4) {
                Text("Device Name")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("iPhone", text: $serverConfig.deviceName)
                    .autocorrectionDisabled()
            }

            // QR Scanner Button
            Button {
                showQRScanner = true
                HapticManager.shared.light()
            } label: {
                Label("Scan QR Code", systemImage: "qrcode.viewfinder")
            }

            // Test Connection Button
            Button {
                HapticManager.shared.medium()
                testConnection()
            } label: {
                HStack {
                    Label("Test Connection", systemImage: "antenna.radiowaves.left.and.right")
                    Spacer()
                    if isTestingConnection {
                        ProgressView()
                    }
                }
            }
            .disabled(isTestingConnection || !serverConfig.isValid)

            // Connection Test Result
            if let result = connectionTestResult {
                HStack {
                    Image(systemName: connectionTestSuccess == true ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(connectionTestSuccess == true ? .green : .red)
                    Text(result)
                        .font(.caption)
                        .foregroundColor(connectionTestSuccess == true ? .green : .red)
                }
            }
        } header: {
            Text("Connection")
        } footer: {
            Text("Get the logging URL from PhoneTrack in Nextcloud. The token is the unique identifier for your tracking session.")
        }
    }

    // MARK: - Frequency Section

    private var frequencySection: some View {
        Section {
            // Preset Picker
            Picker("Update Interval", selection: $trackingSettings.intervalPreset) {
                ForEach(IntervalPreset.allCases, id: \.self) { preset in
                    Text(preset.displayName).tag(preset)
                }
            }

            // Custom Interval Slider
            if trackingSettings.intervalPreset == .custom {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Custom Interval")
                        Spacer()
                        Text(formatInterval(trackingSettings.customIntervalSeconds))
                            .foregroundColor(.secondary)
                    }

                    // Logarithmic slider for better UX
                    Slider(
                        value: Binding(
                            get: { log10(trackingSettings.customIntervalSeconds) },
                            set: { trackingSettings.customIntervalSeconds = pow(10, $0) }
                        ),
                        in: log10(5)...log10(3600), // 5 seconds to 60 minutes
                        step: 0.1
                    )
                }
            }
        } header: {
            Text("Update Frequency")
        } footer: {
            Text("More frequent updates use more battery. Consider using Battery Saver mode for longer trips.")
        }
    }

    // MARK: - Battery Section

    private var batterySection: some View {
        Section {
            Toggle("Smart Mode", isOn: $trackingSettings.smartModeEnabled)

            if trackingSettings.smartModeEnabled {
                Stepper(
                    "Low battery threshold: \(trackingSettings.smartModeBatteryThreshold)%",
                    value: $trackingSettings.smartModeBatteryThreshold,
                    in: 10...50,
                    step: 5
                )

                Toggle("Pause on Critical Battery", isOn: $trackingSettings.pauseOnCriticalBattery)

                if trackingSettings.pauseOnCriticalBattery {
                    Stepper(
                        "Critical threshold: \(trackingSettings.criticalBatteryThreshold)%",
                        value: $trackingSettings.criticalBatteryThreshold,
                        in: 5...20,
                        step: 5
                    )
                }
            }

            Toggle("Significant Location Only", isOn: $trackingSettings.significantLocationEnabled)

            Toggle("Motion-Aware Tracking", isOn: $trackingSettings.motionAwareEnabled)

            if trackingSettings.motionAwareEnabled {
                Stepper(
                    "Stationary delay: \(trackingSettings.stationaryDelayMinutes) min",
                    value: $trackingSettings.stationaryDelayMinutes,
                    in: 1...30
                )
            }

            Toggle("Smart Movement Tracking", isOn: $trackingSettings.smartMovementTrackingEnabled)
        } header: {
            Text("Battery Optimization")
        } footer: {
            Text("Smart Mode reduces update frequency when battery is low. Significant Location mode only updates when you move ~500m. Smart Movement Tracking progressively reduces frequency when stationary (up to 30 min intervals).")
        }
    }

    // MARK: - Data Section

    private var dataSection: some View {
        Section {
            Toggle("Send Altitude", isOn: $trackingSettings.sendAltitude)
            Toggle("Send Speed", isOn: $trackingSettings.sendSpeed)
            Toggle("Send Bearing", isOn: $trackingSettings.sendBearing)
            Toggle("Send Battery Level", isOn: $trackingSettings.sendBatteryLevel)
            Toggle("Send Accuracy", isOn: $trackingSettings.sendAccuracy)
        } header: {
            Text("Data to Send")
        }
    }

    // MARK: - Advanced Section

    private var advancedSection: some View {
        Section {
            Toggle("Retry Failed Sends", isOn: $trackingSettings.retryFailedSends)

            if trackingSettings.retryFailedSends {
                Stepper(
                    "Max retries: \(trackingSettings.maxRetryAttempts)",
                    value: $trackingSettings.maxRetryAttempts,
                    in: 1...10
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Minimum Accuracy")
                    Spacer()
                    Text("\(Int(trackingSettings.minimumAccuracyMeters))m")
                        .foregroundColor(.secondary)
                }
                Slider(
                    value: $trackingSettings.minimumAccuracyMeters,
                    in: 10...500,
                    step: 10
                )
            }

            Toggle("Debug Logging", isOn: $trackingSettings.debugLogging)
        } header: {
            Text("Advanced")
        } footer: {
            Text("Locations with accuracy worse than the minimum will be ignored.")
        }
    }

    // MARK: - Countries Section

    private var countriesSection: some View {
        Section {
            Button {
                HapticManager.shared.medium()
                let count = CountriesManager.shared.importHistoricalCountries()
                if count > 0 {
                    importAlertMessage = "Successfully imported \(count) countries with visit sessions."
                    HapticManager.shared.success()
                } else {
                    importAlertMessage = "No new countries to import. All countries have already been added."
                    HapticManager.shared.light()
                }
                showImportAlert = true
            } label: {
                HStack {
                    Label("Import Historical Countries", systemImage: "globe.badge.chevron.backward")
                    Spacer()
                    Text("11 countries")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Text("Countries Data")
        } footer: {
            Text("Import pre-analyzed historical visits from 2019-2025 including Spain, Denmark, Hungary, Czech Republic, Pakistan, UAE, Turkey, Saudi Arabia, Qatar, Bahrain, and Switzerland.")
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                Spacer()
                Text("1.0.0")
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("Pending Locations")
                Spacer()
                Text("\(PendingLocationQueue.shared.count)")
                    .foregroundColor(.secondary)
            }

            Button(role: .destructive) {
                HapticManager.shared.warning()
                PendingLocationQueue.shared.clear()
                HapticManager.shared.success()
            } label: {
                Text("Clear Pending Queue")
            }
            .disabled(PendingLocationQueue.shared.isEmpty)
        } header: {
            Text("About")
        }
    }

    // MARK: - Actions

    private func loadSettings() {
        serverConfig = settingsManager.serverConfig
        trackingSettings = settingsManager.trackingSettings
    }

    private func saveSettings() {
        settingsManager.updateServerConfig(serverConfig)
        settingsManager.updateTrackingSettings(trackingSettings)

        // Update location manager with new settings
        if LocationManager.shared.isTracking {
            LocationManager.shared.updateSettings(
                interval: trackingSettings.effectiveInterval,
                minimumAccuracy: trackingSettings.minimumAccuracyMeters
            )
        }
    }

    private func testConnection() {
        isTestingConnection = true
        connectionTestResult = nil
        connectionTestSuccess = nil

        // Temporarily save config for testing
        let tempConfig = serverConfig
        settingsManager.updateServerConfig(tempConfig)

        PhoneTrackAPI.shared.testConnection { success, message in
            isTestingConnection = false
            connectionTestResult = message
            connectionTestSuccess = success

            // Haptic feedback based on result
            if success {
                HapticManager.shared.success()
            } else {
                HapticManager.shared.error()
            }
        }
    }

    private func formatInterval(_ seconds: TimeInterval) -> String {
        if seconds < 60 {
            return "\(Int(seconds))s"
        } else if seconds < 3600 {
            let minutes = Int(seconds) / 60
            let secs = Int(seconds) % 60
            if secs == 0 {
                return "\(minutes)m"
            }
            return "\(minutes)m \(secs)s"
        } else {
            let hours = Int(seconds) / 3600
            let minutes = (Int(seconds) % 3600) / 60
            if minutes == 0 {
                return "\(hours)h"
            }
            return "\(hours)h \(minutes)m"
        }
    }

    private func formatDistance(_ meters: Double) -> String {
        let miles = meters / 1609.344
        if miles >= 0.1 {
            return String(format: "%.1f mi", miles)
        }
        let feet = meters * 3.28084
        return String(format: "%.0f ft", feet)
    }
}

// MARK: - Instruction Step View

struct InstructionStepView: View {
    let number: Int
    let title: String
    let description: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Step number circle
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 32, height: 32)

                Text("\(number)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(color)

                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - QR Instruction Row

struct QRInstructionRow: View {
    let step: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(step)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.purple))

            Text(text)
                .font(.caption)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Data Summary Item

struct DataSummaryItem: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Restore Button

struct RestoreButton: View {
    let isImporting: Bool
    let action: () -> Void

    var body: some View {
        HStack {
            Spacer()
            if isImporting {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(0.8)
                Text("Restoring...")
            } else {
                Image(systemName: "arrow.down.doc.fill")
                Text("Restore from Backup")
            }
            Spacer()
        }
        .font(.headline)
        .foregroundColor(.white)
        .padding(.vertical, 14)
        .background(
            LinearGradient(
                colors: [.orange, .red],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(10)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isImporting {
                action()
            }
        }
        .opacity(isImporting ? 0.6 : 1)
    }
}

// MARK: - Restore File Picker View

struct RestoreFilePickerView: UIViewControllerRepresentable {
    let onResult: (Result<[URL], Error>) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.json, .data, .plainText])
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onResult: onResult)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onResult: (Result<[URL], Error>) -> Void

        init(onResult: @escaping (Result<[URL], Error>) -> Void) {
            self.onResult = onResult
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            print("[RestoreFilePicker] Selected files: \(urls)")
            onResult(.success(urls))
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            print("[RestoreFilePicker] Cancelled")
            onResult(.success([]))
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environmentObject(SettingsManager.shared)
}
