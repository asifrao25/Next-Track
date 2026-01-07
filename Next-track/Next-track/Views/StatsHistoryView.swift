//
//  StatsHistoryView.swift
//  Next-track
//
//  Detailed statistics and tracking history
//

import SwiftUI

struct StatsHistoryView: View {
    @StateObject private var historyManager = TrackingHistoryManager.shared
    @State private var selectedTimeRange: TimeRange = .today
    @State private var showClearConfirmation = false

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

                    // Session History
                    sessionHistorySection
                }
                .padding(.vertical)
            }
            .navigationTitle("Stats & History")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
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
                        SessionRowView(session: session) {
                            historyManager.deleteSession(session)
                        }
                    }
                }
                .padding(.horizontal)
            }
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

// MARK: - Session Row View

struct SessionRowView: View {
    let session: TrackingSession
    let onDelete: () -> Void

    @State private var showDeleteConfirmation = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.startTime, style: .date)
                    .font(.headline)

                HStack(spacing: 12) {
                    Label(session.formattedDuration, systemImage: "clock")
                    Label(session.formattedDistance, systemImage: "figure.walk")
                    Label("\(session.pointsCount) pts", systemImage: "mappin")
                }
                .font(.caption)
                .foregroundColor(.secondary)

                if session.isActive {
                    Text("Active")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
            }

            Spacer()

            Button {
                showDeleteConfirmation = true
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .alert("Delete Session?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                onDelete()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    StatsHistoryView()
}
