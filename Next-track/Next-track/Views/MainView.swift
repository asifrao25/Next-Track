//
//  MainView.swift
//  Next-track
//
//  Main dashboard with tracking toggle and status
//

import SwiftUI
import CoreLocation
import UserNotifications
import MapKit

struct MainView: View {
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var phoneTrackAPI: PhoneTrackAPI

    @StateObject private var batteryMonitor = BatteryMonitor.shared
    @StateObject private var connectionMonitor = ConnectionMonitor.shared
    @StateObject private var historyManager = TrackingHistoryManager.shared
    @StateObject private var geofenceManager = GeofenceManager.shared
    @StateObject private var trackingStateManager = TrackingStateManager.shared
    @StateObject private var cityTracker = CityTracker.shared
    @StateObject private var placeManager = PlaceDetectionManager.shared
    @StateObject private var insightsManager = InsightsManager.shared
    @StateObject private var countriesManager = CountriesManager.shared

    @State private var selectedTab = AppTab.centerIndex  // Start on Track tab (index 3)
    @State private var isTracking = false
    @State private var startupCompleted = false
    @State private var showFullMap = false
    @State private var showStopConfirmation = false
    @State private var showRecoveryAlert = false
    @State private var showInterruptedTrackingAlert = false
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var pendingCenterOnLocation = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // Tab content
            Group {
                switch selectedTab {
                case AppTab.stats.rawValue:
                    StatsHistoryView()
                case AppTab.cities.rawValue:
                    CitiesView()
                case AppTab.places.rawValue:
                    PlacesView()
                case AppTab.track.rawValue:
                    homeTab
                case AppTab.countries.rawValue:
                    CountriesView()
                case AppTab.insights.rawValue:
                    InsightsView()
                case AppTab.settings.rawValue:
                    settingsTab
                default:
                    homeTab
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Custom scrollable tab bar
            ScrollableTabBar(
                selectedTab: $selectedTab,
                tabs: AppTab.allTabs,
                centerIndex: AppTab.centerIndex
            )
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onChange(of: selectedTab) { _, _ in
            HapticManager.shared.selectionChanged()
        }
        .onChange(of: locationManager.currentLocation) { _, newLocation in
            // Center on location once it arrives if requested
            if pendingCenterOnLocation, let loc = newLocation {
                pendingCenterOnLocation = false
                withAnimation(.easeInOut(duration: 0.3)) {
                    mapPosition = .camera(MapCamera(
                        centerCoordinate: loc.coordinate,
                        distance: 800,
                        heading: 0,
                        pitch: 0
                    ))
                }
                HapticManager.shared.success()
            }
        }
        .onAppear {
            setupLocationCallback()
            setupGeofenceCallbacks()
            connectionMonitor.requestNotificationPermission { _ in }
            // Sync tracking state from components
            trackingStateManager.syncStateFromComponents()
            isTracking = trackingStateManager.isTracking
            // Check for interrupted session recovery
            checkForSessionRecovery()
            // Coordinated startup sequence (replaces separate delays)
            performCoordinatedStartup()
        }
        .onChange(of: trackingStateManager.isTracking) { _, newValue in
            // Keep local state in sync with TrackingStateManager
            isTracking = newValue
        }
        .onDisappear {
            // Clear callbacks to prevent retain cycles
            clearGeofenceCallbacks()
        }
        .alert("Session Recovery", isPresented: $showRecoveryAlert) {
            Button("Save Session") {
                historyManager.saveRecoveredSession()
                HapticManager.shared.success()
            }
            Button("Discard", role: .destructive) {
                historyManager.discardRecoveredSession()
            }
        } message: {
            if let session = historyManager.recoverySession {
                Text("A previous tracking session was interrupted.\n\n\(session.pointsCount) location points recorded\n\(session.formattedDistance) traveled\n\nWould you like to save this data?")
            } else {
                Text("A previous tracking session was interrupted. Would you like to save the recorded data?")
            }
        }
        .alert("Tracking Interrupted", isPresented: $showInterruptedTrackingAlert) {
            Button("Resume Tracking") {
                startTracking()
                HapticManager.shared.trackingStarted()
            }
            Button("Dismiss", role: .cancel) { }
        } message: {
            Text("Your tracking was interrupted (phone restart or app terminated). Would you like to resume?")
        }
    }

    // MARK: - Home Tab

    private var homeTab: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    // Full-screen map background
                    mapFullScreen
                        .ignoresSafeArea(edges: .bottom)

                    // Overlay content
                    VStack(spacing: 0) {
                        // Header at top
                        CustomTitleHeaderView(
                            connectionMonitor: connectionMonitor,
                            batteryMonitor: batteryMonitor,
                            isTracking: isTracking,
                            hasIssues: hasIssues,
                            pendingCount: PendingLocationQueue.shared.count,
                            currentZoneName: geofenceManager.currentZone?.name,
                            connectionStatus: mapConnectionStatus,
                            lastSuccessfulSend: settingsManager.trackingStats.lastSuccessfulSend
                        )
                        .padding(.horizontal)
                        .padding(.top, 8)

                        Spacer()

                        // Bottom controls (button + stats)
                        trackingOverlay
                            .padding(.bottom, 110)  // Account for custom tab bar height
                    }
                }
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

