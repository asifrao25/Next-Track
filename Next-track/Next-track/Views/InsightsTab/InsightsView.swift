//
//  InsightsView.swift
//  Next-track
//
//  View for displaying smart insights and analytics
//

import SwiftUI
import Charts

struct InsightsView: View {
    @ObservedObject var insightsManager = InsightsManager.shared
    @ObservedObject var placeManager = PlaceDetectionManager.shared
    @ObservedObject var cityTracker = CityTracker.shared
    @ObservedObject var locationManager = LocationManager.shared
    @ObservedObject var settingsManager = SettingsManager.shared
    @StateObject private var connectionMonitor = ConnectionMonitor.shared
    @StateObject private var batteryMonitor = BatteryMonitor.shared
    @StateObject private var historyManager = TrackingHistoryManager.shared
    @StateObject private var geofenceManager = GeofenceManager.shared

    @State private var selectedPeriod: InsightPeriod = .weekly

    var currentInsight: InsightSummary {
        insightsManager.getInsight(for: selectedPeriod)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()

                // Main content
                VStack(spacing: 0) {
                    // Header at top
                    CustomTitleHeaderView(
                        connectionMonitor: connectionMonitor,
                        batteryMonitor: batteryMonitor,
                        isTracking: locationManager.isTracking,
                        hasIssues: false,
                        pendingCount: PendingLocationQueue.shared.count,
                        currentZoneName: geofenceManager.currentZone?.name,
                        connectionStatus: .connected,
                        lastSuccessfulSend: settingsManager.trackingStats.lastSuccessfulSend,
                        todayMiles: historyManager.todaysDistance / 1609.344,
                        sessionDuration: historyManager.currentSession?.duration ?? 0,
                        pointsSent: settingsManager.trackingStats.pointsSentToday,
                        currentElevation: locationManager.currentLocation?.altitude,
                        accentColor: .pink
                    )
                    .padding(.horizontal, 4)

                    // Scrollable content
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            // Period selector
                            PeriodSelector(selectedPeriod: $selectedPeriod)
                                .padding(.horizontal, 16)
                                .padding(.top, 8)

                            if currentInsight.isEmpty {
                                InsightsEmptyStateView()
                                    .padding(.top, 20)
                            } else {
                                // Summary card
                                SummaryCard(insight: currentInsight)
                                    .padding(.horizontal, 16)

                                // Activity breakdown with pie chart
                                ActivityBreakdownCard(breakdown: currentInsight.activityBreakdown)
                                    .padding(.horizontal, 16)

                                // Comparison with previous period
                                if currentInsight.distanceChange != nil || currentInsight.durationChange != nil {
                                    ComparisonCard(insight: currentInsight, period: selectedPeriod)
                                        .padding(.horizontal, 16)
                                }

                                // Highlights
                                HighlightsCard(insight: currentInsight)
                                    .padding(.horizontal, 16)

                                // Quick stats in single row
                                QuickStatsGrid(insight: currentInsight)
                                    .padding(.horizontal, 16)

                                // Refresh button
                                Button {
                                    insightsManager.refreshInsights()
                                    HapticManager.shared.buttonTap()
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.system(size: 14, weight: .semibold))
                                        Text("Refresh Insights")
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 14)
                                    .background(
                                        Capsule()
                                            .fill(
                                                LinearGradient(
                                                    colors: [.pink, .pink.opacity(0.8)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .shadow(color: .pink.opacity(0.4), radius: 8, x: 0, y: 4)
                                    )
                                }
                                .padding(.top, 8)
                            }
                        }
                        .padding(.top, 4)
                        .padding(.bottom, 100) // Extra padding for tab bar
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                insightsManager.generateAllInsights()
            }
        }
    }
}

// MARK: - Period Selector

struct PeriodSelector: View {
    @Binding var selectedPeriod: InsightPeriod

    var body: some View {
        HStack(spacing: 0) {
            ForEach(InsightPeriod.allCases, id: \.self) { period in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedPeriod = period
                        HapticManager.shared.selectionChanged()
                    }
                } label: {
                    Text(period.displayName)
                        .font(.system(size: 14, weight: selectedPeriod == period ? .bold : .medium))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(
                            ZStack {
                                if selectedPeriod == period {
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [.pink, .pink.opacity(0.8)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .shadow(color: .pink.opacity(0.4), radius: 8, x: 0, y: 4)
                                }
                            }
                        )
                        .foregroundColor(selectedPeriod == period ? .white : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            Capsule()
                .fill(Color(UIColor.tertiarySystemGroupedBackground))
        )
    }
}

// MARK: - Empty State

struct InsightsEmptyStateView: View {
    var body: some View {
        VStack(spacing: 24) {
            // Icon with animated glow effect
            ZStack {
                Circle()
                    .fill(Color.pink.opacity(0.1))
                    .frame(width: 120, height: 120)

                Circle()
                    .fill(Color.pink.opacity(0.05))
                    .frame(width: 100, height: 100)

                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 50, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.pink, .pink.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 8) {
                Text("No Insights Yet")
                    .font(.system(size: 22, weight: .bold))

                Text("Start tracking to see your activity insights\nand discover patterns in your movements")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            // Hint cards
            VStack(spacing: 12) {
                EmptyStateHintRow(icon: "figure.walk", text: "Track your daily walks and drives", color: .green)
                EmptyStateHintRow(icon: "mappin.circle.fill", text: "Discover your most visited places", color: .orange)
                EmptyStateHintRow(icon: "chart.bar.fill", text: "Compare activity over time", color: .blue)
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 32)
    }
}

struct EmptyStateHintRow: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
            }

            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(UIColor.tertiarySystemGroupedBackground))
        )
    }
}

