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
    @StateObject private var autoExportManager = AutoExportManager.shared
    @State private var selectedTimeRange: TimeRange = .today
    @State private var showClearConfirmation = false
    @State private var exportItem: IdentifiableURL?  // Changed to use identifiable wrapper
    @State private var showImportPicker = false
    @State private var importError: String?
    @State private var showImportError = false
    @State private var showFolderPicker = false
    @State private var showSessionsList = false  // Collapsed by default
    @State private var showDailyStats = false     // Collapsed by default

    enum TimeRange: String, CaseIterable {
        case today = "Today"
        case week = "This Week"
        case allTime = "All Time"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Time Range Picker
                    Picker("Time Range", selection: $selectedTimeRange) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Stats Cards
                    statsCards

                    // Pending Locations
                    pendingLocationsCard

                    // Connection Status
                    connectionStatusCard

                    // Auto Export Settings
                    autoExportCard

                    // Daily Stats (collapsed by day)
                    dailyStatsSection

                    // Sessions (collapsed by default)
                    sessionsSection
                }
                .padding(.vertical)
                .padding(.bottom, 100) // Space for tab bar
            }
            .navigationTitle("Stats & History")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        // Export options
                        Menu {
                            Button {
                                exportAllToGPX()
                            } label: {
                                Label("Export as GPX (for Maps)", systemImage: "map")
                            }

                            Button {
                                exportAllToJSON()
                            } label: {
                                Label("Export as JSON (Backup)", systemImage: "doc.text")
                            }
                        } label: {
                            Label("Export All Data", systemImage: "square.and.arrow.up")
                        }

                        Button {
                            showImportPicker = true
                        } label: {
                            Label("Import Data", systemImage: "square.and.arrow.down")
                        }

                        Divider()

                        Button(role: .destructive) {
                            showClearConfirmation = true
                        } label: {
                            Label("Clear History", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .alert("Clear All History?", isPresented: $showClearConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) {
                    historyManager.clearAllHistory()
                }
            } message: {
                Text("This will permanently delete all tracking history. This action cannot be undone.")
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
            .fileImporter(
                isPresented: $showFolderPicker,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false
            ) { result in
                handleFolderSelection(result)
            }
        }
    }

    // MARK: - Auto Export Card

    private var autoExportCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(.blue)
                Text("Auto Export")
                    .font(.headline)
                Spacer()
            }

            Toggle("Export daily at midnight", isOn: $autoExportManager.isEnabled)
                .disabled(autoExportManager.exportFolderURL == nil)

            // Folder selection
            Button {
                showFolderPicker = true
            } label: {
                HStack {
                    Image(systemName: "folder")
                    if let folderURL = autoExportManager.exportFolderURL {
                        Text(folderURL.lastPathComponent)
                            .lineLimit(1)
                    } else {
                        Text("Select export folder")
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.bordered)
            .tint(autoExportManager.exportFolderURL != nil ? .green : .blue)

            // Last export info
            if let lastExport = autoExportManager.lastExportDate {
                HStack {
                    Text("Last export:")
                        .foregroundColor(.secondary)
                    Text(lastExport, style: .relative)
                    Text("ago")
                        .foregroundColor(.secondary)
                }
                .font(.caption)

                if !autoExportManager.lastExportStatus.isEmpty {
                    Text(autoExportManager.lastExportStatus)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Manual export button - exports today's sessions
            Button {
                autoExportManager.performDailyExport(forToday: true)
            } label: {
                Label("Export Today", systemImage: "square.and.arrow.up")
                    .font(.subheadline)
            }
            .buttonStyle(.bordered)
            .disabled(autoExportManager.exportFolderURL == nil)

            // Info text
            Text("Auto-exports previous day's data at midnight. 'Export Today' saves current day's sessions.")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private func handleFolderSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                autoExportManager.setExportFolder(url)
            }
        case .failure(let error):
            print("[StatsHistory] Folder selection failed: \(error)")
        }
    }

    // MARK: - Export Functions

    private func exportAllToGPX() {
        let gpxContent = historyManager.exportAllSessionsToGPX()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let filename = "NextTrack-Export-\(dateFormatter.string(from: Date())).gpx"

        if let url = historyManager.saveGPXFile(content: gpxContent, filename: filename) {
            exportItem = IdentifiableURL(url: url)
        }
    }

    private func exportAllToJSON() {
        guard let jsonData = historyManager.exportAllSessionsToJSON() else { return }
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let filename = "NextTrack-Backup-\(dateFormatter.string(from: Date())).json"

        if let url = historyManager.saveJSONFile(data: jsonData, filename: filename) {
            exportItem = IdentifiableURL(url: url)
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            // Start accessing security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                importError = "Cannot access the selected file"
                showImportError = true
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let data = try Data(contentsOf: url)
                if historyManager.importSessionsFromJSON(data) {
                    // Success - no need to show anything
                } else {
                    importError = "Invalid file format. Please select a valid Next Track backup file."
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

    // MARK: - Stats Cards

    private var statsCards: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                StatCardLarge(
                    title: "Distance",
                    value: formatDistance(distanceForRange),
                    icon: "figure.walk",
                    color: .blue
                )

                StatCardLarge(
                    title: "Points Sent",
                    value: "\(pointsForRange)",
                    icon: "mappin.and.ellipse",
                    color: .green
                )
            }

            HStack(spacing: 12) {
                StatCardLarge(
                    title: "Sessions",
                    value: "\(sessionsForRange)",
                    icon: "clock.fill",
                    color: .orange
                )

                StatCardLarge(
                    title: "Duration",
                    value: formatDuration(durationForRange),
                    icon: "timer",
                    color: .purple
                )
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Pending Locations Card

    private var pendingLocationsCard: some View {
        let pendingCount = PendingLocationQueue.shared.count

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "tray.full.fill")
                    .foregroundColor(pendingCount > 0 ? .orange : .green)
                Text("Pending Locations")
                    .font(.headline)
                Spacer()
                Text("\(pendingCount)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(pendingCount > 0 ? .orange : .green)
            }

            if pendingCount > 0 {
                Text("These locations will be sent when connection is restored")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button("Retry Now") {
                    PhoneTrackAPI.shared.sendPendingLocations()
                }
                .buttonStyle(.bordered)
                .tint(.orange)
            } else {
                Text("All locations have been sent successfully")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    // MARK: - Connection Status Card

    private var connectionStatusCard: some View {
        let connectionMonitor = ConnectionMonitor.shared

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: connectionMonitor.isConnected ? "wifi" : "wifi.slash")
                    .foregroundColor(connectionMonitor.isConnected ? .green : .red)
                Text("Connection Status")
                    .font(.headline)
                Spacer()
                Text(connectionMonitor.connectionType.rawValue)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            HStack {
                if let lastSuccess = connectionMonitor.lastSuccessfulConnection {
                    Text("Last sync: ")
                        .foregroundColor(.secondary)
                    Text(lastSuccess, style: .relative)
                    Text(" ago")
                        .foregroundColor(.secondary)
                } else {
                    Text("No successful sync yet")
                        .foregroundColor(.secondary)
                }
            }
            .font(.caption)

            if let _ = connectionMonitor.disconnectedSince {
                Text(connectionMonitor.statusDescription)
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    // MARK: - Daily Stats Section (Collapsible)

    private var dailyStatsSection: some View {
        VStack(spacing: 0) {
            // Collapsible header
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.blue)
                Text("Daily Records")
                    .font(.headline)
                // Always show total count - not filtered
                Text("(\(totalUniqueDays) \(totalUniqueDays == 1 ? "day" : "days"))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .rotationEffect(.degrees(showDailyStats ? 90 : 0))
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showDailyStats.toggle()
                }
            }
            .padding(.horizontal)

            // Expanded daily stats list
            if showDailyStats {
                if historyManager.dailyStats.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No tracking history yet")
                            .foregroundColor(.secondary)
                        Text("Start tracking to see daily summaries here")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(dailyStatsToShow) { daily in
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

    /// Daily stats always shows ALL days - not filtered by time range
    /// Time range only affects the summary stats cards at the top
    private var dailyStatsToShow: [DailyStats] {
        // Always show all days in Daily Records section
        return historyManager.dailyStats
    }

    /// Total unique days across all data (for display in header)
    private var totalUniqueDays: Int {
        historyManager.dailyStats.count
    }

    // MARK: - Sessions Section (Collapsible)

    private var sessionsSection: some View {
        VStack(spacing: 0) {
            // Collapsible header
            HStack {
                Image(systemName: "list.bullet.rectangle")
                    .foregroundColor(.orange)
                Text("Sessions")
                    .font(.headline)
                Text("(\(historyManager.sessions.count))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .rotationEffect(.degrees(showSessionsList ? 90 : 0))
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showSessionsList.toggle()
                }
            }
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

    // MARK: - Export Single Session

    private func exportSessionToGPX(_ session: TrackingSession) {
        let gpxContent = historyManager.exportSessionToGPX(session)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-HHmm"
        let filename = "NextTrack-\(dateFormatter.string(from: session.startTime)).gpx"

        if let url = historyManager.saveGPXFile(content: gpxContent, filename: filename) {
            exportItem = IdentifiableURL(url: url)
        }
    }

    // MARK: - Export Daily Stats

    private func exportDayToGPX(_ dailyStats: DailyStats) {
        let gpxContent = historyManager.exportDayToGPX(dailyStats)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let filename = "NextTrack-\(dateFormatter.string(from: dailyStats.date)).gpx"

        if let url = historyManager.saveGPXFile(content: gpxContent, filename: filename) {
            exportItem = IdentifiableURL(url: url)
        }
    }

    private func openDayInMaps(_ dailyStats: DailyStats) {
        let locations = dailyStats.allLocations
        print("[Maps] Opening day in maps - \(locations.count) locations")

        guard !locations.isEmpty else {
            print("[Maps] No locations to show")
            return
        }

        // Create map items from the track points
        var mapItems: [MKMapItem] = []

        // Add start point
        if let first = locations.first {
            let startCoord = CLLocationCoordinate2D(latitude: first.latitude, longitude: first.longitude)
            let startPlacemark = MKPlacemark(coordinate: startCoord)
            let startItem = MKMapItem(placemark: startPlacemark)
            startItem.name = "Start"
            mapItems.append(startItem)
            print("[Maps] Start: \(first.latitude), \(first.longitude)")
        }

        // Add end point if different from start
        if let last = locations.last, locations.count > 1 {
            let endCoord = CLLocationCoordinate2D(latitude: last.latitude, longitude: last.longitude)
            let endPlacemark = MKPlacemark(coordinate: endCoord)
            let endItem = MKMapItem(placemark: endPlacemark)
            endItem.name = "End"
            mapItems.append(endItem)
            print("[Maps] End: \(last.latitude), \(last.longitude)")
        }

        // Open Apple Maps directly
        print("[Maps] Opening Apple Maps with \(mapItems.count) items")
        MKMapItem.openMaps(with: mapItems, launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
        ])
    }

    private func shareDayGPX(_ dailyStats: DailyStats) {
        let gpxContent = historyManager.exportDayToGPX(dailyStats)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let filename = "NextTrack-\(dateFormatter.string(from: dailyStats.date)).gpx"

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

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

// MARK: - Stat Card Large

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

// MARK: - Session Row View (Collapsible)

struct SessionRowView: View {
    let session: TrackingSession
    let onDelete: () -> Void
    let onExport: (TrackingSession) -> Void

    @State private var isExpanded = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            // Header (always visible) - entire row is tappable
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
            .contentShape(Rectangle())  // Makes entire area tappable
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
        .background(Color(.systemGray6))
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
                            title: "Full Date",
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
        .background(Color(.systemGray6))
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
