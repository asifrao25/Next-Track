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
    @StateObject private var iCloudSync = iCloudSyncManager.shared
    @StateObject private var backupManager = FullBackupManager.shared
    @StateObject private var autoBackupManager = AutoExportManager.shared

    @State private var selectedTab = AppTab.centerIndex  // Start on Track tab (index 3)
    @State private var isTracking = false
    @State private var startupCompleted = false
    @State private var showFullMap = false
    @State private var showStopConfirmation = false
    @State private var showRecoveryAlert = false
    @State private var showInterruptedTrackingAlert = false
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var pendingCenterOnLocation = false
    @State private var showICloudPopup = false
    @State private var hasShownICloudPopup = false
    @State private var aboutCreatorExpanded = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // Tab content
            Group {
                switch selectedTab {
                case AppTab.stats.rawValue:
                    StatsHistoryView()
                case AppTab.visited.rawValue:
                    VisitedView()
                case AppTab.track.rawValue:
                    homeTab
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

            // Center map on current location when app loads
            centerMapOnCurrentLocation()
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
        .overlay {
            // iCloud sync popup
            if showICloudPopup {
                iCloudSyncPopupView(isPresented: $showICloudPopup)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    .zIndex(100)
            }
        }
        .onChange(of: iCloudSync.iCloudAvailable) { _, isAvailable in
            // Show popup once if iCloud becomes unavailable and we haven't shown it yet
            if !isAvailable && !hasShownICloudPopup && startupCompleted {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation(.spring(response: 0.4)) {
                        showICloudPopup = true
                        hasShownICloudPopup = true
                    }
                }
            }
        }
        .task {
            // Check iCloud availability after a delay on first launch
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            if !iCloudSync.iCloudAvailable && !hasShownICloudPopup {
                await MainActor.run {
                    withAnimation(.spring(response: 0.4)) {
                        showICloudPopup = true
                        hasShownICloudPopup = true
                    }
                }
            }
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
                            isTracking: isTracking,
                            hasIssues: hasIssues,
                            currentZoneName: geofenceManager.currentZone?.name,
                            accentColor: .green
                        )
                        .padding(.horizontal, 4)

                        Spacer()

                        // Bottom controls (button + stats)
                        trackingOverlay
                            .padding(.bottom, 6)

                        // Quick action pills - frequency on left, geofence on right
                        HStack(spacing: 16) {
                            QuickFrequencyPillView()
                            QuickGeofencePillView()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 78)  // Flush with navbar top edge
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
                // About Creator - Collapsible Section
                Section {
                    // Collapsible Header
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            aboutCreatorExpanded.toggle()
                        }
                        HapticManager.shared.light()
                    } label: {
                        HStack(spacing: 14) {
                            // Creator Photo
                            Image("creator")
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 50, height: 50)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(
                                            LinearGradient(
                                                colors: [.pink, .purple],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 2
                                        )
                                )

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Dr Asif Rao")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("Creator & Developer")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.secondary)
                                .rotationEffect(.degrees(aboutCreatorExpanded ? 90 : 0))
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)

                    // Expanded Content
                    if aboutCreatorExpanded {
                        // Send Feedback
                        Button {
                            if let url = URL(string: "mailto:mail@asifrao.com?subject=Been%20There%20App%20Feedback") {
                                UIApplication.shared.open(url)
                            }
                            HapticManager.shared.light()
                        } label: {
                            HStack {
                                Label("Send Feedback", systemImage: "envelope.fill")
                                Spacer()
                                Text("mail@asifrao.com")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .foregroundColor(.primary)

                        // Buy Me a Coffee (Placeholder)
                        Button {
                            HapticManager.shared.medium()
                            // TODO: Add Buy Me a Coffee link
                        } label: {
                            HStack {
                                Spacer()
                                Image(systemName: "cup.and.saucer.fill")
                                Text("Buy Me a Coffee")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                            .foregroundColor(.black)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(
                                    colors: [Color(red: 1.0, green: 0.87, blue: 0.0), Color(red: 1.0, green: 0.6, blue: 0.0)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                } header: {
                    Label("About the Creator", systemImage: "person.fill")
                }

                // Connection Section
                Section("Connect to Nextcloud Server (optional)") {
                    NavigationLink {
                        ConnectionSettingsView()
                    } label: {
                        Label("Server Settings", systemImage: "server.rack")
                    }
                    .hapticOnTap()
                }

                // iCloud Sync Section
                Section {
                    // iCloud Status Row
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.cyan, .blue],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 44, height: 44)

                            Image(systemName: "icloud.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.white)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("iCloud Sync")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            HStack(spacing: 6) {
                                Circle()
                                    .fill(iCloudSync.isEnabled && iCloudSync.iCloudAvailable ? Color.green : Color.orange)
                                    .frame(width: 8, height: 8)
                                Text(iCloudSync.isEnabled ? (iCloudSync.iCloudAvailable ? "Connected" : "Unavailable") : "Disabled")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        Toggle("", isOn: $iCloudSync.isEnabled)
                            .labelsHidden()
                            .disabled(!iCloudSync.iCloudAvailable)
                    }
                    .padding(.vertical, 4)

                    // Sync Now Button
                    if iCloudSync.isEnabled && iCloudSync.iCloudAvailable {
                        Button {
                            Task { await iCloudSync.syncAllData() }
                            HapticManager.shared.medium()
                        } label: {
                            HStack {
                                if iCloudSync.isSyncing {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Syncing...")
                                } else {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                    Text("Sync Now")
                                }
                                Spacer()
                                if let lastSync = iCloudSync.lastSyncDate {
                                    Text(lastSync, format: .dateTime.month(.abbreviated).day().hour().minute())
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .disabled(iCloudSync.isSyncing)
                    }
                } header: {
                    Label("iCloud", systemImage: "icloud.fill")
                } footer: {
                    Text("Sync your data across all your devices.")
                }

                // Backup & Restore Section
                Section {
                    // Last Backup Info
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.orange, .red],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 44, height: 44)

                            Image(systemName: "externaldrive.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.white)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Local Backup")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            if let lastBackup = autoBackupManager.lastExportDate {
                                Text("Last: \(lastBackup, format: .dateTime.month(.abbreviated).day().hour().minute())")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("No backup yet")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }

                        Spacer()

                        Toggle("", isOn: $autoBackupManager.isEnabled)
                            .labelsHidden()
                    }
                    .padding(.vertical, 4)

                    // Export & Restore Navigation
                    NavigationLink {
                        BackupRestoreView()
                    } label: {
                        Label("Export & Restore", systemImage: "square.and.arrow.up.on.square")
                    }
                    .hapticOnTap()
                } header: {
                    Label("Backup & Restore", systemImage: "externaldrive.fill")
                }

                // Security Section
                Section {
                    NavigationLink {
                        SecuritySettingsView()
                            .environmentObject(settingsManager)
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.teal, .cyan],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 44, height: 44)

                                Image(systemName: "lock.shield.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.white)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("App Lock")
                                    .font(.subheadline)
                                    .fontWeight(.medium)

                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(settingsManager.securitySettings.isEnabled ? Color.green : Color.gray)
                                        .frame(width: 8, height: 8)
                                    Text(settingsManager.securitySettings.isEnabled ?
                                         (settingsManager.securitySettings.lockMethod == .biometric ? "Face ID / Touch ID" : "Passcode") :
                                         "Off")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Label("Security", systemImage: "lock.shield.fill")
                } footer: {
                    Text("Protect your travel data with Face ID, Touch ID, or a passcode.")
                }

                // Tracking Section
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

                // Advanced Section
                Section("Advanced") {
                    NavigationLink {
                        DataSettingsView()
                    } label: {
                        Label("Data Options", systemImage: "antenna.radiowaves.left.and.right")
                    }
                    .hapticOnTap()
                }

                // About Section
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
            if !settingsManager.isConfigured {
                Text("Server not configured - tracking locally only")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
        .buttonStyle(.plain)
        .accessibilityLabel(isTracking ? "Stop tracking" : "Start tracking")
        .accessibilityHint(isTracking ? "Double tap to stop location tracking" : "Double tap to start location tracking")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Tracking Overlay (Button + Stats)

    private var trackingOverlay: some View {
        VStack(spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                // Left stat: Distance (orange)
                OverlayStatView(
                    value: formatDistance(historyManager.todaysDistance),
                    label: "Distance",
                    icon: "figure.walk",
                    color: .orange
                )

                Spacer()

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
                .buttonStyle(.plain)
                .accessibilityLabel("Center on my location")
                .accessibilityHint("Centers the map on your current location")

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
                .buttonStyle(.plain)
                .accessibilityLabel("Expand map")
                .accessibilityHint("Opens the map in full screen mode")

                Spacer()

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

    /// Center map on current location at app startup (no haptic)
    private func centerMapOnCurrentLocation() {
        // Small delay to allow view to initialize
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if let loc = locationManager.currentLocation {
                // Location already available - center immediately
                withAnimation(.easeInOut(duration: 0.5)) {
                    mapPosition = .camera(MapCamera(
                        centerCoordinate: loc.coordinate,
                        distance: 1500,  // Slightly zoomed out for initial view
                        heading: 0,
                        pitch: 0
                    ))
                }
            } else {
                // Request location and center when it arrives
                locationManager.requestSingleLocation()
                pendingCenterOnLocation = true
            }
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

            // Only send to server if configured (server is optional)
            if settingsMgr.isConfigured {
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
            // Check if there are enabled geofences (regardless of monitoring state)
            let enabledZones = geoMgr.zones.filter { $0.isEnabled }
            let hasEnabledZones = !enabledZones.isEmpty

            // Step 1: If there are enabled geofences, ensure monitoring is active and check states
            if hasEnabledZones {
                print("[Startup] Step 1: Found \(enabledZones.count) enabled geofences")

                // Start monitoring if not already active (fixes issue where monitoring state was saved as false)
                if !geoMgr.isMonitoring {
                    print("[Startup] Step 1: Starting geofence monitoring...")
                    geoMgr.startMonitoringAllZones()
                }

                // Wait for zone state check to complete before deciding to auto-start
                print("[Startup] Step 1: Checking current zone states...")
                geoMgr.checkCurrentZoneStates {
                    print("[Startup] Step 1: Geofence state check complete")
                    self.completeStartupSequence()
                }
            } else {
                // No geofences configured - proceed immediately
                print("[Startup] Step 1: No geofences configured - proceeding immediately")
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

        // Step 4: Auto-start tracking (server is optional - tracking works locally)
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
        ScrollView {
            VStack(spacing: 16) {
                // Section header
                HStack {
                    Image(systemName: "timer")
                        .font(.title3)
                        .foregroundColor(.green)
                        .frame(width: 32, height: 32)
                        .background(Color.green.opacity(0.15))
                        .cornerRadius(8)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Update Frequency")
                            .font(.headline)
                        Text("Choose how often to log your location")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 16)

                // Frequency cards - using displayedPresets (5 options)
                ForEach(IntervalPreset.displayedPresets, id: \.self) { preset in
                    FrequencyDetailCard(
                        preset: preset,
                        isSelected: trackingSettings.intervalPreset == preset,
                        isExpanded: trackingSettings.intervalPreset == preset,
                        onSelect: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                trackingSettings.intervalPreset = preset
                            }
                        }
                    )
                    .padding(.horizontal)
                }

                // Custom interval slider (shown when Custom is selected)
                if trackingSettings.intervalPreset == .custom {
                    CustomIntervalSlider(
                        customInterval: $trackingSettings.customIntervalSeconds
                    )
                    .padding(.horizontal)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
                }

                // Footer tip
                footerTip
                    .padding(.horizontal)
                    .padding(.bottom, 100)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Update Frequency")
        .onAppear {
            trackingSettings = settingsManager.trackingSettings
        }
        .onDisappear {
            settingsManager.updateTrackingSettings(trackingSettings)
        }
    }

    private var footerTip: some View {
        HStack(spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .font(.title3)
                .foregroundColor(.yellow)

            Text("Tip: Enable Smart Mode in Battery Settings to automatically reduce frequency when battery is low.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.yellow.opacity(0.1))
        )
    }
}

// MARK: - Frequency Detail Card Components

extension IntervalPreset {
    /// Accent color for the detail card
    var accentColor: Color {
        switch self {
        case .realtime: return .green
        case .high: return .cyan
        case .normal: return .blue
        case .batterySaver: return .orange
        case .extended: return .indigo
        case .minimal: return .purple
        case .custom: return .pink
        }
    }
}

struct PathPreviewShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        // More realistic road-like path with multiple turns
        let h = rect.height
        let w = rect.width

        path.move(to: CGPoint(x: 8, y: h * 0.7))
        path.addLine(to: CGPoint(x: w * 0.15, y: h * 0.7))
        path.addQuadCurve(to: CGPoint(x: w * 0.25, y: h * 0.3), control: CGPoint(x: w * 0.2, y: h * 0.5))
        path.addLine(to: CGPoint(x: w * 0.4, y: h * 0.3))
        path.addQuadCurve(to: CGPoint(x: w * 0.5, y: h * 0.7), control: CGPoint(x: w * 0.45, y: h * 0.5))
        path.addLine(to: CGPoint(x: w * 0.65, y: h * 0.7))
        path.addQuadCurve(to: CGPoint(x: w * 0.8, y: h * 0.35), control: CGPoint(x: w * 0.72, y: h * 0.5))
        path.addLine(to: CGPoint(x: w - 8, y: h * 0.35))

        return path
    }
}

struct PathPreviewView: View {
    let dotCount: Int
    let pathColor: Color
    let isSelected: Bool

    // Deviation amount - more dots = less deviation (smoother path)
    // 12 dots (10s) = nearly 0 deviation, 2 dots (30min) = max deviation
    private var deviationAmount: CGFloat {
        let maxDeviation: CGFloat = 10
        let normalized = CGFloat(12 - dotCount) / 10.0
        return max(0, normalized * maxDeviation)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Ideal path (faint dashed reference line showing actual route)
                PathPreviewShape()
                    .stroke(
                        Color.gray.opacity(0.25),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [4, 4])
                    )

                // Tracked path (straight lines between data points - gets jagged with fewer)
                Path { path in
                    let points = getPathPoints(in: geometry.size)
                    guard let first = points.first else { return }
                    path.move(to: first)
                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                }
                .stroke(
                    pathColor,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                )

                // Data point dots
                ForEach(Array(getPathPoints(in: geometry.size).enumerated()), id: \.offset) { _, point in
                    Circle()
                        .fill(pathColor)
                        .frame(width: 7, height: 7)
                        .shadow(color: pathColor.opacity(0.6), radius: 2)
                        .position(point)
                }
            }
        }
        .frame(height: 55)
    }

    // Sample points along the road-like path
    private func getPathPoints(in size: CGSize) -> [CGPoint] {
        let w = size.width
        let h = size.height

        // Define key waypoints along the road (matching PathPreviewShape)
        let waypoints: [CGPoint] = [
            CGPoint(x: 8, y: h * 0.7),
            CGPoint(x: w * 0.15, y: h * 0.7),
            CGPoint(x: w * 0.2, y: h * 0.5),   // curve control area
            CGPoint(x: w * 0.25, y: h * 0.3),
            CGPoint(x: w * 0.4, y: h * 0.3),
            CGPoint(x: w * 0.45, y: h * 0.5),  // curve control area
            CGPoint(x: w * 0.5, y: h * 0.7),
            CGPoint(x: w * 0.65, y: h * 0.7),
            CGPoint(x: w * 0.72, y: h * 0.5),  // curve control area
            CGPoint(x: w * 0.8, y: h * 0.35),
            CGPoint(x: w - 8, y: h * 0.35)
        ]

        // Sample points based on dotCount
        var result: [CGPoint] = []
        let totalWaypoints = waypoints.count

        for i in 0..<dotCount {
            let t = CGFloat(i) / CGFloat(max(dotCount - 1, 1))
            let waypointIndex = min(Int(t * CGFloat(totalWaypoints - 1)), totalWaypoints - 2)
            let localT = (t * CGFloat(totalWaypoints - 1)) - CGFloat(waypointIndex)

            let p1 = waypoints[waypointIndex]
            let p2 = waypoints[min(waypointIndex + 1, totalWaypoints - 1)]

            // Interpolate between waypoints
            var point = CGPoint(
                x: p1.x + (p2.x - p1.x) * localT,
                y: p1.y + (p2.y - p1.y) * localT
            )

            // Add deviation for middle points (simulates cutting corners with fewer data points)
            if i > 0 && i < dotCount - 1 {
                let seed = Double(i * 7 + 3)
                point.x += sin(seed * 1.3) * deviationAmount
                point.y += cos(seed * 2.1) * deviationAmount * 0.8
                // Keep in bounds
                point.y = max(5, min(h - 5, point.y))
            }

            result.append(point)
        }

        return result
    }
}

struct FrequencyInfoPill: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.primary)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(UIColor.tertiarySystemGroupedBackground))
        )
    }
}