// MARK: - Summary Card

struct SummaryCard: View {
    let insight: InsightSummary

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.pink)
                    Text("Summary")
                        .font(.system(size: 16, weight: .bold))
                }
                Spacer()
                Text(insight.period.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.pink.opacity(0.3)))
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Stats row - single line, symmetrical
            HStack(spacing: 0) {
                // Distance
                SummaryStatItem(
                    icon: "figure.walk",
                    value: insight.formattedDistance,
                    label: "Distance",
                    color: .orange
                )

                // Divider
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 1, height: 50)

                // Duration
                SummaryStatItem(
                    icon: "clock.fill",
                    value: insight.formattedDuration,
                    label: "Time",
                    color: .blue
                )

                // Divider
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 1, height: 50)

                // Sessions
                SummaryStatItem(
                    icon: "point.topleft.down.to.point.bottomright.curvepath",
                    value: "\(insight.sessionCount)",
                    label: "Sessions",
                    color: .green
                )
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [.pink.opacity(0.3), .clear, .pink.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

struct SummaryStatItem: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Activity Breakdown Card

struct ActivityBreakdownCard: View {
    let breakdown: ActivityBreakdown

    // Activity data for pie chart
    var activityData: [(String, Double, Color)] {
        [
            ("On Foot", breakdown.onFootPercentage, Color.green),
            ("Vehicle", breakdown.vehiclePercentage, Color.blue),
            ("Stationary", breakdown.stationaryPercentage, Color.gray)
        ].filter { $0.1 > 0 }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "chart.pie.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.pink)
                    Text("Activity Breakdown")
                        .font(.system(size: 16, weight: .bold))
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 16)

            if breakdown.totalTime > 0 {
                HStack(spacing: 16) {
                    // Pie Chart
                    ZStack {
                        // Pie slices
                        ActivityPieChart(
                            onFoot: breakdown.onFootPercentage,
                            vehicle: breakdown.vehiclePercentage,
                            stationary: breakdown.stationaryPercentage
                        )
                        .frame(width: 120, height: 120)

                        // Center label
                        VStack(spacing: 2) {
                            Text(breakdown.formattedTotalTime)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                            Text("Total")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }

                    // Legend with stats
                    VStack(spacing: 12) {
                        ActivityLegendItem(
                            icon: "figure.walk",
                            label: "On Foot",
                            time: breakdown.formattedOnFootTime,
                            percentage: breakdown.onFootPercentage,
                            color: .green
                        )

                        ActivityLegendItem(
                            icon: "car.fill",
                            label: "Vehicle",
                            time: breakdown.formattedVehicleTime,
                            percentage: breakdown.vehiclePercentage,
                            color: .blue
                        )

                        ActivityLegendItem(
                            icon: "pause.circle.fill",
                            label: "Stationary",
                            time: breakdown.formattedStationaryTime,
                            percentage: breakdown.stationaryPercentage,
                            color: .gray
                        )
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "chart.pie")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.3))
                    Text("No activity data available")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .padding(.bottom, 16)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [.pink.opacity(0.3), .clear, .pink.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

// MARK: - Activity Pie Chart

struct ActivityPieChart: View {
    let onFoot: Double
    let vehicle: Double
    let stationary: Double

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let center = CGPoint(x: size / 2, y: size / 2)
            let radius = size / 2

            ZStack {
                // Background circle
                Circle()
                    .fill(Color.gray.opacity(0.1))

                // Pie slices
                let total = max(onFoot + vehicle + stationary, 0.01)
                let onFootAngle = (onFoot / total) * 360
                let vehicleAngle = (vehicle / total) * 360
                let stationaryAngle = (stationary / total) * 360

                // On Foot slice
                if onFoot > 0 {
                    PieSlice(startAngle: -90, endAngle: -90 + onFootAngle)
                        .fill(Color.green)
                }

                // Vehicle slice
                if vehicle > 0 {
                    PieSlice(startAngle: -90 + onFootAngle, endAngle: -90 + onFootAngle + vehicleAngle)
                        .fill(Color.blue)
                }

                // Stationary slice
                if stationary > 0 {
                    PieSlice(startAngle: -90 + onFootAngle + vehicleAngle, endAngle: -90 + onFootAngle + vehicleAngle + stationaryAngle)
                        .fill(Color.gray)
                }

                // Inner circle for donut effect
                Circle()
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
                    .frame(width: size * 0.6, height: size * 0.6)
            }
        }
    }
}

struct PieSlice: Shape {
    let startAngle: Double
    let endAngle: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(startAngle),
            endAngle: .degrees(endAngle),
            clockwise: false
        )
        path.closeSubpath()

        return path
    }
}

