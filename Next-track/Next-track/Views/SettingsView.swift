//
//  SettingsView.swift
//  Next-track
//
//  All configuration options
//

import SwiftUI

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

    var body: some View {
        NavigationStack {
            Form {
                // Connection Section
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
            } label: {
                Label("Scan QR Code", systemImage: "qrcode.viewfinder")
            }

            // Test Connection Button
            Button {
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
                let count = CountriesManager.shared.importHistoricalCountries()
                if count > 0 {
                    importAlertMessage = "Successfully imported \(count) countries with visit sessions."
                } else {
                    importAlertMessage = "No new countries to import. All countries have already been added."
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
                PendingLocationQueue.shared.clear()
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
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environmentObject(SettingsManager.shared)
}