struct FrequencyDetailCard: View {
    let preset: IntervalPreset
    let isSelected: Bool
    let isExpanded: Bool
    let onSelect: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            if isExpanded {
                detailSection
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .shadow(
                    color: isSelected ? preset.accentColor.opacity(0.3) : Color.black.opacity(0.05),
                    radius: isSelected ? 8 : 4,
                    x: 0,
                    y: isSelected ? 4 : 2
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? preset.accentColor : Color.clear, lineWidth: 2)
        )
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isExpanded)
        .onTapGesture {
            HapticManager.shared.selectionChanged()
            onSelect()
        }
    }

    private var headerSection: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(preset.accentColor.opacity(0.3), lineWidth: 2)
                    .frame(width: 24, height: 24)
                if isSelected {
                    Circle()
                        .fill(preset.accentColor)
                        .frame(width: 16, height: 16)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(preset.displayName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                Text(preset == .custom ? "Your interval" : "updates every \(preset.shortName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: preset.batteryIcon)
                    .font(.system(size: 12))
                    .foregroundColor(preset.accentColor)
                Text(preset.batteryImpact)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(preset.accentColor)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(preset.accentColor.opacity(0.15)))
        }
        .padding()
    }

    private var detailSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Divider().padding(.horizontal)
            Text(preset.cardDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                        .font(.caption)
                        .foregroundColor(preset.accentColor)
                    Text("Path Accuracy Preview")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                PathPreviewView(
                    dotCount: preset.dotDensity,
                    pathColor: preset.accentColor,
                    isSelected: isSelected
                )
                .padding(.horizontal)
            }
            HStack(spacing: 12) {
                FrequencyInfoPill(icon: preset.batteryIcon, label: "Battery", value: preset.batteryImpact, color: preset.accentColor)
                FrequencyInfoPill(icon: "chart.line.uptrend.xyaxis", label: "Accuracy", value: preset.accuracyLabel, color: preset.accentColor)
                FrequencyInfoPill(icon: "timer", label: "Interval", value: preset.shortName, color: preset.accentColor)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }
}