struct ActivityLegendItem: View {
    let icon: String
    let label: String
    let time: String
    let percentage: Double
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            // Color indicator
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)

            // Icon
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 16)

            // Label
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)

            Spacer()

            // Percentage
            Text("\(Int(percentage))%")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(color)
        }
    }
}

// MARK: - Comparison Card

struct ComparisonCard: View {
    let insight: InsightSummary
    let period: InsightPeriod

    var comparisonText: String {
        switch period {
        case .daily: return "vs yesterday"
        case .weekly: return "vs last week"
        case .monthly: return "vs last month"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.pink)
                    Text("Comparison")
                        .font(.system(size: 16, weight: .bold))
                }
                Spacer()
                Text(comparisonText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.pink.opacity(0.3)))
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Comparison items in a row
            HStack(spacing: 16) {
                // Distance change
                if let change = insight.formattedDistanceChange {
                    ComparisonItem(
                        icon: "figure.walk",
                        label: "Distance",
                        change: change,
                        isPositive: insight.isDistanceUp
                    )
                }

                // Duration change
                if let change = insight.formattedDurationChange {
                    ComparisonItem(
                        icon: "clock.fill",
                        label: "Time",
                        change: change,
                        isPositive: insight.isDurationUp
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [.pink.opacity(0.3), .clear, .pink.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

struct ComparisonItem: View {
    let icon: String
    let label: String
    let change: String
    let isPositive: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Icon with background
            ZStack {
                Circle()
                    .fill(isPositive ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isPositive ? .green : .red)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)

                HStack(spacing: 4) {
                    Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 12, weight: .bold))
                    Text(change)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                }
                .foregroundColor(isPositive ? .green : .red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(UIColor.tertiarySystemGroupedBackground))
        )
    }
}

// MARK: - Highlights Card

struct HighlightsCard: View {
    let insight: InsightSummary

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.pink)
                    Text("Highlights")
                        .font(.system(size: 16, weight: .bold))
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            VStack(spacing: 10) {
                // Longest session
                if let session = insight.longestSession {
                    HighlightRow(
                        icon: "trophy.fill",
                        iconColor: .yellow,
                        bgColor: .yellow.opacity(0.15),
                        title: "Longest Trip",
                        subtitle: "\(session.formattedDistance) on \(session.formattedDate)"
                    )
                }

                // Most visited place
                if let place = insight.mostVisitedPlace {
                    HighlightRow(
                        icon: "star.fill",
                        iconColor: .orange,
                        bgColor: .orange.opacity(0.15),
                        title: "Most Visited",
                        subtitle: "\(place.name) (\(place.visitCount)x)"
                    )
                }

                // New places
                if insight.newPlacesDiscovered > 0 {
                    HighlightRow(
                        icon: "sparkles",
                        iconColor: .purple,
                        bgColor: .purple.opacity(0.15),
                        title: "New Places",
                        subtitle: "\(insight.newPlacesDiscovered) discovered"
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [.pink.opacity(0.3), .clear, .pink.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

struct HighlightRow: View {
    let icon: String
    let iconColor: Color
    let bgColor: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            // Icon with colored background
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(bgColor)
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.5))
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(UIColor.tertiarySystemGroupedBackground))
        )
    }
}

// MARK: - Quick Stats Grid

struct QuickStatsGrid: View {
    let insight: InsightSummary

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.pink)
                    Text("Quick Stats")
                        .font(.system(size: 16, weight: .bold))
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Single row of 4 stats
            HStack(spacing: 8) {
                QuickStatCard(
                    icon: "mappin.circle.fill",
                    value: "\(insight.placesVisited)",
                    label: "Places",
                    color: .orange
                )

                QuickStatCard(
                    icon: "building.2.fill",
                    value: "\(insight.citiesVisited)",
                    label: "Cities",
                    color: .purple
                )

                QuickStatCard(
                    icon: "speedometer",
                    value: insight.formattedAverageDistance,
                    label: "Avg/Trip",
                    color: .blue
                )

                QuickStatCard(
                    icon: "clock.fill",
                    value: insight.formattedDuration,
                    label: "Time",
                    color: .green
                )
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [.pink.opacity(0.3), .clear, .pink.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

struct QuickStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            // Icon with background
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 32, height: 32)

                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
            }

            // Value
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            // Label
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(UIColor.tertiarySystemGroupedBackground))
        )
    }
}

// MARK: - Preview

#Preview {
    InsightsView()
}
