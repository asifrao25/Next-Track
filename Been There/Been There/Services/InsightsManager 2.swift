//
//  InsightsManager.swift
//  Next-track
//
//  Service for generating smart insights from tracking history
//

import Foundation
import Combine

class InsightsManager: ObservableObject {
    static let shared = InsightsManager()

    // MARK: - Published Properties

    @Published var dailyInsight: InsightSummary?
    @Published var weeklyInsight: InsightSummary?
    @Published var monthlyInsight: InsightSummary?
    @Published var isGenerating: Bool = false

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        // Listen for new sessions to refresh insights
        NotificationCenter.default.publisher(for: NSNotification.Name("SessionEnded"))
            .debounce(for: .seconds(5), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshInsights()
            }
            .store(in: &cancellables)
    }

    // MARK: - Public Methods

    /// Generate all insights
    func generateAllInsights() {
        isGenerating = true

        let sessions = TrackingHistoryManager.shared.sessions
        let places = PlaceDetectionManager.shared.detectedPlaces
        let cities = CityTracker.shared.visitedCities

        dailyInsight = generateInsight(for: .daily, sessions: sessions, places: places, cities: cities)
        weeklyInsight = generateInsight(for: .weekly, sessions: sessions, places: places, cities: cities)
        monthlyInsight = generateInsight(for: .monthly, sessions: sessions, places: places, cities: cities)

        isGenerating = false
    }

    /// Refresh insights (called after new data)
    func refreshInsights() {
        generateAllInsights()
    }

    /// Get insight for a specific period
    func getInsight(for period: InsightPeriod) -> InsightSummary {
        switch period {
        case .daily: return dailyInsight ?? .empty
        case .weekly: return weeklyInsight ?? .empty
        case .monthly: return monthlyInsight ?? .empty
        }
    }

    // MARK: - Private Methods

    private func generateInsight(
        for period: InsightPeriod,
        sessions: [TrackingSession],
        places: [DetectedPlace],
        cities: [VisitedCity]
    ) -> InsightSummary {
        let dateRange = period.dateRange
        let previousRange = period.previousPeriodRange

        // Filter sessions in current period
        let currentSessions = sessions.filter { session in
            session.startTime >= dateRange.start && session.startTime < dateRange.end
        }

        // Filter sessions in previous period (for comparison)
        let previousSessions = sessions.filter { session in
            session.startTime >= previousRange.start && session.startTime < previousRange.end
        }

        // Calculate core metrics for current period
        let totalDistance = currentSessions.reduce(0.0) { $0 + $1.totalDistance }
        let totalDuration = currentSessions.reduce(0.0) { $0 + $1.duration }

        // Calculate metrics for previous period
        let prevDistance = previousSessions.reduce(0.0) { $0 + $1.totalDistance }
        let prevDuration = previousSessions.reduce(0.0) { $0 + $1.duration }

        // Calculate percentage changes
        let distanceChange: Double? = prevDistance > 0
            ? ((totalDistance - prevDistance) / prevDistance) * 100
            : nil
        let durationChange: Double? = prevDuration > 0
            ? ((totalDuration - prevDuration) / prevDuration) * 100
            : nil

        // Calculate activity breakdown
        let activityBreakdown = calculateActivityBreakdown(for: currentSessions)

        // Places visited in period
        let placesVisitedInPeriod = places.filter { place in
            place.visitHistory.contains { visit in
                visit.arrivalTime >= dateRange.start && visit.arrivalTime < dateRange.end
            }
        }.count

        // New places discovered in period
        let newPlacesInPeriod = places.filter { place in
            place.createdAt >= dateRange.start && place.createdAt < dateRange.end
        }.count

        // Cities visited in period
        let citiesVisitedInPeriod = cities.filter { city in
            city.lastVisitDate >= dateRange.start && city.lastVisitDate < dateRange.end
        }.count

        // Find longest session
        let longestSession = currentSessions.max(by: { $0.totalDistance < $1.totalDistance })
        let sessionHighlight: SessionHighlight? = longestSession.map { session in
            SessionHighlight(
                sessionId: session.id,
                name: session.name,
                distance: session.totalDistance,
                duration: session.duration,
                date: session.startTime
            )
        }

        // Find most visited place
        let mostVisited = places.max(by: { $0.visitCount < $1.visitCount })
        let placeHighlight: PlaceHighlight? = mostVisited.map { place in
            PlaceHighlight(
                placeId: place.id,
                name: place.name ?? "Unknown Place",
                visitCount: place.visitCount,
                category: place.category
            )
        }

        return InsightSummary(
            period: period,
            totalDistance: totalDistance,
            totalDuration: totalDuration,
            sessionCount: currentSessions.count,
            activityBreakdown: activityBreakdown,
            placesVisited: placesVisitedInPeriod,
            newPlacesDiscovered: newPlacesInPeriod,
            citiesVisited: citiesVisitedInPeriod,
            distanceChange: distanceChange,
            durationChange: durationChange,
            longestSession: sessionHighlight,
            mostVisitedPlace: placeHighlight
        )
    }

    private func calculateActivityBreakdown(for sessions: [TrackingSession]) -> ActivityBreakdown {
        var breakdown = ActivityBreakdown()

        for session in sessions {
            for location in session.locations {
                // Determine activity type from speed
                let speed = location.speed ?? 0
                let timeIncrement: TimeInterval = 1  // Each location point represents ~1 second of time

                // Also check stored activity type if available
                if let activityType = location.activityType {
                    switch activityType.lowercased() {
                    case "walking":
                        breakdown.walkingTime += timeIncrement
                    case "running":
                        breakdown.runningTime += timeIncrement
                    case "cycling":
                        breakdown.cyclingTime += timeIncrement
                    case "automotive", "driving":
                        breakdown.drivingTime += timeIncrement
                    case "stationary":
                        breakdown.stationaryTime += timeIncrement
                    default:
                        breakdown.unknownTime += timeIncrement
                    }
                } else {
                    // Infer from speed
                    if speed < 0.5 {
                        // Stationary (< 0.5 m/s ≈ 1 mph)
                        breakdown.stationaryTime += timeIncrement
                    } else if speed < 2.0 {
                        // Walking (0.5-2 m/s ≈ 1-4.5 mph)
                        breakdown.walkingTime += timeIncrement
                    } else if speed < 4.0 {
                        // Running (2-4 m/s ≈ 4.5-9 mph)
                        breakdown.runningTime += timeIncrement
                    } else if speed < 10.0 {
                        // Cycling (4-10 m/s ≈ 9-22 mph)
                        breakdown.cyclingTime += timeIncrement
                    } else {
                        // Driving (> 10 m/s ≈ 22+ mph)
                        breakdown.drivingTime += timeIncrement
                    }
                }
            }
        }

        return breakdown
    }

    // MARK: - Summary Strings

    /// Get a natural language summary of the insight
    func getSummaryText(for period: InsightPeriod) -> String {
        let insight = getInsight(for: period)

        if insight.isEmpty {
            return "No tracking data for \(period.displayName.lowercased())."
        }

        var summary = "You traveled \(insight.formattedDistance) in \(insight.sessionCount) session\(insight.sessionCount == 1 ? "" : "s")"

        if let change = insight.formattedDistanceChange {
            summary += " (\(change) vs last \(period == .daily ? "day" : period == .weekly ? "week" : "month"))"
        }

        summary += "."

        if insight.placesVisited > 0 {
            summary += " Visited \(insight.placesVisited) place\(insight.placesVisited == 1 ? "" : "s")."
        }

        if insight.newPlacesDiscovered > 0 {
            summary += " Discovered \(insight.newPlacesDiscovered) new place\(insight.newPlacesDiscovered == 1 ? "" : "s")!"
        }

        return summary
    }

    /// Get activity summary text
    func getActivitySummaryText(for period: InsightPeriod) -> String {
        let insight = getInsight(for: period)
        let breakdown = insight.activityBreakdown

        if breakdown.totalTime == 0 {
            return "No activity data available."
        }

        var activities: [String] = []

        if breakdown.onFootPercentage > 10 {
            activities.append("\(Int(breakdown.onFootPercentage))% on foot")
        }
        if breakdown.vehiclePercentage > 10 {
            activities.append("\(Int(breakdown.vehiclePercentage))% in vehicle")
        }
        if breakdown.stationaryPercentage > 10 {
            activities.append("\(Int(breakdown.stationaryPercentage))% stationary")
        }

        if activities.isEmpty {
            return "Various activities recorded."
        }

        return activities.joined(separator: ", ")
    }

    // MARK: - Highlights

    /// Get today's key metrics for dashboard
    func getTodayMetrics() -> (distance: String, duration: String, places: Int) {
        let insight = dailyInsight ?? .empty
        return (
            distance: insight.formattedDistance,
            duration: insight.formattedDuration,
            places: insight.placesVisited
        )
    }

    /// Get week-over-week trends
    func getWeeklyTrends() -> (distanceTrend: Double?, durationTrend: Double?, isDistanceUp: Bool, isDurationUp: Bool) {
        let insight = weeklyInsight ?? .empty
        return (
            distanceTrend: insight.distanceChange,
            durationTrend: insight.durationChange,
            isDistanceUp: insight.isDistanceUp,
            isDurationUp: insight.isDurationUp
        )
    }
}

// MARK: - Notification Names

extension NSNotification.Name {
    static let sessionEnded = NSNotification.Name("SessionEnded")
}
