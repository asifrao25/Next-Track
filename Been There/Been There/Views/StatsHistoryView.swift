//
//  StatsHistoryView.swift
//  Next-track
//
//  Detailed statistics and tracking history
//

import SwiftUI
import UniformTypeIdentifiers
import MapKit

// Wrapper to make URL identifiable for sheet presentation
struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

struct StatsHistoryView: View {
    @StateObject private var historyManager = TrackingHistoryManager.shared
    @StateObject private var connectionMonitor = ConnectionMonitor.shared
    @StateObject private var batteryMonitor = BatteryMonitor.shared
    @StateObject private var geofenceManager = GeofenceManager.shared
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var phoneTrackAPI: PhoneTrackAPI
    @EnvironmentObject var locationManager: LocationManager

    @State private var selectedTimeRange: TimeRange = .today
    @State private var showClearConfirmation = false
    @State private var showFinalClearConfirmation = false
    @State private var exportItem: IdentifiableURL?
    @State private var showImportPicker = false
    @State private var importError: String?
    @State private var showImportError = false
    @State private var showSessionsList = false
    @State private var showDailyStats = false

    enum TimeRange: String, CaseIterable {
        case today = "Today"
        case week = "Week"
        case allTime = "All Time"
    }

    // Helper to map PhoneTrackAPI connection status to our enum
    private var mapConnectionStatus: ConnectionStatusType {
        switch phoneTrackAPI.connectionStatus {
        case .connected: return .connected
        case .disconnected: return .disconnected
        case .error: return .error
        case .unknown: return .unknown
        }
    }

