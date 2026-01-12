//
//  FullBackupManager.swift
//  Next-track
//
//  Comprehensive backup and restore for ALL app data
//

import Foundation
import Combine
import UIKit

/// Complete app backup structure containing all data
struct FullAppBackup: Codable {
    let version: Int
    let createdAt: Date
    let deviceName: String

    // All data types
    let trackingSessions: [TrackingSession]
    let visitedCountries: [VisitedCountry]
    let visitedCities: [VisitedCity]
    let detectedPlaces: [DetectedPlace]
    let visitedUKCities: [VisitedUKCity]
    let geofenceZones: [GeofenceZone]
    let serverConfig: ServerConfig
    let trackingSettings: TrackingSettings
    let trackingStats: TrackingStats

    // Metadata
    let summary: BackupSummary

    static let currentVersion = 1
}

/// Summary of backup contents for display
struct BackupSummary: Codable {
    let totalSessions: Int
    let totalCountries: Int
    let totalCities: Int
    let totalPlaces: Int
    let totalUKCities: Int
    let totalGeofences: Int
    let totalTrackingPoints: Int
    let totalDistance: Double
    let oldestData: Date?
    let newestData: Date?
}

/// Manages full app backup and restore operations
class FullBackupManager: ObservableObject {
    static let shared = FullBackupManager()

    @Published var isExporting = false
    @Published var isImporting = false
    @Published var lastBackupDate: Date?
    @Published var lastBackupSummary: BackupSummary?
    @Published var error: String?
    @Published var progress: Double = 0

    private let backupDateKey = "lastFullBackupDate"

    private init() {
        loadLastBackupDate()
    }

    // MARK: - Export Full Backup

