//
//  MainView.swift
//  Next-track
//
//  Main dashboard with tracking toggle and status
//

import SwiftUI
import CoreLocation

struct MainView: View {
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var phoneTrackAPI: PhoneTrackAPI

    @StateObject private var batteryMonitor = BatteryMonitor.shared
    @StateObject private var connectionMonitor = ConnectionMonitor.shared
    @StateObject private var historyManager = TrackingHistoryManager.shared
    @StateObject private var geofenceManager = GeofenceManager.shared

    @State private var selectedTab = 0
    @State private var isTracking = false
    @State private var showFullMap = false
    @State private var showStopConfirmation = false

    var body: some View {
        TabView(selection: $selectedTab) {
            // MARK: - Home Tab
            homeTab
                .tabItem {
                    Label("Track", systemImage: "location.fill")
                }
                .tag(0)

            // MARK: - Stats Tab
            StatsHistoryView()
                .tabItem {
                    Label("Stats", systemImage: "chart.bar.fill")
                }
                .tag(1)

            // MARK: - Settings Tab
            settingsTab
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(2)
        }
        .onChange(of: selectedTab) { _, _ in
            HapticManager.shared.selectionChanged()
        }
        .onAppear {
            setupLocationCallback()
            setupGeofenceCallbacks()
            connectionMonitor.requestNotificationPermission { _ in }
        }
    }

    // MARK: - Home Tab

    private var homeTab: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Custom App Title Header
                    CustomTitleHeaderView(
                        connectionMonitor: connectionMonitor,
                        batteryMonitor: batteryMonitor,
                        isTracking: isTracking,
                        hasIssues: hasIssues,
                        pendingCount: PendingLocationQueue.shared.count,
                        currentZoneName: geofenceManager.currentZone?.name
                    )

                    // Map Preview
                    mapPreview

                    // Tracking Toggle
                    trackingToggle

                    // Quick Stats
                    quickStats

                    // Connection Status
                    connectionStatus

