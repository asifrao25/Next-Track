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

    /// Formatted name for display and export
    var name: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "Track - \(formatter.string(from: startTime))"
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

    /// Maximum altitude reached during the session
    var maxAltitude: Double? {
        let altitudes = locations.compactMap { $0.altitude }
        return altitudes.max()
    }

    /// Average horizontal accuracy during the session
    var averageAccuracy: Double? {
        let accuracies = locations.compactMap { $0.accuracy }
        guard !accuracies.isEmpty else { return nil }
        return accuracies.reduce(0, +) / Double(accuracies.count)
    }

    /// Minimum altitude reached during the session
    var minAltitude: Double? {
        let altitudes = locations.compactMap { $0.altitude }
        return altitudes.min()
    }

    /// Elevation gain during the session
    var elevationGain: Double {
        var gain = 0.0
        var previousAltitude: Double?

        for location in locations {
            if let alt = location.altitude {
                if let prev = previousAltitude, alt > prev {
                    gain += (alt - prev)
                }
                previousAltitude = alt
            }
        }
        return gain
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
    private let maxStoredSessions = 10000  // Keep all sessions (effectively unlimited)

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

    // MARK: - Export Functions

    /// Export a single session to GPX format (works with Google Earth, Apple Maps, most GPS apps)
    func exportSessionToGPX(_ session: TrackingSession) -> String {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="Next Track iOS App"
             xmlns="http://www.topografix.com/GPX/1/1"
             xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
             xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">
          <metadata>
            <name>\(session.name)</name>
            <time>\(dateFormatter.string(from: session.startTime))</time>
          </metadata>
          <trk>
            <name>\(session.name)</name>
            <trkseg>

        """

        for location in session.locations {
            gpx += "      <trkpt lat=\"\(location.latitude)\" lon=\"\(location.longitude)\">\n"
            if let altitude = location.altitude {
                gpx += "        <ele>\(altitude)</ele>\n"
            }
            gpx += "        <time>\(dateFormatter.string(from: location.timestamp))</time>\n"
            if let speed = location.speed {
                gpx += "        <speed>\(speed)</speed>\n"
            }
            gpx += "      </trkpt>\n"
        }

        gpx += """
            </trkseg>
          </trk>
        </gpx>
        """

        return gpx
    }

    /// Export all sessions to a single GPX file
    func exportAllSessionsToGPX() -> String {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="Next Track iOS App"
             xmlns="http://www.topografix.com/GPX/1/1"
             xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
             xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">
          <metadata>
            <name>Next Track Export - All Sessions</name>
            <time>\(dateFormatter.string(from: Date()))</time>
          </metadata>

        """

        for session in sessions {
            gpx += "  <trk>\n"
            gpx += "    <name>\(session.name)</name>\n"
            gpx += "    <trkseg>\n"

            for location in session.locations {
                gpx += "      <trkpt lat=\"\(location.latitude)\" lon=\"\(location.longitude)\">\n"
                if let altitude = location.altitude {
                    gpx += "        <ele>\(altitude)</ele>\n"
                }
                gpx += "        <time>\(dateFormatter.string(from: location.timestamp))</time>\n"
                gpx += "      </trkpt>\n"
            }

            gpx += "    </trkseg>\n"
            gpx += "  </trk>\n"
        }

        gpx += "</gpx>"

        return gpx
    }

    /// Export a session to JSON format (for backup/restore)
    func exportSessionToJSON(_ session: TrackingSession) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(session)
    }

    /// Export all sessions to JSON format
    func exportAllSessionsToJSON() -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(sessions)
    }

    /// Import sessions from JSON data
    func importSessionsFromJSON(_ data: Data) -> Bool {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let importedSessions = try? decoder.decode([TrackingSession].self, from: data) {
            // Merge with existing, avoiding duplicates
            for imported in importedSessions {
                if !sessions.contains(where: { $0.id == imported.id }) {
                    sessions.append(imported)
                }
            }
            sessions.sort { $0.startTime > $1.startTime }
            saveSessions()
            return true
        }

        // Try single session import
        if let singleSession = try? decoder.decode(TrackingSession.self, from: data) {
            if !sessions.contains(where: { $0.id == singleSession.id }) {
                sessions.insert(singleSession, at: 0)
                sessions.sort { $0.startTime > $1.startTime }
                saveSessions()
            }
            return true
        }

        return false
    }

    /// Get file URL for export
    func getExportFileURL(filename: String) -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent(filename)
    }

    /// Save GPX to file and return URL for sharing
    func saveGPXFile(content: String, filename: String) -> URL? {
        let fileURL = getExportFileURL(filename: filename)
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("[TrackingHistory] Failed to save GPX: \(error)")
            return nil
        }
    }

    /// Save JSON to file and return URL for sharing
    func saveJSONFile(data: Data, filename: String) -> URL? {
        let fileURL = getExportFileURL(filename: filename)
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("[TrackingHistory] Failed to save JSON: \(error)")
            return nil
        }
    }
}
