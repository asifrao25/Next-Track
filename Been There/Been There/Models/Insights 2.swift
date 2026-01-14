//
//  Insights.swift
//  Next-track
//
//  Models for smart insights and analytics
//

import Foundation

// MARK: - Insight Period

enum InsightPeriod: String, Codable, CaseIterable {
    case daily = "Today"
    case weekly = "This Week"
    case monthly = "This Month"

    var displayName: String { rawValue }

    var dateRange: (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()

        switch self {
        case .daily:
            let start = calendar.startOfDay(for: now)
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? now
            return (start, end)

        case .weekly:
            let start = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            return (start, now)

        case .monthly:
            let start = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            return (start, now)
        }
    }

    var previousPeriodRange: (start: Date, end: Date) {
        let calendar = Calendar.current
        let current = dateRange

        switch self {
        case .daily:
            let start = calendar.date(byAdding: .day, value: -1, to: current.start) ?? current.start
            return (start, current.start)

        case .weekly:
            let start = calendar.date(byAdding: .day, value: -7, to: current.start) ?? current.start
            return (start, current.start)

        case .monthly:
            let start = calendar.date(byAdding: .month, value: -1, to: current.start) ?? current.start
            return (start, current.start)
        }
    }
}

// MARK: - Session Highlight

struct SessionHighlight: Codable {
    let sessionId: UUID
    let name: String
    let distance: Double        // meters
    let duration: TimeInterval  // seconds
    let date: Date

    var formattedDistance: String {
        let miles = distance / 1609.344
        return String(format: "%.2f mi", miles)
    }

    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"  // Day name
        return formatter.string(from: date)
    }
}

// MARK: - Place Highlight

struct PlaceHighlight: Codable {
    let placeId: UUID?
    let name: String
    let visitCount: Int
    let category: PlaceCategory
}

// MARK: - Activity Breakdown

struct ActivityBreakdown: Codable {
    var walkingTime: TimeInterval = 0
    var runningTime: TimeInterval = 0
    var cyclingTime: TimeInterval = 0
    var drivingTime: TimeInterval = 0
    var stationaryTime: TimeInterval = 0
    var unknownTime: TimeInterval = 0

    var totalTime: TimeInterval {
        walkingTime + runningTime + cyclingTime + drivingTime + stationaryTime + unknownTime
    }

    var walkingPercentage: Double {
        totalTime > 0 ? (walkingTime / totalTime) * 100 : 0
    }

    var runningPercentage: Double {
        totalTime > 0 ? (runningTime / totalTime) * 100 : 0
    }

    var cyclingPercentage: Double {
        totalTime > 0 ? (cyclingTime / totalTime) * 100 : 0
    }

    var drivingPercentage: Double {
        totalTime > 0 ? (drivingTime / totalTime) * 100 : 0
    }

    var stationaryPercentage: Double {
        totalTime > 0 ? (stationaryTime / totalTime) * 100 : 0
    }

    /// For simplified display (walking + running = "On Foot")
    var onFootTime: TimeInterval {
        walkingTime + runningTime
    }

    var onFootPercentage: Double {
        totalTime > 0 ? (onFootTime / totalTime) * 100 : 0
    }

    /// Combine cycling + driving as "Vehicle"
    var vehicleTime: TimeInterval {
        cyclingTime + drivingTime
    }

    var vehiclePercentage: Double {
        totalTime > 0 ? (vehicleTime / totalTime) * 100 : 0
    }

    // Formatted strings
    func formattedTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    var formattedWalkingTime: String { formattedTime(walkingTime) }
    var formattedDrivingTime: String { formattedTime(drivingTime) }
    var formattedStationaryTime: String { formattedTime(stationaryTime) }
    var formattedOnFootTime: String { formattedTime(onFootTime) }
    var formattedVehicleTime: String { formattedTime(vehicleTime) }
    var formattedTotalTime: String { formattedTime(totalTime) }
}

// MARK: - Insight Summary

struct InsightSummary: Codable {
    let id: UUID
    let period: InsightPeriod
    let generatedAt: Date

    // Core metrics
    var totalDistance: Double           // meters
    var totalDuration: TimeInterval     // seconds (actual tracking time)
    var sessionCount: Int

    // Activity breakdown
    var activityBreakdown: ActivityBreakdown

    // Places
    var placesVisited: Int
    var newPlacesDiscovered: Int
    var citiesVisited: Int

    // Comparisons (vs previous period)
    var distanceChange: Double?         // percentage (+/- %)
    var durationChange: Double?         // percentage (+/- %)

    // Highlights
    var longestSession: SessionHighlight?
    var mostVisitedPlace: PlaceHighlight?

    // MARK: - Computed Properties

    var formattedDistance: String {
        let miles = totalDistance / 1609.344
        return String(format: "%.1f mi", miles)
    }

    var formattedDuration: String {
        let hours = Int(totalDuration) / 3600
        let minutes = (Int(totalDuration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    var formattedDistanceChange: String? {
        guard let change = distanceChange else { return nil }
        let sign = change >= 0 ? "+" : ""
        return "\(sign)\(Int(change))%"
    }

    var formattedDurationChange: String? {
        guard let change = durationChange else { return nil }
        let sign = change >= 0 ? "+" : ""
        return "\(sign)\(Int(change))%"
    }

    var isDistanceUp: Bool {
        (distanceChange ?? 0) >= 0
    }

    var isDurationUp: Bool {
        (durationChange ?? 0) >= 0
    }

    var averageDistancePerSession: Double {
        sessionCount > 0 ? totalDistance / Double(sessionCount) : 0
    }

    var formattedAverageDistance: String {
        let miles = averageDistancePerSession / 1609.344
        return String(format: "%.1f mi/session", miles)
    }

    // MARK: - Initialization

    init(
        period: InsightPeriod,
        totalDistance: Double = 0,
        totalDuration: TimeInterval = 0,
        sessionCount: Int = 0,
        activityBreakdown: ActivityBreakdown = ActivityBreakdown(),
        placesVisited: Int = 0,
        newPlacesDiscovered: Int = 0,
        citiesVisited: Int = 0,
        distanceChange: Double? = nil,
        durationChange: Double? = nil,
        longestSession: SessionHighlight? = nil,
        mostVisitedPlace: PlaceHighlight? = nil
    ) {
        self.id = UUID()
        self.period = period
        self.generatedAt = Date()
        self.totalDistance = totalDistance
        self.totalDuration = totalDuration
        self.sessionCount = sessionCount
        self.activityBreakdown = activityBreakdown
        self.placesVisited = placesVisited
        self.newPlacesDiscovered = newPlacesDiscovered
        self.citiesVisited = citiesVisited
        self.distanceChange = distanceChange
        self.durationChange = durationChange
        self.longestSession = longestSession
        self.mostVisitedPlace = mostVisitedPlace
    }

    // MARK: - Empty State

    static var empty: InsightSummary {
        InsightSummary(period: .weekly)
    }

    var isEmpty: Bool {
        sessionCount == 0 && totalDistance == 0
    }
}