                    // Last Update Info
                    lastUpdateInfo
                }
                .padding()
            }
            .toolbar(.hidden, for: .navigationBar)
            .fullScreenCover(isPresented: $showFullMap) {
                FullMapView()
            }
            .alert("Stop Tracking?", isPresented: $showStopConfirmation) {
                Button("Cancel", role: .cancel) {
                    HapticManager.shared.buttonTap()
                }
                Button("Stop", role: .destructive) {
                    stopTracking()
                }
            } message: {
                Text("Are you sure you want to stop tracking your location?")
            }
        }
    }

    // MARK: - Settings Tab

    private var settingsTab: some View {
        NavigationStack {
            List {
                Section("Connection") {
                    NavigationLink {
                        ConnectionSettingsView()
                    } label: {
                        Label("Server Settings", systemImage: "server.rack")
                    }
                    .hapticOnTap()
                }

                Section("Tracking") {
                    NavigationLink {
                        TrackingSettingsView()
                    } label: {
                        Label("Update Frequency", systemImage: "clock")
                    }
                    .hapticOnTap()

                    NavigationLink {
                        GeofenceSettingsView()
                            .environmentObject(locationManager)
                            .environmentObject(geofenceManager)
                    } label: {
                        Label("Geofencing", systemImage: "location.circle")
                    }
                    .hapticOnTap()

                    NavigationLink {
                        BatterySettingsView()
                    } label: {
                        Label("Battery Optimization", systemImage: "battery.75percent")
                    }
                    .hapticOnTap()
                }

                Section("Advanced") {
                    NavigationLink {
                        DataSettingsView()
                    } label: {
                        Label("Data Options", systemImage: "antenna.radiowaves.left.and.right")
                    }
                    .hapticOnTap()
                }

                Section("About") {
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
                            .foregroundColor(PendingLocationQueue.shared.count > 0 ? .orange : .secondary)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }

    // MARK: - Status Header

    private var statusHeader: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 12, height: 12)

            Text(statusText)
                .font(.headline)
                .foregroundColor(statusColor)

            Spacer()

            // Pending indicator
            if PendingLocationQueue.shared.count > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "tray.full.fill")
                        .foregroundColor(.orange)
                    Text("\(PendingLocationQueue.shared.count)")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(.trailing, 8)
            }

            // Battery indicator
            HStack(spacing: 4) {
                Image(systemName: batteryIcon)
                    .foregroundColor(batteryColor)
                Text("\(batteryMonitor.batteryLevel)%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Pending Locations Banner

    private var pendingLocationsBanner: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(PendingLocationQueue.shared.count) locations pending")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("Will send when connection is restored")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("Retry") {
                HapticManager.shared.buttonTap()
                PhoneTrackAPI.shared.sendPendingLocations()
            }
            .buttonStyle(.bordered)
            .tint(.orange)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }

    private var statusColor: Color {
        if !settingsManager.isConfigured {
            return .orange
        }
        if isTracking {
            return .green
        }
        return .gray
    }

    private var statusText: String {
        if !settingsManager.isConfigured {
            return "Not Configured"
        }
        if isTracking {
            return "Tracking Active"
        }
        return "Tracking Paused"
    }

    private var hasIssues: Bool {
        phoneTrackAPI.connectionStatus == .error ||
        phoneTrackAPI.connectionStatus == .disconnected ||
        PendingLocationQueue.shared.count > 0 ||
        !settingsManager.isConfigured
    }

    private var batteryIcon: String {
        if batteryMonitor.isCharging {
            return "battery.100.bolt"
        }
        switch batteryMonitor.batteryLevel {
        case 0...10: return "battery.0"
        case 11...25: return "battery.25"
        case 26...50: return "battery.50"
        case 51...75: return "battery.75"
        default: return "battery.100"
        }
    }

    private var batteryColor: Color {
        if batteryMonitor.isCharging { return .green }
        if batteryMonitor.batteryLevel <= 10 { return .red }
        if batteryMonitor.batteryLevel <= 20 { return .orange }
        return .primary
    }

    // MARK: - Map Preview

    private var mapPreview: some View {
        Button {
            showFullMap = true
            HapticManager.shared.buttonTap()
        } label: {
            MapPreviewView(
                location: locationManager.currentLocation,
                sessionLocations: historyManager.currentSession?.locations ?? []
            )
            .frame(height: 200)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Tracking Toggle

    private var trackingToggle: some View {
        VStack(spacing: 12) {
            Button {
                HapticManager.shared.importantButtonTap()
                if isTracking {
                    showStopConfirmation = true
                } else {
                    startTracking()
                }
            } label: {
                HStack {
                    Image(systemName: isTracking ? "location.fill" : "location")
                        .font(.title)
                    Text(isTracking ? "Stop Tracking" : "Start Tracking")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(isTracking ? Color.red : Color.green)
                .foregroundColor(.white)
                .cornerRadius(16)
            }
            .disabled(!settingsManager.isConfigured)

            if !settingsManager.isConfigured {
                Text("Configure server settings to start tracking")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
    }

    // MARK: - Quick Stats

    private var quickStats: some View {
        HStack(spacing: 16) {
            StatCard(
                title: "Points Today",
                value: "\(historyManager.todaysPoints)",
                icon: "mappin.and.ellipse"
            )

            StatCard(
                title: "Distance",
                value: formatDistance(historyManager.todaysDistance),
                icon: "figure.walk"
            )

            StatCard(
                title: "Accuracy",
                value: formatAccuracy(locationManager.currentLocation?.horizontalAccuracy),
                icon: "scope"
            )
        }
    }

    // MARK: - Connection Status

    private var connectionStatus: some View {
        HStack {
            Image(systemName: connectionIcon)
                .foregroundColor(connectionColor)

            Text(connectionText)
                .font(.subheadline)

            Spacer()

            if phoneTrackAPI.isSending {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var connectionIcon: String {
        switch phoneTrackAPI.connectionStatus {
        case .connected: return "checkmark.circle.fill"
        case .disconnected: return "xmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }

    private var connectionColor: Color {
        switch phoneTrackAPI.connectionStatus {
        case .connected: return .green
        case .disconnected: return .orange
        case .error: return .red
        case .unknown: return .gray
        }
    }

    private var connectionText: String {
        switch phoneTrackAPI.connectionStatus {
        case .connected: return "Connected to server"
        case .disconnected: return "Disconnected"
        case .error: return "Connection error"
        case .unknown: return "Connection status unknown"
        }
    }

    // MARK: - Last Update Info

    private var lastUpdateInfo: some View {
        Group {
            if let lastSent = settingsManager.trackingStats.lastSuccessfulSend {
                HStack {
                    Text("Last sent:")
                        .foregroundColor(.secondary)
                    Text(lastSent, style: .relative)
                    Text("ago")
                        .foregroundColor(.secondary)
                }
                .font(.caption)
            }
        }
    }

    // MARK: - Actions

    private func startTracking() {
        let settings = settingsManager.trackingSettings

        if settings.significantLocationEnabled {
            locationManager.startSignificantLocationMonitoring()
        } else {
            let interval = calculateEffectiveInterval()
            locationManager.startTracking(
                interval: interval,
                minimumAccuracy: settings.minimumAccuracyMeters
            )
        }

        settingsManager.startSession()
        historyManager.startNewSession()
        isTracking = true

        HapticManager.shared.trackingStarted()
    }

    private func stopTracking() {
        locationManager.stopTracking()
        locationManager.stopSignificantLocationMonitoring()
        historyManager.endCurrentSession()
        isTracking = false

        HapticManager.shared.trackingStopped()
    }

    private func calculateEffectiveInterval() -> TimeInterval {
        let settings = settingsManager.trackingSettings
        let baseInterval = settings.effectiveInterval
        let multiplier = batteryMonitor.recommendedIntervalMultiplier(settings: settings)

        if multiplier == 0 {
            return baseInterval * 10
        }

        return baseInterval * multiplier
    }

    private func setupLocationCallback() {
        // Capture references directly to avoid SwiftUI view lifecycle issues
        let historyMgr = TrackingHistoryManager.shared
        let phoneTrk = phoneTrackAPI
        let settingsMgr = settingsManager
        let connMon = connectionMonitor
        let battMon = batteryMonitor
        let locMgr = locationManager

        locationManager.onLocationUpdate = { location in
            // Record location to history (this was failing before due to closure capture)
            historyMgr.addLocation(location)

            let distance = locMgr.getDistanceFromLastSent() ?? 0

            phoneTrk.sendLocation(location) { result in
                switch result {
                case .success:
                    settingsMgr.recordSuccessfulSend(distance: distance)
                    connMon.recordSuccessfulSend()
                    HapticManager.shared.locationSent()
                case .failure:
                    settingsMgr.recordFailedSend()
                    connMon.recordFailedSend()
                    if settingsMgr.trackingSettings.retryFailedSends {
                        let locationData = LocationData(
                            from: location,
                            batteryLevel: battMon.batteryLevel
                        )
                        PendingLocationQueue.shared.add(locationData)
                    }
                }
            }
        }
    }

    private func setupGeofenceCallbacks() {
        geofenceManager.onShouldStartTracking = { [self] in
            if !isTracking {
                startTracking()
            }
        }
        geofenceManager.onShouldStopTracking = { [self] in
            if isTracking {
                stopTracking()
            }
        }
    }

    // MARK: - Formatters

    private func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        }
        return String(format: "%.0f m", meters)
    }

    private func formatAccuracy(_ accuracy: Double?) -> String {
        guard let acc = accuracy, acc >= 0 else { return "--" }
        return String(format: "%.0f m", acc)
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)

            Text(value)
                .font(.headline)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Placeholder Settings Views

struct ConnectionSettingsView: View {
    var body: some View {
        SettingsView()
    }
}

struct TrackingSettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var trackingSettings = TrackingSettings.default

    var body: some View {
        Form {
            Section("Update Interval") {
                Picker("Preset", selection: $trackingSettings.intervalPreset) {
                    ForEach(IntervalPreset.allCases, id: \.self) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                }
                .onChange(of: trackingSettings.intervalPreset) { _, _ in
                    HapticManager.shared.selectionChanged()
                }

                if trackingSettings.intervalPreset == .custom {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Custom Interval")
                            Spacer()
                            Text(formatInterval(trackingSettings.customIntervalSeconds))
                                .foregroundColor(.secondary)
                        }
                        Slider(
                            value: Binding(
                                get: { log10(trackingSettings.customIntervalSeconds) },
                                set: { trackingSettings.customIntervalSeconds = pow(10, $0) }
                            ),
                            in: log10(5)...log10(3600)
                        )
                        .onChange(of: trackingSettings.customIntervalSeconds) { _, _ in
                            HapticManager.shared.sliderChanged()
                        }
                    }
                }
            }
        }
        .navigationTitle("Update Frequency")
        .onAppear {
            trackingSettings = settingsManager.trackingSettings
        }
        .onDisappear {
            settingsManager.updateTrackingSettings(trackingSettings)
        }
    }

    private func formatInterval(_ seconds: TimeInterval) -> String {
        if seconds < 60 {
            return "\(Int(seconds))s"
        } else if seconds < 3600 {
            return "\(Int(seconds / 60))m"
        } else {
            return "\(Int(seconds / 3600))h"
        }
    }
}

struct BatterySettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var trackingSettings = TrackingSettings.default

    var body: some View {
        Form {
            Section {
                Toggle("Smart Mode", isOn: $trackingSettings.smartModeEnabled)
                    .onChange(of: trackingSettings.smartModeEnabled) { _, _ in
                        HapticManager.shared.toggleChanged()
                    }

                if trackingSettings.smartModeEnabled {
                    Stepper(
                        "Low battery: \(trackingSettings.smartModeBatteryThreshold)%",
                        value: $trackingSettings.smartModeBatteryThreshold,
                        in: 10...50,
                        step: 5
                    )
                }
            } footer: {
                Text("Reduces update frequency when battery is low")
            }

            Section {
                Toggle("Significant Location Only", isOn: $trackingSettings.significantLocationEnabled)
                    .onChange(of: trackingSettings.significantLocationEnabled) { _, _ in
                        HapticManager.shared.toggleChanged()
                    }
            } footer: {
                Text("Only updates when you move ~500m. Uses very little battery.")
            }

            Section {
                Toggle("Motion-Aware", isOn: $trackingSettings.motionAwareEnabled)
                    .onChange(of: trackingSettings.motionAwareEnabled) { _, _ in
                        HapticManager.shared.toggleChanged()
                    }
            } footer: {
                Text("Adjusts frequency based on movement")
            }
        }
        .navigationTitle("Battery Optimization")
        .onAppear {
            trackingSettings = settingsManager.trackingSettings
        }
        .onDisappear {
            settingsManager.updateTrackingSettings(trackingSettings)
        }
    }
}

struct DataSettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var trackingSettings = TrackingSettings.default

    var body: some View {
        Form {
            Section("Data to Send") {
                Toggle("Altitude", isOn: $trackingSettings.sendAltitude)
                Toggle("Speed", isOn: $trackingSettings.sendSpeed)
                Toggle("Bearing", isOn: $trackingSettings.sendBearing)
                Toggle("Battery Level", isOn: $trackingSettings.sendBatteryLevel)
                Toggle("Accuracy", isOn: $trackingSettings.sendAccuracy)
            }

            Section("Reliability") {
                Toggle("Retry Failed Sends", isOn: $trackingSettings.retryFailedSends)

                VStack(alignment: .leading) {
                    HStack {
                        Text("Min Accuracy")
                        Spacer()
                        Text("\(Int(trackingSettings.minimumAccuracyMeters))m")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $trackingSettings.minimumAccuracyMeters, in: 10...500, step: 10)
                }
            }

            Section {
                Toggle("Debug Logging", isOn: $trackingSettings.debugLogging)
            }
        }
        .navigationTitle("Data Options")
        .onAppear {
            trackingSettings = settingsManager.trackingSettings
        }
        .onDisappear {
            settingsManager.updateTrackingSettings(trackingSettings)
        }
    }
}

// MARK: - Preview

#Preview {
    MainView()
        .environmentObject(LocationManager.shared)
        .environmentObject(SettingsManager.shared)
        .environmentObject(PhoneTrackAPI.shared)
}
