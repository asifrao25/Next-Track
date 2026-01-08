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

    @State private var selectedPeriod: InsightPeriod = .weekly

    var currentInsight: InsightSummary {
        insightsManager.getInsight(for: selectedPeriod)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Period selector
                    PeriodSelector(selectedPeriod: $selectedPeriod)
                        .padding(.horizontal)

                    if currentInsight.isEmpty {
                        InsightsEmptyStateView()
                            .padding(.top, 40)
                    } else {
                        // Summary card
                        SummaryCard(insight: currentInsight)
                            .padding(.horizontal)

                        // Activity breakdown
                        ActivityBreakdownCard(breakdown: currentInsight.activityBreakdown)
                            .padding(.horizontal)

                        // Comparison with previous period
                        if currentInsight.distanceChange != nil || currentInsight.durationChange != nil {
                            ComparisonCard(insight: currentInsight, period: selectedPeriod)
                                .padding(.horizontal)
                        }

                        // Highlights
                        HighlightsCard(insight: currentInsight)
                            .padding(.horizontal)

                        // Quick stats
                        QuickStatsGrid(insight: currentInsight)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Insights")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        insightsManager.refreshInsights()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.pink)
                    }
                }
            }
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
        HStack(spacing: 8) {
            ForEach(InsightPeriod.allCases, id: \.self) { period in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedPeriod = period
                    }
                } label: {
                    Text(period.displayName)
                        .font(.subheadline)
                        .fontWeight(selectedPeriod == period ? .semibold : .regular)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(selectedPeriod == period ? Color.pink.opacity(0.2) : Color.gray.opacity(0.1))
                        )
                        .foregroundColor(selectedPeriod == period ? .pink : .primary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Empty State

struct InsightsEmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.pie")
                .font(.system(size: 60))
                .foregroundColor(.pink.opacity(0.5))

            Text("No Insights Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Start tracking to see your activity insights")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
}

// MARK: - Summary Card

struct SummaryCard: View {
    let insight: InsightSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Summary")
                    .font(.headline)
                Spacer()
                Text(insight.period.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 24) {
                // Distance
                VStack(spacing: 4) {
                    Text(insight.formattedDistance)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.pink)
                    Text("Distance")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Divider()
                    .frame(height: 40)

                // Duration
                VStack(spacing: 4) {
                    Text(insight.formattedDuration)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.pink)
                    Text("Time")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Divider()
                    .frame(height: 40)

                // Sessions
                VStack(spacing: 4) {
                    Text("\(insight.sessionCount)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.pink)
                    Text("Sessions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
    }
}

// MARK: - Activity Breakdown Card

struct ActivityBreakdownCard: View {
    let breakdown: ActivityBreakdown

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Activity Breakdown")
                .font(.headline)

            if breakdown.totalTime > 0 {
                // Activity bars
                VStack(spacing: 12) {
                    ActivityRow(
                        icon: "figure.walk",
                        label: "On Foot",
                        time: breakdown.formattedOnFootTime,
                        percentage: breakdown.onFootPercentage,
                        color: .green
                    )

                    ActivityRow(
                        icon: "car.fill",
                        label: "Vehicle",
                        time: breakdown.formattedVehicleTime,
                        percentage: breakdown.vehiclePercentage,
                        color: .blue
                    )

                    ActivityRow(
                        icon: "pause.circle.fill",
                        label: "Stationary",
                        time: breakdown.formattedStationaryTime,
                        percentage: breakdown.stationaryPercentage,
                        color: .gray
                    )
                }
            } else {
                Text("No activity data available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
    }
}

struct ActivityRow: View {
    let icon: String
    let label: String
    let time: String
    let percentage: Double
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
                .frame(width: 24)

            Text(label)
                .font(.subheadline)

            Spacer()

            Text(time)
                .font(.subheadline)
                .foregroundColor(.secondary)

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geometry.size.width * min(percentage / 100, 1.0), height: 8)
                }
            }
            .frame(width: 60, height: 8)

            Text("\(Int(percentage))%")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 35, alignment: .trailing)
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
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Comparison")
                    .font(.headline)
                Spacer()
                Text(comparisonText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 24) {
                // Distance change
                if let change = insight.formattedDistanceChange {
                    ComparisonItem(
                        label: "Distance",
                        change: change,
                        isPositive: insight.isDistanceUp
                    )
                }

                // Duration change
                if let change = insight.formattedDurationChange {
                    ComparisonItem(
                        label: "Time",
                        change: change,
                        isPositive: insight.isDurationUp
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
    }
}

struct ComparisonItem: View {
    let label: String
    let change: String
    let isPositive: Bool

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 14, weight: .semibold))
                Text(change)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
            }
            .foregroundColor(isPositive ? .green : .red)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Highlights Card

struct HighlightsCard: View {
    let insight: InsightSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Highlights")
                .font(.headline)

            VStack(spacing: 12) {
                // Longest session
                if let session = insight.longestSession {
                    HighlightRow(
                        icon: "trophy.fill",
                        iconColor: .yellow,
                        title: "Longest Trip",
                        subtitle: "\(session.formattedDistance) on \(session.formattedDate)"
                    )
                }

                // Most visited place
                if let place = insight.mostVisitedPlace {
                    HighlightRow(
                        icon: "star.fill",
                        iconColor: .orange,
                        title: "Most Visited",
                        subtitle: "\(place.name) (\(place.visitCount)x)"
                    )
                }

                // New places
                if insight.newPlacesDiscovered > 0 {
                    HighlightRow(
                        icon: "sparkles",
                        iconColor: .purple,
                        title: "New Places",
                        subtitle: "\(insight.newPlacesDiscovered) discovered"
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
    }
}

struct HighlightRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(iconColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

// MARK: - Quick Stats Grid

struct QuickStatsGrid: View {
    let insight: InsightSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Stats")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                QuickStatCard(
                    icon: "mappin.circle.fill",
                    value: "\(insight.placesVisited)",
                    label: "Places Visited",
                    color: .orange
                )

                QuickStatCard(
                    icon: "building.2.fill",
                    value: "\(insight.citiesVisited)",
                    label: "Cities Visited",
                    color: .purple
                )

                QuickStatCard(
                    icon: "speedometer",
                    value: insight.formattedAverageDistance,
                    label: "Avg per Session",
                    color: .blue
                )

                QuickStatCard(
                    icon: "clock.fill",
                    value: insight.formattedDuration,
                    label: "Total Time",
                    color: .green
                )
            }
        }
    }
}

struct QuickStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)
                Spacer()
            }

            HStack {
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Spacer()
            }

            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.tertiarySystemGroupedBackground))
        )
    }
}

// MARK: - Preview

#Preview {
    InsightsView()
}