    private var hasIssues: Bool {
        phoneTrackAPI.connectionStatus == .error ||
        phoneTrackAPI.connectionStatus == .disconnected ||
        PendingLocationQueue.shared.count > 0 ||
        !settingsManager.isConfigured
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // Scrollable content
                ScrollView {
                    VStack(spacing: 24) {
                        // Spacer for fixed header
                        Color.clear.frame(height: 130)

                        // Time Range Picker
                        timeRangePicker

                        // Hero Stats Grid
                        heroStatsGrid

                        // Quick Stats Row
                        quickStatsRow

                        // Daily Records Section
                        dailyStatsSection

                        // Sessions Section
                        sessionsSection

                        // Export/Import Section
                        dataManagementSection
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 120)
                }
                .background(Color(.systemGroupedBackground))

                // Fixed header at top
                VStack(spacing: 0) {
                    CustomTitleHeaderView(
                        connectionMonitor: connectionMonitor,
                        batteryMonitor: batteryMonitor,
                        isTracking: TrackingStateManager.shared.isTracking,
                        hasIssues: hasIssues,
                        pendingCount: PendingLocationQueue.shared.count,
                        currentZoneName: geofenceManager.currentZone?.name,
                        connectionStatus: mapConnectionStatus,
                        lastSuccessfulSend: settingsManager.trackingStats.lastSuccessfulSend,
                        todayMiles: historyManager.todaysDistance / 1609.344,
                        sessionDuration: historyManager.currentSession?.duration ?? 0,
                        pointsSent: settingsManager.trackingStats.pointsSentToday,
                        currentElevation: locationManager.currentLocation?.altitude,
                        accentColor: .purple
                    )
                    .padding(.horizontal, 4)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .alert("Clear All History?", isPresented: $showClearConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Continue", role: .destructive) {
                    showFinalClearConfirmation = true
                }
            } message: {
                Text("This will permanently delete all tracking history including sessions, daily records, and statistics.")
            }
            .alert("Are You Absolutely Sure?", isPresented: $showFinalClearConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete Everything", role: .destructive) {
                    historyManager.clearAllHistory()
                }
            } message: {
                Text("This action CANNOT be undone. All your tracking data will be permanently erased.")
            }
            .alert("Import Error", isPresented: $showImportError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importError ?? "Failed to import data")
            }
            .sheet(item: $exportItem) { item in
                ShareSheet(activityItems: [item.url])
            }
            .fileImporter(
                isPresented: $showImportPicker,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result)
            }
        }
    }

    // MARK: - Time Range Picker

    private var timeRangePicker: some View {
        HStack(spacing: 12) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTimeRange = range
                    }
                } label: {
                    Text(range.rawValue)
                        .font(.subheadline)
                        .fontWeight(selectedTimeRange == range ? .semibold : .medium)
                        .foregroundColor(selectedTimeRange == range ? .white : .secondary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            Group {
                                if selectedTimeRange == range {
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [.blue, .blue.opacity(0.8)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .shadow(color: .blue.opacity(0.3), radius: 4, x: 0, y: 2)
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Hero Stats Grid

    private var heroStatsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 12) {
            // Distance Card - Large
            HeroStatCard(
                title: "Distance",
                value: formatDistance(distanceForRange),
                subtitle: selectedTimeRange == .today ? "traveled today" : selectedTimeRange == .week ? "this week" : "total",
                icon: "figure.walk",
                gradient: [Color.blue, Color.cyan]
            )

            // Sessions Card - Large
            HeroStatCard(
                title: "Sessions",
                value: "\(sessionsForRange)",
                subtitle: selectedTimeRange == .today ? "today" : selectedTimeRange == .week ? "this week" : "total",
                icon: "clock.fill",
                gradient: [Color.orange, Color.yellow]
            )

            // Points Card - Large
            HeroStatCard(
                title: "Points",
                value: formatLargeNumber(pointsForRange),
                subtitle: "locations tracked",
                icon: "mappin.and.ellipse",
                gradient: [Color.green, Color.mint]
            )

            // Duration Card - Large
            HeroStatCard(
                title: "Duration",
                value: formatDuration(durationForRange),
                subtitle: "time tracking",
                icon: "timer",
                gradient: [Color.purple, Color.pink]
            )
        }
        .padding(.horizontal)
    }

    // MARK: - Quick Stats Row

    private var quickStatsRow: some View {
        HStack(spacing: 12) {
            QuickStatPill(
                label: "Avg/Session",
                value: formatDistance(averageDistancePerSession),
                icon: "arrow.left.arrow.right"
            )

            QuickStatPill(
                label: "Days Active",
                value: "\(totalUniqueDays)",
                icon: "calendar"
            )

            QuickStatPill(
                label: "Avg Speed",
                value: formatSpeed(averageSpeed),
                icon: "speedometer"
            )
        }
        .padding(.horizontal)
    }

    // MARK: - Daily Stats Section

    private var dailyStatsSection: some View {
        VStack(spacing: 0) {
            // Section header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showDailyStats.toggle()
                }
            } label: {
                HStack {
                    HStack(spacing: 10) {
                        Image(systemName: "calendar")
                            .font(.title3)
                            .foregroundColor(.blue)
                            .frame(width: 32, height: 32)
                            .background(Color.blue.opacity(0.15))
                            .cornerRadius(8)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Daily Records")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("\(totalUniqueDays) days tracked")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(showDailyStats ? 90 : 0))
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(16)
            }
            .buttonStyle(.plain)
            .padding(.horizontal)

            // Expanded daily stats
            if showDailyStats {
                if historyManager.dailyStats.isEmpty {
                    emptyStateView(
                        icon: "calendar.badge.clock",
                        title: "No tracking history yet",
                        subtitle: "Start tracking to see daily summaries"
                    )
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(historyManager.dailyStats) { daily in
                            DailyStatsRowView(
                                dailyStats: daily,
                                onOpenInMaps: { openDayInMaps(daily) },
                                onShareGPX: { shareDayGPX(daily) },
                                onDeleteSession: { session in
                                    historyManager.deleteSession(session)
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
            }
        }
    }

    // MARK: - Sessions Section

    private var sessionsSection: some View {
        VStack(spacing: 0) {
            // Section header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showSessionsList.toggle()
                }
            } label: {
                HStack {
                    HStack(spacing: 10) {
                        Image(systemName: "list.bullet.rectangle.fill")
                            .font(.title3)
                            .foregroundColor(.orange)
                            .frame(width: 32, height: 32)
                            .background(Color.orange.opacity(0.15))
                            .cornerRadius(8)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sessions")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("\(historyManager.sessions.count) total sessions")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(showSessionsList ? 90 : 0))
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(16)
            }
            .buttonStyle(.plain)
            .padding(.horizontal)

            // Expanded sessions list
            if showSessionsList && !historyManager.sessions.isEmpty {
                LazyVStack(spacing: 8) {
                    ForEach(sessionsToShow) { session in
                        SessionRowView(
                            session: session,
                            onDelete: {
                                historyManager.deleteSession(session)
                            },
                            onExport: { session in
                                exportSessionToGPX(session)
                            }
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
        }
    }

    // MARK: - Data Management Section

    private var dataManagementSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "square.and.arrow.up.on.square")
                    .font(.title3)
                    .foregroundColor(.indigo)
                    .frame(width: 32, height: 32)
                    .background(Color.indigo.opacity(0.15))
                    .cornerRadius(8)

                Text("Data Management")
                    .font(.headline)

                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)

            HStack(spacing: 12) {
                // Export GPX Button
                Button {
                    exportAllToGPX()
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "map")
                            .font(.title2)
                        Text("Export GPX")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)

                // Export JSON Button
                Button {
                    exportAllToJSON()
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "doc.text")
                            .font(.title2)
                        Text("Export JSON")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)

                // Import Button
                Button {
                    showImportPicker = true
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.title2)
                        Text("Import")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)

            // Clear All Button
            Button {
                showClearConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Clear All History")
                }
                .font(.subheadline)
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    // MARK: - Empty State View

    private func emptyStateView(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.6))

            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)

            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Export Functions

    private func exportAllToGPX() {
        let gpxContent = historyManager.exportAllSessionsToGPX()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let filename = "BeenThere-Export-\(dateFormatter.string(from: Date())).gpx"

        if let url = historyManager.saveGPXFile(content: gpxContent, filename: filename) {
            exportItem = IdentifiableURL(url: url)
        }
    }

    private func exportAllToJSON() {
        guard let jsonData = historyManager.exportAllSessionsToJSON() else { return }
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let filename = "BeenThere-Backup-\(dateFormatter.string(from: Date())).json"

        if let url = historyManager.saveJSONFile(data: jsonData, filename: filename) {
            exportItem = IdentifiableURL(url: url)
        }
    }

    private func exportSessionToGPX(_ session: TrackingSession) {
        let gpxContent = historyManager.exportSessionToGPX(session)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-HHmm"
        let filename = "BeenThere-\(dateFormatter.string(from: session.startTime)).gpx"

        if let url = historyManager.saveGPXFile(content: gpxContent, filename: filename) {
            exportItem = IdentifiableURL(url: url)
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            guard url.startAccessingSecurityScopedResource() else {
                importError = "Cannot access the selected file"
                showImportError = true
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let data = try Data(contentsOf: url)
                if historyManager.importSessionsFromJSON(data) {
                    // Success
                } else {
                    importError = "Invalid file format. Please select a valid Been There backup file."
                    showImportError = true
                }
            } catch {
                importError = "Failed to read file: \(error.localizedDescription)"
                showImportError = true
            }

        case .failure(let error):
            importError = error.localizedDescription
            showImportError = true
        }
    }

    private func openDayInMaps(_ dailyStats: DailyStats) {
        let locations = dailyStats.allLocations
        guard !locations.isEmpty else { return }

        var mapItems: [MKMapItem] = []

        if let first = locations.first {
            let startCoord = CLLocationCoordinate2D(latitude: first.latitude, longitude: first.longitude)
            let startItem = MKMapItem(placemark: MKPlacemark(coordinate: startCoord))
            startItem.name = "Start"
            mapItems.append(startItem)
        }

        if let last = locations.last, locations.count > 1 {
            let endCoord = CLLocationCoordinate2D(latitude: last.latitude, longitude: last.longitude)
            let endItem = MKMapItem(placemark: MKPlacemark(coordinate: endCoord))
            endItem.name = "End"
            mapItems.append(endItem)
        }

        MKMapItem.openMaps(with: mapItems, launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
        ])
    }

    private func shareDayGPX(_ dailyStats: DailyStats) {
        let gpxContent = historyManager.exportDayToGPX(dailyStats)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let filename = "BeenThere-\(dateFormatter.string(from: dailyStats.date)).gpx"

        if let url = historyManager.saveGPXFile(content: gpxContent, filename: filename) {
            exportItem = IdentifiableURL(url: url)
        }
    }

    // MARK: - Computed Properties

    private var distanceForRange: Double {
        switch selectedTimeRange {
        case .today: return historyManager.todaysDistance
        case .week: return historyManager.thisWeeksDistance
        case .allTime: return historyManager.totalDistanceAllTime
        }
    }

    private var pointsForRange: Int {
        switch selectedTimeRange {
        case .today: return historyManager.todaysPoints
        case .week: return historyManager.thisWeeksSessions.reduce(0) { $0 + $1.pointsCount }
        case .allTime: return historyManager.totalPointsAllTime
        }
    }

    private var sessionsForRange: Int {
        switch selectedTimeRange {
        case .today: return historyManager.todaysSessions.count
        case .week: return historyManager.thisWeeksSessions.count
        case .allTime: return historyManager.totalSessions
        }
    }

    private var durationForRange: TimeInterval {
        switch selectedTimeRange {
        case .today: return historyManager.todaysSessions.reduce(0) { $0 + $1.duration }
        case .week: return historyManager.thisWeeksSessions.reduce(0) { $0 + $1.duration }
        case .allTime: return historyManager.totalDurationAllTime
        }
    }

    private var sessionsToShow: [TrackingSession] {
        switch selectedTimeRange {
        case .today: return historyManager.todaysSessions
        case .week: return historyManager.thisWeeksSessions
        case .allTime: return Array(historyManager.sessions.prefix(20))
        }
    }

    private var totalUniqueDays: Int {
        historyManager.dailyStats.count
    }

    private var averageDistancePerSession: Double {
        guard sessionsForRange > 0 else { return 0 }
        return distanceForRange / Double(sessionsForRange)
    }

    private var averageSpeed: Double {
        guard durationForRange > 0 else { return 0 }
        // meters per second to mph
        let metersPerSecond = distanceForRange / durationForRange
        return metersPerSecond * 2.23694
    }

    // MARK: - Formatters

    private func formatDistance(_ meters: Double) -> String {
        let miles = meters / 1609.344
        if miles >= 100 {
            return String(format: "%.0f mi", miles)
        } else if miles >= 10 {
            return String(format: "%.1f mi", miles)
        } else if miles >= 0.1 {
            return String(format: "%.2f mi", miles)
        }
        let feet = meters * 3.28084
        return String(format: "%.0f ft", feet)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    private func formatLargeNumber(_ number: Int) -> String {
        if number >= 1000000 {
            return String(format: "%.1fM", Double(number) / 1000000)
        } else if number >= 1000 {
            return String(format: "%.1fK", Double(number) / 1000)
        }
        return "\(number)"
    }

    private func formatSpeed(_ mph: Double) -> String {
        return String(format: "%.1f mph", mph)
    }
}

// MARK: - Hero Stat Card

struct HeroStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let gradient: [Color]

    @State private var isAnimating = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                animatedIcon
                Spacer()
            }

            Spacer()

            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.9))

            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding()
        .frame(height: 140)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: gradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .shadow(color: gradient.first?.opacity(0.3) ?? .clear, radius: 8, x: 0, y: 4)
        .onAppear {
            isAnimating = true
        }
    }

    @ViewBuilder
    private var animatedIcon: some View {
        Image(systemName: icon)
            .font(.title2)
            .foregroundColor(.white.opacity(0.9))
            .symbolEffect(.variableColor.iterative.reversing, options: .repeating, value: isAnimating)
    }
}

