//
//  TrackingHistory.swift
//  Next-track
//
//  Models for tracking history and sessions
//

import Foundation
import CoreLocation

// MARK: - Tracking Session

struct TrackingSession: Codable, Identifiable {
    let id: UUID
    var startTime: Date
    var endTime: Date?
    var pointsCount: Int
    var totalDistance: Double // meters
    var locations: [StoredLocation]

    var isActive: Bool {
        endTime == nil
    }

    var duration: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime)
    }

    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    var formattedDistance: String {
        if totalDistance >= 1000 {
            return String(format: "%.2f km", totalDistance / 1000)
        }
        return String(format: "%.0f m", totalDistance)
    }

    var averageSpeed: Double? {
        guard duration > 0 else { return nil }
        return totalDistance / duration // m/s
    }

    var formattedAverageSpeed: String {
        guard let speed = averageSpeed else { return "--" }
        let kmh = speed * 3.6
        return String(format: "%.1f km/h", kmh)
    }

    static func new() -> TrackingSession {
        TrackingSession(
            id: UUID(),
            startTime: Date(),
            endTime: nil,
            pointsCount: 0,
            totalDistance: 0,
            locations: []
        )
    }
}

// MARK: - Stored Location

struct StoredLocation: Codable {
    let latitude: Double
    let longitude: Double
    let timestamp: Date
    let altitude: Double?
    let speed: Double?
    let accuracy: Double?

    init(from clLocation: CLLocation) {
        self.latitude = clLocation.coordinate.latitude
        self.longitude = clLocation.coordinate.longitude
        self.timestamp = clLocation.timestamp
        self.altitude = clLocation.altitude >= 0 ? clLocation.altitude : nil
        self.speed = clLocation.speed >= 0 ? clLocation.speed : nil
        self.accuracy = clLocation.horizontalAccuracy >= 0 ? clLocation.horizontalAccuracy : nil
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    func distance(to other: StoredLocation) -> Double {
        let loc1 = CLLocation(latitude: latitude, longitude: longitude)
        let loc2 = CLLocation(latitude: other.latitude, longitude: other.longitude)
        return loc1.distance(from: loc2)
    }
}

// MARK: - History Manager

class TrackingHistoryManager: ObservableObject {
    static let shared = TrackingHistoryManager()

    @Published var sessions: [TrackingSession] = []
    @Published var currentSession: TrackingSession?

    private let storageKey = "trackingSessions"
    private let maxStoredSessions = 100

    private init() {
        loadSessions()
    }

    // MARK: - Session Management

    func startNewSession() {
        let session = TrackingSession.new()
        currentSession = session
        print("[TrackingHistory] Started new session: \(session.id)")
    }

    func endCurrentSession() {
        guard var session = currentSession else { return }
        session.endTime = Date()
        sessions.insert(session, at: 0)
        currentSession = nil
        trimOldSessions()
        saveSessions()
        print("[TrackingHistory] Ended session: \(session.id) - \(session.pointsCount) points, \(session.formattedDistance)")
    }

    func addLocation(_ location: CLLocation) {
        guard var session = currentSession else { return }

        let storedLocation = StoredLocation(from: location)

        // Calculate distance from last point
        if let lastLocation = session.locations.last {
            let distance = storedLocation.distance(to: lastLocation)
            session.totalDistance += distance
        }

        session.locations.append(storedLocation)
        session.pointsCount += 1
        currentSession = session
    }

    func deleteSession(_ session: TrackingSession) {
        sessions.removeAll { $0.id == session.id }
        saveSessions()
    }

    func clearAllHistory() {
        sessions.removeAll()
        saveSessions()
    }

    // MARK: - Statistics

    var totalSessions: Int {
        sessions.count
    }

    var totalPointsAllTime: Int {
        sessions.reduce(0) { $0 + $1.pointsCount } + (currentSession?.pointsCount ?? 0)
    }

    var totalDistanceAllTime: Double {
        sessions.reduce(0) { $0 + $1.totalDistance } + (currentSession?.totalDistance ?? 0)
    }

    var totalDurationAllTime: TimeInterval {
        sessions.reduce(0) { $0 + $1.duration } + (currentSession?.duration ?? 0)
    }

    var averageSessionDuration: TimeInterval {
        guard !sessions.isEmpty else { return 0 }
        return totalDurationAllTime / Double(sessions.count)
    }

    var todaysSessions: [TrackingSession] {
        sessions.filter { Calendar.current.isDateInToday($0.startTime) }
    }

    var todaysDistance: Double {
        todaysSessions.reduce(0) { $0 + $1.totalDistance } + (currentSession?.totalDistance ?? 0)
    }

    var todaysPoints: Int {
        todaysSessions.reduce(0) { $0 + $1.pointsCount } + (currentSession?.pointsCount ?? 0)
    }

    var thisWeeksSessions: [TrackingSession] {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return sessions.filter { $0.startTime >= weekAgo }
    }

    var thisWeeksDistance: Double {
        thisWeeksSessions.reduce(0) { $0 + $1.totalDistance }
    }

    // MARK: - Persistence

    private func loadSessions() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let sessions = try? JSONDecoder().decode([TrackingSession].self, from: data) else {
            return
        }
        self.sessions = sessions
    }

    private func saveSessions() {
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func trimOldSessions() {
        if sessions.count > maxStoredSessions {
            sessions = Array(sessions.prefix(maxStoredSessions))
        }
    }
}