    // Helper to map PhoneTrackAPI connection status to our enum
    private var mapConnectionStatus: ConnectionStatusType {
        switch phoneTrackAPI.connectionStatus {
        case .connected:
            return .connected
        case .disconnected:
            return .disconnected
        case .error:
            return .error
        case .unknown:
            return .unknown
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

                    NavigationLink {
                        TrackAppearanceSettingsView()
                    } label: {
                        Label("Track Appearance", systemImage: "paintbrush")
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
                sessionLocations: historyManager.currentSession?.locations ?? [],
                historicalSessions: historyManager.sessions,
                position: $mapPosition
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

    // MARK: - Round Tracking Button (70pt)

    private var roundTrackingButton: some View {
        Button {
            HapticManager.shared.importantButtonTap()
            if isTracking {
                showStopConfirmation = true
            } else {
                startTracking()
            }
        } label: {
            Circle()
                .fill(isTracking ? Color.red : Color.green)
                .frame(width: 70, height: 70)
                .overlay(
                    Image(systemName: isTracking ? "stop.fill" : "play.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                )
        }
        .disabled(!settingsManager.isConfigured)
        .opacity(settingsManager.isConfigured ? 1.0 : 0.5)
    }

    // MARK: - Tracking Overlay (Button + Stats)

    private var trackingOverlay: some View {
        VStack(spacing: 10) {
            HStack(alignment: .center, spacing: 6) {
                // Left stat: Distance (orange)
                OverlayStatView(
                    value: formatDistance(historyManager.todaysDistance),
                    label: "Distance",
                    icon: "figure.walk",
                    color: .orange
                )

                // Center on location button
                Button {
                    centerOnLocation()
                } label: {
                    Image(systemName: "location.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Color.blue))
                }

                // Center: Round Start/Stop Button
                roundTrackingButton

                // Expand to full screen button
                Button {
                    showFullMap = true
                    HapticManager.shared.buttonTap()
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Color.purple))
                }

                // Right stat: Points Today (blue)
                OverlayStatView(
                    value: "\(historyManager.todaysPoints)",
                    label: "Points",
                    icon: "mappin.and.ellipse",
                    color: .blue
                )
            }
            .padding(.horizontal, 12)

            // Not configured warning
            if !settingsManager.isConfigured {
                Text("Configure server to start tracking")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: - Center on Location

    private func centerOnLocation() {
        HapticManager.shared.buttonTap()

        if let loc = locationManager.currentLocation {
            withAnimation(.easeInOut(duration: 0.3)) {
                mapPosition = .camera(MapCamera(
                    centerCoordinate: loc.coordinate,
                    distance: 800,
                    heading: 0,
                    pitch: 0
                ))
            }
        } else {
            // Request location if not available
            locationManager.requestSingleLocation()
            // Set flag to center once location arrives
            pendingCenterOnLocation = true
        }
    }

    // MARK: - Full Screen Map

    private var mapFullScreen: some View {
        MapPreviewView(
            location: locationManager.currentLocation,
            sessionLocations: historyManager.currentSession?.locations ?? [],
            historicalSessions: historyManager.sessions,
            position: $mapPosition
        )
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
        // Use TrackingStateManager for manual tracking start
        let success = trackingStateManager.startTracking(source: .manual)

        if success {
            // Update session tracking state
            settingsManager.startSession()
            historyManager.setTrackingState(true)
            HapticManager.shared.trackingStarted()
        }
    }

    private func stopTracking() {
        // Use TrackingStateManager for manual tracking stop
        let success = trackingStateManager.stopTracking(source: .manual)

        if success {
            // Clear tracking state (user intentionally stopped)
            historyManager.setTrackingState(false)
            HapticManager.shared.trackingStopped()
        }
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
        let cityTrk = CityTracker.shared
        let placeMgr = PlaceDetectionManager.shared

        locationManager.onLocationUpdate = { location in
            // Record location to history (this was failing before due to closure capture)
            historyMgr.addLocation(location)

            // Track city visits (rate-limited internally)
            cityTrk.processLocation(location)

            // Track place visits during active tracking
            placeMgr.processLocation(location, timestamp: location.timestamp)

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
        // Capture TrackingStateManager for geofence callbacks
        let trackingManager = TrackingStateManager.shared

        geofenceManager.onShouldStartTracking = {
            // Use TrackingStateManager for coordinated, debounced start
            let success = trackingManager.startTracking(source: .geofenceExit)

            if success {
                print("[Geofence] Tracking started via geofence exit")
                HapticManager.shared.trackingStarted()
            } else {
                print("[Geofence] Start tracking request was blocked (debounced or already tracking)")
            }
        }

        geofenceManager.onShouldStopTracking = {
            // Use TrackingStateManager for coordinated, debounced stop
            let success = trackingManager.stopTracking(source: .geofenceEnter)

            if success {
                print("[Geofence] Tracking stopped via geofence enter")
                HapticManager.shared.trackingStopped()
            } else {
                print("[Geofence] Stop tracking request was blocked (debounced or not tracking)")
            }
        }
    }

    private func clearGeofenceCallbacks() {
        geofenceManager.onShouldStartTracking = nil
        geofenceManager.onShouldStopTracking = nil
    }

    private func checkForSessionRecovery() {
        // Small delay to let the UI settle before showing alert
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if historyManager.hasRecoverySession {
                showRecoveryAlert = true
            }
        }
    }

    /// Coordinated startup sequence that waits for geofence state before making decisions
    /// This replaces the previous separate delayed operations that could race
    private func performCoordinatedStartup() {
        guard !startupCompleted else {
            print("[Startup] Already completed startup sequence")
            return
        }

        print("[Startup] ========== Starting coordinated startup ==========")

        // Capture references for use in closures
        let geoMgr = geofenceManager

        // Small delay to let the app initialize
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Step 1: Wait for geofence state check to complete (if monitoring)
            if geoMgr.isMonitoring {
                print("[Startup] Step 1: Waiting for geofence state check...")

                geoMgr.checkCurrentZoneStates {
                    print("[Startup] Step 1: Geofence state check complete")
                    self.completeStartupSequence()
                }
            } else {
                print("[Startup] Step 1: Geofencing not active - proceeding immediately")
                self.completeStartupSequence()
            }
        }
    }

    /// Second phase of startup after geofence state is known
    private func completeStartupSequence() {
        startupCompleted = true

        // Step 2: Check if in stop zone
        if trackingStateManager.isInStopZone() {
            if let zone = geofenceManager.currentZone {
                print("[Startup] Step 2: In stop zone '\(zone.name)' - will NOT auto-start")
            }
            // Still check for interrupted tracking (to show recovery option)
            checkForInterruptedTrackingRecovery()
            print("[Startup] ========== Startup complete (in stop zone) ==========")
            return
        }

        // Step 3: Check if already tracking
        guard !trackingStateManager.isTracking else {
            print("[Startup] Step 2: Already tracking - skipping auto-start")
            print("[Startup] ========== Startup complete (already tracking) ==========")
            return
        }

        // Step 4: Check if configured
        guard settingsManager.isConfigured else {
            print("[Startup] Step 3: Server not configured - skipping auto-start")
            print("[Startup] ========== Startup complete (not configured) ==========")
            return
        }

        // Step 5: Auto-start tracking
        print("[Startup] Step 4: Auto-starting tracking...")
        let success = trackingStateManager.startTracking(source: .autoStart)

        if success {
            print("[Startup] Auto-start successful")
            HapticManager.shared.trackingStarted()
            sendAutoStartNotification()
        } else {
            print("[Startup] Auto-start was blocked")
        }

        // Step 6: Check for interrupted tracking (even if auto-start succeeded, user might want to know)
        checkForInterruptedTrackingRecovery()

        print("[Startup] ========== Startup complete ==========")
    }

    private func sendAutoStartNotification() {
        let content = UNMutableNotificationContent()
        content.title = "📍 Tracking Started"
        content.body = "Next Track has automatically started location tracking."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "auto-start-tracking",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[AutoStart] Failed to send notification: \(error)")
            }
        }
    }

    /// Check if tracking was interrupted (phone restart, app crash) and offer recovery
    private func checkForInterruptedTrackingRecovery() {
        // Skip if already tracking
        guard !trackingStateManager.isTracking else {
            print("[RestartDetection] Already tracking - skipping interrupted check")
            return
        }

        // Check if was tracking before termination
        guard historyManager.wasTrackingBeforeTermination() else {
            print("[RestartDetection] Was not tracking before termination")
            return
        }

        // Check if it's been a while (indicating restart/crash, not normal app switch)
        if let lastTimestamp = historyManager.getLastTrackingTimestamp() {
            let timeSinceLastTracking = Date().timeIntervalSince(lastTimestamp)

            // If more than 5 minutes since last tracking activity
            if timeSinceLastTracking > 300 {
                print("[RestartDetection] Tracking was interrupted \(Int(timeSinceLastTracking/60)) min ago - showing alert")
                showInterruptedTrackingAlert = true
            } else {
                print("[RestartDetection] Recent tracking activity (\(Int(timeSinceLastTracking))s ago) - not showing alert")
            }
        }

        // Clear the state so we don't show again
        historyManager.clearWasTrackingState()
    }

    // MARK: - Formatters

    private func formatDistance(_ meters: Double) -> String {
        let miles = meters / 1609.344
        if miles >= 0.1 {
            return String(format: "%.2f mi", miles)
        }
        // Show feet for very short distances
        let feet = meters * 3.28084
        return String(format: "%.0f ft", feet)
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

// MARK: - Overlay Stat View (for map overlay)

struct OverlayStatView: View {
    let value: String
    let label: String
    let icon: String
    var color: Color = .blue

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))

            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
        }
        .frame(width: 68, height: 62)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.9))
        )
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

// MARK: - Track Appearance Settings View

struct TrackAppearanceSettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var trackingSettings = TrackingSettings.default