// MARK: - Quick Stat Pill

struct QuickStatPill: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - Stat Card Large (kept for compatibility)

struct StatCardLarge: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }

            Text(value)
                .font(.title)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Session Row View

struct SessionRowView: View {
    let session: TrackingSession
    let onDelete: () -> Void
    let onExport: (TrackingSession) -> Void

    @State private var isExpanded = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            // Header (always visible)
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(session.startTime, style: .date)
                            .font(.headline)
                            .foregroundColor(.primary)

                        if session.isActive {
                            Text("LIVE")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green)
                                .cornerRadius(4)
                        }
                    }

                    HStack(spacing: 12) {
                        Label(session.formattedDuration, systemImage: "clock")
                        Label(session.formattedDistance, systemImage: "figure.walk")
                        Label("\(session.pointsCount) pts", systemImage: "mappin")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .padding()
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }

            // Expanded details
            if isExpanded {
                Divider()
                    .padding(.horizontal)

                VStack(spacing: 16) {
                    // Time details
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Started")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(session.startTime, style: .time)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Ended")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if let endTime = session.endTime {
                                Text(endTime, style: .time)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            } else {
                                Text("In Progress")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.green)
                            }
                        }
                    }

                    // Stats grid
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        SessionStatItem(
                            title: "Duration",
                            value: session.formattedDuration,
                            icon: "clock.fill",
                            color: .blue
                        )

                        SessionStatItem(
                            title: "Distance",
                            value: session.formattedDistance,
                            icon: "figure.walk",
                            color: .green
                        )

                        SessionStatItem(
                            title: "Points",
                            value: "\(session.pointsCount)",
                            icon: "mappin.circle.fill",
                            color: .orange
                        )

                        SessionStatItem(
                            title: "Avg Speed",
                            value: session.formattedAverageSpeed,
                            icon: "speedometer",
                            color: .purple
                        )

                        if let maxAlt = session.maxAltitude {
                            SessionStatItem(
                                title: "Max Alt",
                                value: String(format: "%.0f m", maxAlt),
                                icon: "mountain.2.fill",
                                color: .teal
                            )
                        } else {
                            SessionStatItem(
                                title: "Max Alt",
                                value: "--",
                                icon: "mountain.2.fill",
                                color: .gray
                            )
                        }

                        if let avgAccuracy = session.averageAccuracy {
                            SessionStatItem(
                                title: "Accuracy",
                                value: String(format: "%.0f m", avgAccuracy),
                                icon: "scope",
                                color: .indigo
                            )
                        } else {
                            SessionStatItem(
                                title: "Accuracy",
                                value: "--",
                                icon: "scope",
                                color: .gray
                            )
                        }
                    }

                    // Action buttons
                    HStack(spacing: 12) {
                        Button {
                            onExport(session)
                        } label: {
                            Label("Export GPX", systemImage: "square.and.arrow.up")
                                .font(.subheadline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.blue)

                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                                .font(.subheadline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                }
                .padding()
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .alert("Delete Session?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("This will permanently delete this tracking session and all its data.")
        }
    }
}

