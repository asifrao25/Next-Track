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
                   updated.firstVisitDate == nil || first < updated.firstVisitDate! {
                    updated.firstVisitDate = first
                }
                if let last = lastVisit,
                   updated.lastVisitDate == nil || last > updated.lastVisitDate! {
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
                if updated.firstVisitDate == nil || tripDate < updated.firstVisitDate! {
                    updated.firstVisitDate = tripDate
                }
                if updated.lastVisitDate == nil || tripDate > updated.lastVisitDate! {
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
            if updated.firstVisitDate == nil || tripDate < updated.firstVisitDate! {
                updated.firstVisitDate = tripDate
            }
            if updated.lastVisitDate == nil || tripDate > updated.lastVisitDate! {
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
        if country.firstVisitDate == nil || entryDate < country.firstVisitDate! {
            country.firstVisitDate = entryDate
        }
        if country.lastVisitDate == nil || exitDate > country.lastVisitDate! {
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

    private func saveCountries() {
        do {
            let data = try JSONEncoder().encode(visitedCountries)
            UserDefaults.standard.set(data, forKey: storageKey)
            print("[CountriesManager] Saved \(visitedCountries.count) countries")
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
}