    // Helper to convert TrackColorOption to SwiftUI Color
    private func colorFor(_ option: TrackColorOption) -> Color {
        let c = option.color
        return Color(red: c.red, green: c.green, blue: c.blue)
    }

    var body: some View {
        Form {
            Section {
                Picker("Color", selection: $trackingSettings.trackAppearance.todayColor) {
                    ForEach(TrackColorOption.allCases, id: \.self) { color in
                        HStack {
                            Circle()
                                .fill(colorFor(color))
                                .frame(width: 20, height: 20)
                            Text(color.rawValue)
                        }
                        .tag(color)
                    }
                }
                .onChange(of: trackingSettings.trackAppearance.todayColor) { _, _ in
                    HapticManager.shared.selectionChanged()
                }

                Picker("Width", selection: $trackingSettings.trackAppearance.todayWidth) {
                    ForEach(TrackWidthOption.allCases, id: \.self) { width in
                        Text(width.displayName).tag(width)
                    }
                }
                .onChange(of: trackingSettings.trackAppearance.todayWidth) { _, _ in
                    HapticManager.shared.selectionChanged()
                }
            } header: {
                Text("Today's Track")
            } footer: {
                Text("Current and today's completed tracking sessions")
            }

            Section {
                Picker("Color", selection: $trackingSettings.trackAppearance.lastWeekColor) {
                    ForEach(TrackColorOption.allCases, id: \.self) { color in
                        HStack {
                            Circle()
                                .fill(colorFor(color))
                                .frame(width: 20, height: 20)
                            Text(color.rawValue)
                        }
                        .tag(color)
                    }
                }
                .onChange(of: trackingSettings.trackAppearance.lastWeekColor) { _, _ in
                    HapticManager.shared.selectionChanged()
                }

                Picker("Width", selection: $trackingSettings.trackAppearance.lastWeekWidth) {
                    ForEach(TrackWidthOption.allCases, id: \.self) { width in
                        Text(width.displayName).tag(width)
                    }
                }
                .onChange(of: trackingSettings.trackAppearance.lastWeekWidth) { _, _ in
                    HapticManager.shared.selectionChanged()
                }
            } header: {
                Text("Last Week's Tracks")
            } footer: {
                Text("Sessions from the past 7 days (excluding today)")
            }

            Section {
                Picker("Color", selection: $trackingSettings.trackAppearance.olderColor) {
                    ForEach(TrackColorOption.allCases, id: \.self) { color in
                        HStack {
                            Circle()
                                .fill(colorFor(color))
                                .frame(width: 20, height: 20)
                            Text(color.rawValue)
                        }
                        .tag(color)
                    }
                }
                .onChange(of: trackingSettings.trackAppearance.olderColor) { _, _ in
                    HapticManager.shared.selectionChanged()
                }

                Picker("Width", selection: $trackingSettings.trackAppearance.olderWidth) {
                    ForEach(TrackWidthOption.allCases, id: \.self) { width in
                        Text(width.displayName).tag(width)
                    }
                }
                .onChange(of: trackingSettings.trackAppearance.olderWidth) { _, _ in
                    HapticManager.shared.selectionChanged()
                }
            } header: {
                Text("Older Tracks")
            } footer: {
                Text("Sessions older than 7 days")
            }

            Section {
                // Preview of track colors
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(colorFor(trackingSettings.trackAppearance.todayColor))
                            .frame(width: 40, height: CGFloat(trackingSettings.trackAppearance.todayWidth.rawValue))
                        Text("Today")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(colorFor(trackingSettings.trackAppearance.lastWeekColor).opacity(0.7))
                            .frame(width: 40, height: CGFloat(trackingSettings.trackAppearance.lastWeekWidth.rawValue))
                        Text("Last Week")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(colorFor(trackingSettings.trackAppearance.olderColor).opacity(0.5))
                            .frame(width: 40, height: CGFloat(trackingSettings.trackAppearance.olderWidth.rawValue))
                        Text("Older")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
            } header: {
                Text("Preview")
            }
        }
        .navigationTitle("Track Appearance")
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