// MARK: - Session Stat Item

struct SessionStatItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)

            Text(value)
                .font(.caption)
                .fontWeight(.semibold)

            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Daily Stats Row View

struct DailyStatsRowView: View {
    let dailyStats: DailyStats
    let onOpenInMaps: () -> Void
    let onShareGPX: () -> Void
    let onDeleteSession: (TrackingSession) -> Void

    @State private var isExpanded = false
    @State private var sessionToDelete: TrackingSession?
    @State private var showDeleteConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            // Header - always visible
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(dailyStats.shortFormattedDate)
                        .font(.headline)
                        .foregroundColor(.primary)

                    HStack(spacing: 12) {
                        Label("\(dailyStats.sessionCount) sessions", systemImage: "clock")
                        Label(dailyStats.formattedDistance, systemImage: "figure.walk")
                        Label(dailyStats.formattedDuration, systemImage: "timer")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .padding()
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }

            // Expanded details
            if isExpanded {
                Divider()
                    .padding(.horizontal)

                VStack(spacing: 16) {
                    // Stats grid
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        SessionStatItem(
                            title: "Sessions",
                            value: "\(dailyStats.sessionCount)",
                            icon: "clock.fill",
                            color: .blue
                        )

                        SessionStatItem(
                            title: "Distance",
                            value: dailyStats.formattedDistance,
                            icon: "figure.walk",
                            color: .green
                        )

                        SessionStatItem(
                            title: "Duration",
                            value: dailyStats.formattedDuration,
                            icon: "timer",
                            color: .orange
                        )

                        SessionStatItem(
                            title: "Points",
                            value: "\(dailyStats.totalPoints)",
                            icon: "mappin.circle.fill",
                            color: .purple
                        )

                        SessionStatItem(
                            title: "Avg Speed",
                            value: dailyStats.formattedAverageSpeed,
                            icon: "speedometer",
                            color: .teal
                        )

                        SessionStatItem(
                            title: "Date",
                            value: "",
                            icon: "calendar",
                            color: .gray
                        )
                    }

                    // Full date
                    Text(dailyStats.formattedDate)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // Individual sessions list
                    if !dailyStats.sessions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Sessions")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)

                            ForEach(dailyStats.sessions) { session in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack {
                                            Text(session.startTime, style: .time)
                                                .font(.subheadline)
                                                .fontWeight(.medium)

                                            if session.isActive {
                                                Text("LIVE")
                                                    .font(.caption2)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.white)
                                                    .padding(.horizontal, 4)
                                                    .padding(.vertical, 1)
                                                    .background(Color.green)
                                                    .cornerRadius(3)
                                            }
                                        }

                                        HStack(spacing: 8) {
                                            Text(session.formattedDuration)
                                            Text("•")
                                            Text(session.formattedDistance)
                                            Text("•")
                                            Text("\(session.pointsCount) pts")
                                        }
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    // Delete button
                                    Button {
                                        sessionToDelete = session
                                        showDeleteConfirmation = true
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.subheadline)
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(session.isActive)
                                    .opacity(session.isActive ? 0.3 : 1.0)
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(Color(.systemBackground))
                                .cornerRadius(8)
                            }
                        }
                    }

                    // Action buttons
                    HStack(spacing: 12) {
                        Button {
                            onOpenInMaps()
                        } label: {
                            Label("Open in Maps", systemImage: "map")
                                .font(.subheadline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.blue)

                        Button {
                            onShareGPX()
                        } label: {
                            Label("Share GPX", systemImage: "square.and.arrow.up")
                                .font(.subheadline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.green)
                    }
                }
                .padding()
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .alert("Delete Session?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                sessionToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let session = sessionToDelete {
                    onDeleteSession(session)
                }
                sessionToDelete = nil
            }
        } message: {
            if let session = sessionToDelete {
                Text("Delete session from \(session.startTime, style: .time) with \(session.pointsCount) points?")
            } else {
                Text("This will permanently delete this session.")
            }
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    StatsHistoryView()
}