    /// Create a complete backup of all app data
    func createFullBackup() -> Data? {
        isExporting = true
        progress = 0
        error = nil

        defer {
            isExporting = false
            progress = 1.0
        }

        // Gather all data
        progress = 0.1
        let sessions = TrackingHistoryManager.shared.sessions

        progress = 0.2
        let countries = CountriesManager.shared.visitedCountries

        progress = 0.3
        let cities = CityTracker.shared.visitedCities

        progress = 0.4
        let places = PlaceDetectionManager.shared.detectedPlaces

        progress = 0.5
        let ukCities = UKCitiesManager.shared.visitedCities

        progress = 0.6
        let geofences = GeofenceManager.shared.zones

        progress = 0.7
        let serverConfig = SettingsManager.shared.serverConfig
        let trackingSettings = SettingsManager.shared.trackingSettings
        let trackingStats = SettingsManager.shared.trackingStats

        // Calculate summary
        progress = 0.8
        let totalPoints = sessions.reduce(0) { $0 + $1.pointsCount }
        let totalDistance = sessions.reduce(0.0) { $0 + $1.totalDistance }

        // Find date range
        var allDates: [Date] = []
        allDates.append(contentsOf: sessions.map { $0.startTime })
        allDates.append(contentsOf: countries.compactMap { $0.firstVisitDate })
        allDates.append(contentsOf: cities.map { $0.firstVisitDate })
        allDates.append(contentsOf: places.map { $0.createdAt })
        allDates.append(contentsOf: ukCities.compactMap { $0.firstVisitDate })

        let summary = BackupSummary(
            totalSessions: sessions.count,
            totalCountries: countries.count,
            totalCities: cities.count,
            totalPlaces: places.count,
            totalUKCities: ukCities.count,
            totalGeofences: geofences.count,
            totalTrackingPoints: totalPoints,
            totalDistance: totalDistance,
            oldestData: allDates.min(),
            newestData: allDates.max()
        )

        // Create backup object
        progress = 0.9
        let backup = FullAppBackup(
            version: FullAppBackup.currentVersion,
            createdAt: Date(),
            deviceName: UIDevice.current.name,
            trackingSessions: sessions,
            visitedCountries: countries,
            visitedCities: cities,
            detectedPlaces: places,
            visitedUKCities: ukCities,
            geofenceZones: geofences,
            serverConfig: serverConfig,
            trackingSettings: trackingSettings,
            trackingStats: trackingStats,
            summary: summary
        )

        // Encode to JSON
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(backup)

            // Update last backup info
            lastBackupDate = Date()
            lastBackupSummary = summary
            saveLastBackupDate()

            print("[FullBackup] Created backup: \(data.count) bytes")
            print("[FullBackup] Summary: \(sessions.count) sessions, \(countries.count) countries, \(cities.count) cities, \(places.count) places")

            return data
        } catch {
            self.error = "Failed to create backup: \(error.localizedDescription)"
            print("[FullBackup] Error: \(error)")
            return nil
        }
    }

    /// Save backup to a file and return URL for sharing
    func saveBackupFile() -> URL? {
        guard let data = createFullBackup() else { return nil }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let filename = "BeenThere-FullBackup-\(dateFormatter.string(from: Date())).json"

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        do {
            try data.write(to: tempURL)
            print("[FullBackup] Saved to: \(tempURL.path)")
            return tempURL
        } catch {
            self.error = "Failed to save backup file: \(error.localizedDescription)"
            return nil
        }
    }

    // MARK: - Import Full Backup

    /// Restore from a full backup
    func restoreFromBackup(_ data: Data, mergeMode: MergeMode = .merge) -> RestoreResult {
        isImporting = true
        progress = 0
        error = nil

        defer {
            isImporting = false
            progress = 1.0
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let backup = try decoder.decode(FullAppBackup.self, from: data)

            print("[FullBackup] Restoring backup from \(backup.createdAt)")
            print("[FullBackup] Version: \(backup.version), Device: \(backup.deviceName)")

            var result = RestoreResult()

            // Restore tracking sessions
            progress = 0.15
            result.sessionsRestored = restoreSessions(backup.trackingSessions, mode: mergeMode)

            // Restore countries
            progress = 0.30
            result.countriesRestored = restoreCountries(backup.visitedCountries, mode: mergeMode)

            // Restore cities
            progress = 0.45
            result.citiesRestored = restoreCities(backup.visitedCities, mode: mergeMode)

            // Restore places
            progress = 0.60
            result.placesRestored = restorePlaces(backup.detectedPlaces, mode: mergeMode)

            // Restore UK cities
            progress = 0.75
            result.ukCitiesRestored = restoreUKCities(backup.visitedUKCities, mode: mergeMode)

            // Restore geofences
            progress = 0.85
            result.geofencesRestored = restoreGeofences(backup.geofenceZones, mode: mergeMode)

            // Restore settings (always replace)
            progress = 0.95
            restoreSettings(backup.serverConfig, backup.trackingSettings, backup.trackingStats)
            result.settingsRestored = true

            result.success = true
            print("[FullBackup] Restore complete: \(result)")

            return result

        } catch {
            self.error = "Failed to read backup: \(error.localizedDescription)"
            print("[FullBackup] Restore error: \(error)")
            return RestoreResult(success: false)
        }
    }

    // MARK: - Individual Restore Functions

    private func restoreSessions(_ sessions: [TrackingSession], mode: MergeMode) -> Int {
        let existingIds = Set(TrackingHistoryManager.shared.sessions.map { $0.id })
        var restoredCount = 0

        for session in sessions {
            if mode == .replace || !existingIds.contains(session.id) {
                if mode == .replace {
                    // Remove existing if replacing
                    TrackingHistoryManager.shared.sessions.removeAll { $0.id == session.id }
                }
                TrackingHistoryManager.shared.sessions.append(session)
                restoredCount += 1
            }
        }

        // Sort by date
        TrackingHistoryManager.shared.sessions.sort { $0.startTime > $1.startTime }

        return restoredCount
    }

    private func restoreCountries(_ countries: [VisitedCountry], mode: MergeMode) -> Int {
        let existingCodes = Set(CountriesManager.shared.visitedCountries.map { $0.isoCode.uppercased() })
        var restoredCount = 0

        for country in countries {
            if mode == .replace || !existingCodes.contains(country.isoCode.uppercased()) {
                if mode == .replace {
                    CountriesManager.shared.visitedCountries.removeAll { $0.isoCode.uppercased() == country.isoCode.uppercased() }
                }
                CountriesManager.shared.visitedCountries.append(country)
                restoredCount += 1
            }
        }

        return restoredCount
    }

    private func restoreCities(_ cities: [VisitedCity], mode: MergeMode) -> Int {
        let existingKeys = Set(CityTracker.shared.visitedCities.map { "\($0.name)_\($0.country)" })
        var restoredCount = 0

        for city in cities {
            let key = "\(city.name)_\(city.country)"
            if mode == .replace || !existingKeys.contains(key) {
                if mode == .replace {
                    CityTracker.shared.visitedCities.removeAll { "\($0.name)_\($0.country)" == key }
                }
                CityTracker.shared.visitedCities.append(city)
                restoredCount += 1
            }
        }

        return restoredCount
    }

    private func restorePlaces(_ places: [DetectedPlace], mode: MergeMode) -> Int {
        let existingIds = Set(PlaceDetectionManager.shared.detectedPlaces.map { $0.id })
        var restoredCount = 0

        for place in places {
            if mode == .replace || !existingIds.contains(place.id) {
                if mode == .replace {
                    PlaceDetectionManager.shared.detectedPlaces.removeAll { $0.id == place.id }
                }
                PlaceDetectionManager.shared.detectedPlaces.append(place)
                restoredCount += 1
            }
        }

        return restoredCount
    }

    private func restoreUKCities(_ cities: [VisitedUKCity], mode: MergeMode) -> Int {
        let existingNames = Set(UKCitiesManager.shared.visitedCities.map { $0.name.lowercased() })
        var restoredCount = 0

        for city in cities {
            if mode == .replace || !existingNames.contains(city.name.lowercased()) {
                if mode == .replace {
                    UKCitiesManager.shared.visitedCities.removeAll { $0.name.lowercased() == city.name.lowercased() }
                }
                UKCitiesManager.shared.visitedCities.append(city)
                restoredCount += 1
            }
        }

        return restoredCount
    }

    private func restoreGeofences(_ zones: [GeofenceZone], mode: MergeMode) -> Int {
        let existingIds = Set(GeofenceManager.shared.zones.map { $0.id })
        var restoredCount = 0

        for zone in zones {
            if mode == .replace || !existingIds.contains(zone.id) {
                if mode == .replace {
                    if let existing = GeofenceManager.shared.zones.first(where: { $0.id == zone.id }) {
                        GeofenceManager.shared.deleteZone(existing)
                    }
                }
                GeofenceManager.shared.addZone(zone)
                restoredCount += 1
            }
        }

        return restoredCount
    }

    private func restoreSettings(_ config: ServerConfig, _ settings: TrackingSettings, _ stats: TrackingStats) {
        SettingsManager.shared.updateServerConfig(config)
        SettingsManager.shared.updateTrackingSettings(settings)
        // Stats: keep the most recent successful send date, and higher point counts
        let currentStats = SettingsManager.shared.trackingStats
        var mergedStats = TrackingStats()
        mergedStats.pointsSentToday = max(currentStats.pointsSentToday, stats.pointsSentToday)
        mergedStats.totalDistanceToday = max(currentStats.totalDistanceToday, stats.totalDistanceToday)
        mergedStats.lastSentTimestamp = [currentStats.lastSentTimestamp, stats.lastSentTimestamp].compactMap { $0 }.max()
        mergedStats.lastSuccessfulSend = [currentStats.lastSuccessfulSend, stats.lastSuccessfulSend].compactMap { $0 }.max()
        SettingsManager.shared.trackingStats = mergedStats
    }

    // MARK: - Persistence

    private func loadLastBackupDate() {
        lastBackupDate = UserDefaults.standard.object(forKey: backupDateKey) as? Date
    }

    private func saveLastBackupDate() {
        UserDefaults.standard.set(lastBackupDate, forKey: backupDateKey)
    }

    // MARK: - Utility

    /// Get current data summary without creating a backup
    func getCurrentDataSummary() -> BackupSummary {
        let sessions = TrackingHistoryManager.shared.sessions
        let countries = CountriesManager.shared.visitedCountries
        let cities = CityTracker.shared.visitedCities
        let places = PlaceDetectionManager.shared.detectedPlaces
        let ukCities = UKCitiesManager.shared.visitedCities
        let geofences = GeofenceManager.shared.zones

        let totalPoints = sessions.reduce(0) { $0 + $1.pointsCount }
        let totalDistance = sessions.reduce(0.0) { $0 + $1.totalDistance }

        var allDates: [Date] = []
        allDates.append(contentsOf: sessions.map { $0.startTime })
        allDates.append(contentsOf: countries.compactMap { $0.firstVisitDate })
        allDates.append(contentsOf: cities.map { $0.firstVisitDate })

        return BackupSummary(
            totalSessions: sessions.count,
            totalCountries: countries.count,
            totalCities: cities.count,
            totalPlaces: places.count,
            totalUKCities: ukCities.count,
            totalGeofences: geofences.count,
            totalTrackingPoints: totalPoints,
            totalDistance: totalDistance,
            oldestData: allDates.min(),
            newestData: allDates.max()
        )
    }
}

// MARK: - Supporting Types

enum MergeMode {
    case merge    // Add new items, keep existing
    case replace  // Replace existing items with backup data
}

struct RestoreResult {
    var success: Bool = false
    var sessionsRestored: Int = 0
    var countriesRestored: Int = 0
    var citiesRestored: Int = 0
    var placesRestored: Int = 0
    var ukCitiesRestored: Int = 0
    var geofencesRestored: Int = 0
    var settingsRestored: Bool = false

    var totalItemsRestored: Int {
        sessionsRestored + countriesRestored + citiesRestored + placesRestored + ukCitiesRestored + geofencesRestored
    }
}
