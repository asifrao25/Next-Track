//
//  StatsHistoryView.swift
//  Next-track
//
//  Detailed statistics and tracking history
//

import SwiftUI
import UniformTypeIdentifiers

struct StatsHistoryView: View {
    @StateObject private var historyManager = TrackingHistoryManager.shared
    @StateObject private var autoExportManager = AutoExportManager.shared
    @State private var selectedTimeRange: TimeRange = .today
    @State private var showClearConfirmation = false
    @State private var showExportSheet = false
    @State private var exportURL: URL?
    @State private var showImportPicker = false
    @State private var importError: String?
    @State private var showImportError = false
    @State private var showFolderPicker = false

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

                    // Session History
                    sessionHistorySection
                }
                .padding(.vertical)
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
            .sheet(isPresented: $showExportSheet) {
                if let url = exportURL {
                    ShareSheet(activityItems: [url])
                }
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
            exportURL = url
            showExportSheet = true
        }
    }

    private func exportAllToJSON() {
        guard let jsonData = historyManager.exportAllSessionsToJSON() else { return }
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let filename = "NextTrack-Backup-\(dateFormatter.string(from: Date())).json"

        if let url = historyManager.saveJSONFile(data: jsonData, filename: filename) {
            exportURL = url
            showExportSheet = true
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

    // MARK: - Session History

    private var sessionHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Sessions")
                    .font(.headline)
                Spacer()
                Text("\(sessionsToShow.count) sessions")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)

            if historyManager.sessions.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.badge.questionmark")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No tracking history yet")
                        .foregroundColor(.secondary)
                    Text("Start tracking to see your sessions here")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
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
            exportURL = url
            showExportSheet = true
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
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        }
        return String(format: "%.0f m", meters)
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