struct CustomIntervalSlider: View {
    @Binding var customInterval: TimeInterval

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Custom Interval")
                    .font(.headline)
                Spacer()
                Text(formatInterval(customInterval))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.pink)
            }
            Slider(
                value: Binding(
                    get: { log10(customInterval) },
                    set: { customInterval = pow(10, $0) }
                ),
                in: log10(5)...log10(3600)
            )
            .tint(.pink)
            .onChange(of: customInterval) { _, _ in
                HapticManager.shared.sliderChanged()
            }
            HStack {
                Text("5s").font(.caption).foregroundColor(.secondary)
                Spacer()
                Text("60m").font(.caption).foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
    }

    private func formatInterval(_ seconds: TimeInterval) -> String {
        if seconds < 60 {
            return "\(Int(seconds))s"
        } else if seconds < 3600 {
            let mins = Int(seconds / 60)
            let secs = Int(seconds) % 60
            return secs == 0 ? "\(mins)m" : "\(mins)m \(secs)s"
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
            // Today's Track Section
            Section {
                // Color selection with visual swatches
                VStack(alignment: .leading, spacing: 8) {
                    Text("Color")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                        ForEach(TrackColorOption.allCases, id: \.self) { color in
                            Button {
                                trackingSettings.trackAppearance.todayColor = color
                                HapticManager.shared.selectionChanged()
                            } label: {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(colorFor(color))
                                    .frame(height: 44)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(trackingSettings.trackAppearance.todayColor == color ? Color.white : Color.clear, lineWidth: 3)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(trackingSettings.trackAppearance.todayColor == color ? colorFor(color) : Color.clear, lineWidth: 1)
                                            .padding(2)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.vertical, 4)

                // Width selection with visual line samples
                VStack(alignment: .leading, spacing: 8) {
                    Text("Width")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        ForEach(TrackWidthOption.allCases, id: \.self) { width in
                            Button {
                                trackingSettings.trackAppearance.todayWidth = width
                                HapticManager.shared.selectionChanged()
                            } label: {
                                VStack(spacing: 6) {
                                    RoundedRectangle(cornerRadius: CGFloat(width.rawValue) / 2)
                                        .fill(colorFor(trackingSettings.trackAppearance.todayColor))
                                        .frame(width: 50, height: CGFloat(width.rawValue))

                                    Text("\(width.rawValue)pt")
                                        .font(.caption2)
                                        .foregroundColor(trackingSettings.trackAppearance.todayWidth == width ? .primary : .secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(trackingSettings.trackAppearance.todayWidth == width ? Color(.systemGray5) : Color.clear)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Today's Track")
            } footer: {
                Text("Current and today's completed sessions")
            }

            // Last Week's Tracks Section
            Section {
                // Color selection with visual swatches
                VStack(alignment: .leading, spacing: 8) {
                    Text("Color")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                        ForEach(TrackColorOption.allCases, id: \.self) { color in
                            Button {
                                trackingSettings.trackAppearance.lastWeekColor = color
                                HapticManager.shared.selectionChanged()
                            } label: {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(colorFor(color))
                                    .frame(height: 44)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(trackingSettings.trackAppearance.lastWeekColor == color ? Color.white : Color.clear, lineWidth: 3)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(trackingSettings.trackAppearance.lastWeekColor == color ? colorFor(color) : Color.clear, lineWidth: 1)
                                            .padding(2)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.vertical, 4)

                // Width selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Width")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        ForEach(TrackWidthOption.allCases, id: \.self) { width in
                            Button {
                                trackingSettings.trackAppearance.lastWeekWidth = width
                                HapticManager.shared.selectionChanged()
                            } label: {
                                VStack(spacing: 6) {
                                    RoundedRectangle(cornerRadius: CGFloat(width.rawValue) / 2)
                                        .fill(colorFor(trackingSettings.trackAppearance.lastWeekColor))
                                        .frame(width: 50, height: CGFloat(width.rawValue))

                                    Text("\(width.rawValue)pt")
                                        .font(.caption2)
                                        .foregroundColor(trackingSettings.trackAppearance.lastWeekWidth == width ? .primary : .secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(trackingSettings.trackAppearance.lastWeekWidth == width ? Color(.systemGray5) : Color.clear)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Last Week's Tracks")
            } footer: {
                Text("Sessions from the past 7 days (excluding today)")
            }

            // Older Tracks Section
            Section {
                // Color selection with visual swatches
                VStack(alignment: .leading, spacing: 8) {
                    Text("Color")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                        ForEach(TrackColorOption.allCases, id: \.self) { color in
                            Button {
                                trackingSettings.trackAppearance.olderColor = color
                                HapticManager.shared.selectionChanged()
                            } label: {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(colorFor(color))
                                    .frame(height: 44)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(trackingSettings.trackAppearance.olderColor == color ? Color.white : Color.clear, lineWidth: 3)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(trackingSettings.trackAppearance.olderColor == color ? colorFor(color) : Color.clear, lineWidth: 1)
                                            .padding(2)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.vertical, 4)

                // Width selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Width")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        ForEach(TrackWidthOption.allCases, id: \.self) { width in
                            Button {
                                trackingSettings.trackAppearance.olderWidth = width
                                HapticManager.shared.selectionChanged()
                            } label: {
                                VStack(spacing: 6) {
                                    RoundedRectangle(cornerRadius: CGFloat(width.rawValue) / 2)
                                        .fill(colorFor(trackingSettings.trackAppearance.olderColor))
                                        .frame(width: 50, height: CGFloat(width.rawValue))

                                    Text("\(width.rawValue)pt")
                                        .font(.caption2)
                                        .foregroundColor(trackingSettings.trackAppearance.olderWidth == width ? .primary : .secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(trackingSettings.trackAppearance.olderWidth == width ? Color(.systemGray5) : Color.clear)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Older Tracks")
            } footer: {
                Text("Sessions older than 7 days")
            }

            // Live Preview Section
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    // Today preview
                    HStack(spacing: 12) {
                        ZStack {
                            // Wavy line effect
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: 15))
                                path.addCurve(
                                    to: CGPoint(x: 80, y: 15),
                                    control1: CGPoint(x: 20, y: 5),
                                    control2: CGPoint(x: 60, y: 25)
                                )
                            }
                            .stroke(
                                colorFor(trackingSettings.trackAppearance.todayColor),
                                style: StrokeStyle(lineWidth: CGFloat(trackingSettings.trackAppearance.todayWidth.rawValue), lineCap: .round)
                            )
                        }
                        .frame(width: 80, height: 30)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Today")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("Full opacity")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Last week preview
                    HStack(spacing: 12) {
                        ZStack {
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: 15))
                                path.addCurve(
                                    to: CGPoint(x: 80, y: 15),
                                    control1: CGPoint(x: 20, y: 5),
                                    control2: CGPoint(x: 60, y: 25)
                                )
                            }
                            .stroke(
                                colorFor(trackingSettings.trackAppearance.lastWeekColor).opacity(0.7),
                                style: StrokeStyle(lineWidth: CGFloat(trackingSettings.trackAppearance.lastWeekWidth.rawValue), lineCap: .round)
                            )
                        }
                        .frame(width: 80, height: 30)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Last Week")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("70% opacity")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Older preview
                    HStack(spacing: 12) {
                        ZStack {
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: 15))
                                path.addCurve(
                                    to: CGPoint(x: 80, y: 15),
                                    control1: CGPoint(x: 20, y: 5),
                                    control2: CGPoint(x: 60, y: 25)
                                )
                            }
                            .stroke(
                                colorFor(trackingSettings.trackAppearance.olderColor).opacity(0.5),
                                style: StrokeStyle(lineWidth: CGFloat(trackingSettings.trackAppearance.olderWidth.rawValue), lineCap: .round)
                            )
                        }
                        .frame(width: 80, height: 30)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Older")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("50% opacity")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 8)
            } header: {
                Text("Live Preview")
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
