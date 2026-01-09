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
        let miles = totalDistance / 1609.344
        if miles >= 0.1 {
            return String(format: "%.2f mi", miles)
        }
        // Show feet for very short distances
        let feet = totalDistance * 3.28084
        return String(format: "%.0f ft", feet)
    }

    var averageSpeed: Double? {
        guard duration > 0 else { return nil }
        return totalDistance / duration // m/s
    }

    var formattedAverageSpeed: String {
        guard let speed = averageSpeed else { return "--" }
        let mph = speed * 2.23694 // m/s to mph
        return String(format: "%.1f mph", mph)
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
    var activityType: String?  // Activity type from MotionManager (walking, running, driving, etc.)

    init(from clLocation: CLLocation, activityType: String? = nil) {
        self.latitude = clLocation.coordinate.latitude
        self.longitude = clLocation.coordinate.longitude
        self.timestamp = clLocation.timestamp
        self.altitude = clLocation.altitude >= 0 ? clLocation.altitude : nil
        self.speed = clLocation.speed >= 0 ? clLocation.speed : nil
        self.accuracy = clLocation.horizontalAccuracy >= 0 ? clLocation.horizontalAccuracy : nil
        self.activityType = activityType
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

// MARK: - Daily Stats

struct DailyStats: Identifiable {
    let id: Date  // Start of day (used as unique identifier)
    let date: Date
    let sessions: [TrackingSession]

    var sessionCount: Int {
        sessions.count
    }

    var totalDistance: Double {
        sessions.reduce(0) { $0 + $1.totalDistance }
    }

    var totalDuration: TimeInterval {
        sessions.reduce(0) { $0 + $1.duration }
    }

    var totalPoints: Int {
        sessions.reduce(0) { $0 + $1.pointsCount }
    }

    var formattedDistance: String {
        let miles = totalDistance / 1609.344
        if miles >= 0.1 {
            return String(format: "%.2f mi", miles)
        }
        // Show feet for very short distances
        let feet = totalDistance * 3.28084
        return String(format: "%.0f ft", feet)
    }

    var formattedDuration: String {
        let hours = Int(totalDuration) / 3600
        let minutes = (Int(totalDuration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    var averageSpeed: Double? {
        guard totalDuration > 0 else { return nil }
        return totalDistance / totalDuration
    }

    var formattedAverageSpeed: String {
        guard let speed = averageSpeed else { return "--" }
        let mph = speed * 2.23694 // m/s to mph
        return String(format: "%.1f mph", mph)
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: date)
    }

    var shortFormattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }

    /// All locations from all sessions for the day
    var allLocations: [StoredLocation] {
        sessions.flatMap { $0.locations }
    }
}

// MARK: - History Manager

class TrackingHistoryManager: ObservableObject {
    static let shared = TrackingHistoryManager()

    @Published var sessions: [TrackingSession] = []
    @Published var currentSession: TrackingSession?
    @Published var hasRecoverySession: Bool = false
    @Published var recoverySession: TrackingSession?

    private let storageKey = "trackingSessions"
    private let autoSaveKey = "currentSessionAutoSave"
    private let maxStoredSessions = 10000  // Keep all sessions (effectively unlimited)
    private var autoSaveTimer: Timer?
    private var locationsSinceLastSave = 0

    private init() {
        loadSessions()
        checkForRecoverySession()
    }

    // MARK: - Auto-Save & Recovery

    /// Start auto-save timer (call when tracking starts)
    func startAutoSave() {
        stopAutoSave()
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.saveCurrentSessionToDisk()
        }
        print("[TrackingHistory] Auto-save started (60 second interval)")
    }

    /// Stop auto-save timer (call when tracking stops)
    func stopAutoSave() {
        autoSaveTimer?.invalidate()
        autoSaveTimer = nil
        locationsSinceLastSave = 0
    }

    /// Save current session to disk (called periodically and on app background)
    func saveCurrentSessionToDisk() {
        guard let session = currentSession else {
            UserDefaults.standard.removeObject(forKey: autoSaveKey)
            return
        }
        do {
            let data = try JSONEncoder().encode(session)
            UserDefaults.standard.set(data, forKey: autoSaveKey)
            print("[TrackingHistory] Auto-saved session: \(session.pointsCount) points")
        } catch {
            print("[TrackingHistory] ERROR: Failed to encode session for auto-save: \(error.localizedDescription)")
        }
    }

    /// Load a previously interrupted session
    func loadRecoverySession() -> TrackingSession? {
        guard let data = UserDefaults.standard.data(forKey: autoSaveKey) else { return nil }
        return try? JSONDecoder().decode(TrackingSession.self, from: data)
    }

    /// Clear the recovery session from disk
    func clearRecoverySession() {
        UserDefaults.standard.removeObject(forKey: autoSaveKey)
        hasRecoverySession = false
        recoverySession = nil
        print("[TrackingHistory] Recovery session cleared")
    }

    /// Check for interrupted session on app launch
    private func checkForRecoverySession() {
        if let session = loadRecoverySession() {
            // Only show recovery if it has points and is not currently being tracked
            if session.pointsCount > 0 && currentSession == nil {
                recoverySession = session
                hasRecoverySession = true
                print("[TrackingHistory] Found interrupted session: \(session.pointsCount) points from \(session.startTime)")
            } else {
                clearRecoverySession()
            }
        }
    }

    /// Save the recovered session as a completed session
    func saveRecoveredSession() {
        guard var session = recoverySession else { return }
        session.endTime = session.locations.last?.timestamp ?? Date()
        sessions.insert(session, at: 0)
        saveSessions()
        clearRecoverySession()
        print("[TrackingHistory] Recovered session saved: \(session.pointsCount) points")
    }

    /// Discard the recovered session
    func discardRecoveredSession() {
        clearRecoverySession()
        print("[TrackingHistory] Recovered session discarded")
    }

    // MARK: - Tracking State (for restart detection)

    private let wasTrackingKey = "wasTrackingBeforeTermination"
    private let lastTrackingTimestampKey = "lastTrackingTimestamp"

    /// Save tracking state for restart detection
    func setTrackingState(_ isTracking: Bool) {
        UserDefaults.standard.set(isTracking, forKey: wasTrackingKey)
        if isTracking {
            UserDefaults.standard.set(Date(), forKey: lastTrackingTimestampKey)
        }
        print("[TrackingHistory] Tracking state saved: \(isTracking)")
    }

    /// Check if tracking was active before app termination
    func wasTrackingBeforeTermination() -> Bool {
        return UserDefaults.standard.bool(forKey: wasTrackingKey)
    }

    /// Get timestamp of last tracking activity
    func getLastTrackingTimestamp() -> Date? {
        return UserDefaults.standard.object(forKey: lastTrackingTimestampKey) as? Date
    }

    /// Clear the wasTracking state (after showing alert)
    func clearWasTrackingState() {
        UserDefaults.standard.set(false, forKey: wasTrackingKey)
        print("[TrackingHistory] Cleared wasTracking state")
    }

    // MARK: - Session Management

    func startNewSession() {
        // Clear any existing recovery session when starting fresh
        clearRecoverySession()

        let session = TrackingSession.new()
        currentSession = session
        startAutoSave()  // Start periodic auto-save
        saveCurrentSessionToDisk()  // Immediate save
        print("[TrackingHistory] Started new session: \(session.id)")
    }

    func endCurrentSession() {
        guard var session = currentSession else { return }
        session.endTime = Date()
        sessions.insert(session, at: 0)
        currentSession = nil
        stopAutoSave()  // Stop auto-save timer
        clearRecoverySession()  // Remove auto-save data since session is complete
        trimOldSessions()
        saveSessions()
        print("[TrackingHistory] Ended session: \(session.id) - \(session.pointsCount) points, \(session.formattedDistance)")
    }

    func addLocation(_ location: CLLocation) {
        // Ensure we're on main thread for @Published property updates
        let storedLocation = StoredLocation(from: location)

        if Thread.isMainThread {
            addLocationInternal(storedLocation)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.addLocationInternal(storedLocation)
            }
        }
    }

    private func addLocationInternal(_ storedLocation: StoredLocation) {
        guard var session = currentSession else { return }

        // Calculate distance from last point
        if let lastLocation = session.locations.last {
            let distance = storedLocation.distance(to: lastLocation)
            session.totalDistance += distance
        }

        session.locations.append(storedLocation)
        session.pointsCount += 1
        currentSession = session

        // Save every 10 locations for extra protection
        locationsSinceLastSave += 1
        if locationsSinceLastSave >= 10 {
            saveCurrentSessionToDisk()
            locationsSinceLastSave = 0
        }
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

    // MARK: - Daily Stats

    /// Get sessions grouped by day, sorted by date (most recent first)
    /// Includes the current active session if there is one
    var dailyStats: [DailyStats] {
        let calendar = Calendar.current

        // Combine completed sessions with current session if active
        var allSessions = sessions
        if let current = currentSession {
            allSessions.insert(current, at: 0)
        }

        // Group sessions by day
        let grouped = Dictionary(grouping: allSessions) { session in
            calendar.startOfDay(for: session.startTime)
        }

        // Convert to DailyStats array, sorted by date descending
        return grouped.map { date, daySessions in
            DailyStats(
                id: date,
                date: date,
                sessions: daySessions.sorted { $0.startTime > $1.startTime }
            )
        }
        .sorted { $0.date > $1.date }
    }

    /// Total number of unique days with tracking data
    var totalDaysTracked: Int {
        dailyStats.count
    }

    /// Export all sessions for a specific day to GPX
    func exportDayToGPX(_ dailyStats: DailyStats) -> String {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dayFormatter.string(from: dailyStats.date)

        var gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="Next Track iOS App"
             xmlns="http://www.topografix.com/GPX/1/1"
             xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
             xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">
          <metadata>
            <name>Next Track - \(dateString)</name>
            <desc>\(dailyStats.sessionCount) tracking session(s)</desc>
            <time>\(dateFormatter.string(from: Date()))</time>
          </metadata>

        """

        for session in dailyStats.sessions {
            gpx += "  <trk>\n"
            gpx += "    <name>\(session.name)</name>\n"
            gpx += "    <trkseg>\n"

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

            gpx += "    </trkseg>\n"
            gpx += "  </trk>\n"
        }

        gpx += "</gpx>"

        return gpx
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
        do {
            let data = try JSONEncoder().encode(sessions)
            UserDefaults.standard.set(data, forKey: storageKey)
            print("[TrackingHistory] Saved \(sessions.count) sessions to storage")
        } catch {
            print("[TrackingHistory] ERROR: Failed to save sessions: \(error.localizedDescription)")
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
