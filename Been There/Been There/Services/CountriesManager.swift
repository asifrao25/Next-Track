//
//  CountriesManager.swift
//  Next-track
//
//  Service for managing visited countries with auto-detection and manual entry
//

import Foundation
import Combine
import CoreLocation

class CountriesManager: ObservableObject {
    static let shared = CountriesManager()

    // MARK: - Published Properties

    @Published var visitedCountries: [VisitedCountry] = []
    @Published var countryGeoJSON: CountryGeoJSON?
    @Published var isLoading: Bool = false
    @Published var isSyncing: Bool = false

    // MARK: - Private Properties

    private let storageKey = "visitedCountries"
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        loadGeoJSON()
        loadCountries()
        setupCityTrackerSync()
    }

    // MARK: - GeoJSON Loading

    func loadGeoJSON() {
        guard let url = Bundle.main.url(forResource: "countries", withExtension: "geojson"),
              let data = try? Data(contentsOf: url) else {
            print("[CountriesManager] GeoJSON file not found in bundle - using fallback country data")
            return
        }

        do {
            countryGeoJSON = try JSONDecoder().decode(CountryGeoJSON.self, from: data)
            print("[CountriesManager] Loaded \(countryGeoJSON?.features.count ?? 0) countries from GeoJSON")
        } catch {
            print("[CountriesManager] GeoJSON parsing error: \(error)")
        }
    }

    // MARK: - City Tracker Sync

    private func setupCityTrackerSync() {
        // Subscribe to CityTracker changes
        CityTracker.shared.$visitedCities
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] cities in
                self?.syncWithCities(cities)
            }
            .store(in: &cancellables)
    }

    func syncWithCities(_ cities: [VisitedCity]) {
        guard !cities.isEmpty else { return }

        isSyncing = true

        // Group cities by country code
        let citiesByCountry = Dictionary(grouping: cities) { city in
            city.countryCode?.uppercased() ?? "UNKNOWN"
        }

        var hasChanges = false

        for (countryCode, countryCities) in citiesByCountry {
            guard countryCode != "UNKNOWN", countryCode != "-99" else { continue }

            let countryName = countryCities.first?.country ?? countryCode
            let firstVisit = countryCities.map { $0.firstVisitDate }.min()
            let lastVisit = countryCities.map { $0.lastVisitDate }.max()

            if let existingIndex = visitedCountries.firstIndex(where: { $0.isoCode.uppercased() == countryCode }) {
                // Update existing country
                var updated = visitedCountries[existingIndex]
                updated.isAutoDetected = true
                updated.autoDetectedCityCount = countryCities.count

                // Update dates if auto-detected dates are earlier/later
                if let first = firstVisit,
                   first < (updated.firstVisitDate ?? Date.distantFuture) {
                    updated.firstVisitDate = first
                }
                if let last = lastVisit,
                   last > (updated.lastVisitDate ?? Date.distantPast) {
                    updated.lastVisitDate = last
                }
                updated.updatedAt = Date()
                visitedCountries[existingIndex] = updated
                hasChanges = true
            } else {
                // Add new auto-detected country
                let continent = getContinent(for: countryCode)
                let newCountry = VisitedCountry(
                    name: countryName,
                    isoCode: countryCode,
                    continent: continent,
                    isAutoDetected: true,
                    isManuallyAdded: false,
                    firstVisitDate: firstVisit,
                    lastVisitDate: lastVisit,
                    autoDetectedCityCount: countryCities.count
                )
                visitedCountries.append(newCountry)
                hasChanges = true
            }
        }

        if hasChanges {
            saveCountries()
        }

        isSyncing = false
        print("[CountriesManager] Synced \(citiesByCountry.count) countries from \(cities.count) cities")
    }

    // MARK: - Manual Entry

    func addManualCountry(name: String, isoCode: String, trip: CountryTrip) {
        if let existingIndex = visitedCountries.firstIndex(where: { $0.isoCode.uppercased() == isoCode.uppercased() }) {
            // Add trip to existing country
            var updated = visitedCountries[existingIndex]
            updated.isManuallyAdded = true
            updated.trips.append(trip)

            // Update dates
            if let tripDate = trip.effectiveDate {
                if tripDate < (updated.firstVisitDate ?? Date.distantFuture) {
                    updated.firstVisitDate = tripDate
                }
                if tripDate > (updated.lastVisitDate ?? Date.distantPast) {
                    updated.lastVisitDate = tripDate
                }
            }
            updated.updatedAt = Date()
            visitedCountries[existingIndex] = updated
        } else {
            // Create new manually added country
            let continent = getContinent(for: isoCode)
            let tripDate = trip.effectiveDate

            let newCountry = VisitedCountry(
                name: name,
                isoCode: isoCode.uppercased(),
                continent: continent,
                isAutoDetected: false,
                isManuallyAdded: true,
                firstVisitDate: tripDate,
                lastVisitDate: tripDate,
                trips: [trip]
            )
            visitedCountries.append(newCountry)
        }

        saveCountries()
        HapticManager.shared.success()
    }

    func addTrip(_ trip: CountryTrip, to countryId: UUID) {
        guard let index = visitedCountries.firstIndex(where: { $0.id == countryId }) else { return }

        var updated = visitedCountries[index]
        updated.trips.append(trip)
        updated.isManuallyAdded = true

        // Update dates
        if let tripDate = trip.effectiveDate {
            if tripDate < (updated.firstVisitDate ?? Date.distantFuture) {
                updated.firstVisitDate = tripDate
            }
            if tripDate > (updated.lastVisitDate ?? Date.distantPast) {
                updated.lastVisitDate = tripDate
            }
        }
        updated.updatedAt = Date()
        visitedCountries[index] = updated
        saveCountries()
    }

    func updateTrip(_ trip: CountryTrip, for countryId: UUID) {
        guard let countryIndex = visitedCountries.firstIndex(where: { $0.id == countryId }),
              let tripIndex = visitedCountries[countryIndex].trips.firstIndex(where: { $0.id == trip.id })
        else { return }

        visitedCountries[countryIndex].trips[tripIndex] = trip
        visitedCountries[countryIndex].updatedAt = Date()
        saveCountries()
    }

    func deleteTrip(_ tripId: UUID, from countryId: UUID) {
        guard let countryIndex = visitedCountries.firstIndex(where: { $0.id == countryId }) else { return }

        visitedCountries[countryIndex].trips.removeAll { $0.id == tripId }
        visitedCountries[countryIndex].updatedAt = Date()

        // If no trips and not auto-detected, remove the country
        if visitedCountries[countryIndex].trips.isEmpty &&
           !visitedCountries[countryIndex].isAutoDetected {
            visitedCountries.remove(at: countryIndex)
        }

        saveCountries()
    }

    func deleteCountry(_ countryId: UUID) {
        visitedCountries.removeAll { $0.id == countryId }
        saveCountries()
    }

    // MARK: - Time Tracking

    /// Start a visit session when entering a country
    func startVisitSession(isoCode: String, timestamp: Date = Date()) {
        guard var country = country(for: isoCode) else {
            print("[CountriesManager] Cannot start session - country not found: \(isoCode)")
            return
        }

        // Check if there's already an active session
        if let activeSession = country.activeSession {
            print("[CountriesManager] Session already active since \(activeSession.entryDate)")
            return
        }

        // Start new session
        let session = VisitSession(entryDate: timestamp)
        country.visitSessions.append(session)
        country.updatedAt = Date()

        updateCountry(country)
        print("[CountriesManager] Started visit session in \(country.name) at \(timestamp)")
    }

    /// End a visit session when leaving a country
    func endVisitSession(isoCode: String, timestamp: Date = Date()) {
        guard var country = country(for: isoCode) else {
            print("[CountriesManager] Cannot end session - country not found: \(isoCode)")
            return
        }

        // Find the active session
        guard let activeIndex = country.visitSessions.firstIndex(where: { $0.isActive }) else {
            print("[CountriesManager] No active session to end")
            return
        }

        // End the session
        country.visitSessions[activeIndex].exitDate = timestamp

        // Recalculate total time
        country.totalTimeSpent = calculateTotalTime(sessions: country.visitSessions)
        country.lastVisitDate = timestamp
        country.updatedAt = Date()

        updateCountry(country)
        print("[CountriesManager] Ended visit session in \(country.name). Total time: \(country.formattedTimeSpent)")
    }

    /// Calculate total time from all sessions
    private func calculateTotalTime(sessions: [VisitSession]) -> TimeInterval {
        sessions.reduce(0) { $0 + $1.duration }
    }

    /// Add a manual visit session (for historical data)
    func addManualVisitSession(isoCode: String, entryDate: Date, exitDate: Date) {
        guard var country = country(for: isoCode) else {
            print("[CountriesManager] Cannot add session - country not found: \(isoCode)")
            return
        }

        let session = VisitSession(entryDate: entryDate, exitDate: exitDate)
        country.visitSessions.append(session)
        country.totalTimeSpent = calculateTotalTime(sessions: country.visitSessions)

        // Update first/last visit dates
        if entryDate < (country.firstVisitDate ?? Date.distantFuture) {
            country.firstVisitDate = entryDate
        }
        if exitDate > (country.lastVisitDate ?? Date.distantPast) {
            country.lastVisitDate = exitDate
        }

        country.updatedAt = Date()
        updateCountry(country)
        print("[CountriesManager] Added manual session to \(country.name). Duration: \(session.formattedDuration)")
    }

    /// Delete a visit session
    func deleteVisitSession(_ sessionId: UUID, from countryId: UUID) {
        guard let countryIndex = visitedCountries.firstIndex(where: { $0.id == countryId }) else { return }

        visitedCountries[countryIndex].visitSessions.removeAll { $0.id == sessionId }
        visitedCountries[countryIndex].totalTimeSpent = calculateTotalTime(sessions: visitedCountries[countryIndex].visitSessions)
        visitedCountries[countryIndex].updatedAt = Date()
        saveCountries()
    }

    /// Get total time spent across all countries
    var totalTimeAllCountries: TimeInterval {
        visitedCountries.reduce(0) { $0 + $1.totalTimeSpent }
    }

    var formattedTotalTimeAllCountries: String {
        let totalSeconds = Int(totalTimeAllCountries)
        let days = totalSeconds / 86400
        let hours = (totalSeconds % 86400) / 3600

        if days > 0 {
            return "\(days)d \(hours)h"
        } else if hours > 0 {
            return "\(hours) hours"
        } else {
            let minutes = totalSeconds / 60
            return "\(minutes) min"
        }
    }

    /// Helper function to update a country in the array
    private func updateCountry(_ country: VisitedCountry) {
        if let index = visitedCountries.firstIndex(where: { $0.id == country.id }) {
            visitedCountries[index] = country
            saveCountries()
        }
    }

    // MARK: - Statistics

    var totalCountries: Int { visitedCountries.count }

    var autoDetectedCount: Int {
        visitedCountries.filter { $0.isAutoDetected }.count
    }

    var manuallyAddedOnlyCount: Int {
        visitedCountries.filter { $0.isManuallyAdded && !$0.isAutoDetected }.count
    }

    func countriesByContinent() -> [String: [VisitedCountry]] {
        Dictionary(grouping: visitedCountries) { $0.continent ?? "Unknown" }
    }

    func countByContinent() -> [(continent: String, count: Int)] {
        countriesByContinent()
            .map { (continent: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
    }

    /// Approximately 195 recognized sovereign countries
    var percentageOfWorld: Double {
        Double(totalCountries) / 195.0 * 100.0
    }

    // MARK: - Query Methods

    func country(for isoCode: String) -> VisitedCountry? {
        visitedCountries.first { $0.isoCode.uppercased() == isoCode.uppercased() }
    }

    func isCountryVisited(_ isoCode: String) -> Bool {
        visitedCountries.contains { $0.isoCode.uppercased() == isoCode.uppercased() }
    }

    func countries(sortedBy option: CountrySortOption) -> [VisitedCountry] {
        option.sort(visitedCountries)
    }

    func searchCountries(_ query: String) -> [VisitedCountry] {
        guard !query.isEmpty else { return visitedCountries }
        return visitedCountries.filter { country in
            country.name.localizedCaseInsensitiveContains(query) ||
            country.isoCode.localizedCaseInsensitiveContains(query) ||
            (country.continent?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    // MARK: - Country Data Access

    /// Get all countries from static data
    func getAllCountries() -> [CountryData] {
        CountryData.allCountries
    }

    /// Get unvisited countries
    func getUnvisitedCountries() -> [CountryData] {
        let visitedCodes = Set(visitedCountries.map { $0.isoCode.uppercased() })
        return CountryData.allCountries.filter { !visitedCodes.contains($0.isoCode.uppercased()) }
    }

    /// Get coordinate for a country
    func getCountryCenter(isoCode: String) -> CLLocationCoordinate2D? {
        // First try GeoJSON centroid
        if let feature = countryGeoJSON?.features.first(where: {
            $0.properties.isoA2?.uppercased() == isoCode.uppercased()
        }) {
            return GeoJSONParser.calculateCentroid(from: feature.geometry)
        }

        // Fallback to static data
        return CountryData.allCountries
            .first { $0.isoCode.uppercased() == isoCode.uppercased() }?
            .coordinate
    }

    private func getContinent(for isoCode: String) -> String? {
        // Try GeoJSON first
        if let continent = countryGeoJSON?.features
            .first(where: { $0.properties.isoA2?.uppercased() == isoCode.uppercased() })?
            .properties.continent {
            return continent
        }

        // Fallback to static data
        return CountryData.allCountries
            .first { $0.isoCode.uppercased() == isoCode.uppercased() }?
            .continent
    }

    // MARK: - Persistence

    internal func saveCountries() {
        do {
            let data = try JSONEncoder().encode(visitedCountries)
            UserDefaults.standard.set(data, forKey: storageKey)
            print("[CountriesManager] Saved \(visitedCountries.count) countries")

            // Sync to iCloud
            iCloudSyncManager.shared.syncCountriesNow()
        } catch {
            print("[CountriesManager] Failed to save: \(error)")
        }
    }

    private func loadCountries() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            print("[CountriesManager] No saved countries found")
            return
        }

        do {
            visitedCountries = try JSONDecoder().decode([VisitedCountry].self, from: data)
            print("[CountriesManager] Loaded \(visitedCountries.count) countries")
        } catch {
            print("[CountriesManager] Failed to load: \(error)")
        }
    }

    // MARK: - Debug / Reset

    func clearAllCountries() {
        visitedCountries.removeAll()
        saveCountries()
    }

    func forceSyncFromCities() {
        syncWithCities(CityTracker.shared.visitedCities)
    }

    // MARK: - Historical Import

    /// Import historical countries from CSV analysis (one-time import)
    /// Returns the number of countries successfully imported
    func importHistoricalCountries() -> Int {
        var importedCount = 0

        // Helper to create dates from string
        func makeDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
            var components = DateComponents()
            components.year = year
            components.month = month
            components.day = day
            components.hour = hour
            components.minute = minute
            components.timeZone = TimeZone.current
            return Calendar.current.date(from: components) ?? Date()
        }

        // Historical visits extracted from Visits.csv and LC_export.csv
        // Format: (country name, ISO code, [(entry date, exit date)])
        let historicalVisits: [(name: String, iso: String, sessions: [(entry: Date, exit: Date)])] = [
            // Spain - 2 trips (Tenerife Feb 2025, Malaga Nov-Dec 2025)
            ("Spain", "ES", [
                (makeDate(2025, 2, 14, 3, 10), makeDate(2025, 2, 16, 19, 21)),
                (makeDate(2025, 11, 29, 19, 31), makeDate(2025, 12, 1, 20, 12))
            ]),
            // Denmark (May 2025)
            ("Denmark", "DK", [
                (makeDate(2025, 5, 9, 18, 42), makeDate(2025, 5, 11, 18, 48))
            ]),
            // Czech Republic - Prague transit (May 2025)
            ("Czech Republic", "CZ", [
                (makeDate(2025, 5, 9, 13, 49), makeDate(2025, 5, 9, 13, 59))
            ]),
            // Hungary - Budapest (May 2025)
            ("Hungary", "HU", [
                (makeDate(2025, 5, 5, 22, 17), makeDate(2025, 5, 7, 19, 12))
            ]),
            // Qatar - transits (Dec 2019, Apr 2024)
            ("Qatar", "QA", [
                (makeDate(2019, 12, 22, 19, 28), makeDate(2019, 12, 22, 20, 49)),
                (makeDate(2024, 4, 20, 19, 22), makeDate(2024, 4, 20, 19, 37))
            ]),
            // Pakistan - 5 trips
            ("Pakistan", "PK", [
                (makeDate(2019, 12, 22, 22, 0), makeDate(2019, 12, 29, 10, 53)),
                (makeDate(2021, 6, 22, 4, 54), makeDate(2021, 7, 1, 6, 4)),
                (makeDate(2021, 11, 25, 18, 43), makeDate(2021, 12, 5, 16, 31)),
                (makeDate(2022, 11, 6, 7, 17), makeDate(2022, 11, 14, 0, 16)),
                (makeDate(2024, 5, 5, 0, 10), makeDate(2024, 5, 19, 18, 19))
            ]),
            // Bahrain - transits (Jun-Jul 2021)
            ("Bahrain", "BH", [
                (makeDate(2021, 6, 21, 19, 22), makeDate(2021, 6, 21, 22, 4)),
                (makeDate(2021, 7, 1, 9, 46), makeDate(2021, 7, 1, 10, 4))
            ]),
            // UAE - Dubai (Jan 2023)
            ("United Arab Emirates", "AE", [
                (makeDate(2023, 1, 17, 1, 25), makeDate(2023, 1, 22, 7, 53))
            ]),
            // Saudi Arabia - Medina/Umrah (Jan-Feb 2024)
            ("Saudi Arabia", "SA", [
                (makeDate(2024, 1, 30, 2, 11), makeDate(2024, 2, 10, 13, 26))
            ]),
            // Turkey - Antalya & Istanbul (Sep 2023)
            ("Turkey", "TR", [
                (makeDate(2023, 9, 6, 19, 40), makeDate(2023, 9, 11, 12, 0))
            ]),
            // Switzerland - Interlaken (Jul 2024)
            ("Switzerland", "CH", [
                (makeDate(2024, 7, 25, 19, 48), makeDate(2024, 7, 26, 9, 25))
            ])
        ]

        for visit in historicalVisits {
            // Skip if country already exists
            guard !isCountryVisited(visit.iso) else {
                print("[CountriesManager] Skipping \(visit.name) - already exists")
                continue
            }

            // Get first session for the trip date
            guard let firstSession = visit.sessions.first else { continue }

            // Create a trip for the country
            let trip = CountryTrip(
                visitDate: firstSession.entry,
                tripName: "Historical Import"
            )

            // Add the country
            addManualCountry(name: visit.name, isoCode: visit.iso, trip: trip)

            // Add all visit sessions for time tracking
            for session in visit.sessions {
                addManualVisitSession(
                    isoCode: visit.iso,
                    entryDate: session.entry,
                    exitDate: session.exit
                )
            }

            importedCount += 1
            print("[CountriesManager] Imported \(visit.name) with \(visit.sessions.count) session(s)")
        }

        if importedCount > 0 {
            HapticManager.shared.success()
        }

        print("[CountriesManager] Historical import complete: \(importedCount) countries imported")
        return importedCount
    }
}
