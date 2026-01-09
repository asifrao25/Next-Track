//
//  UKCitiesManager.swift
//  Next-track
//
//  Manages visited UK cities data with persistence
//

import Foundation
import CoreLocation
import Combine
import UserNotifications

class UKCitiesManager: ObservableObject {
    static let shared = UKCitiesManager()

    @Published var visitedCities: [VisitedUKCity] = []
    @Published var isLoading: Bool = false
    @Published var ladGeoJSON: UKLADGeoJSON?
    @Published var lastDetectedLAD: String?  // For UI display of current location

    private let storageKey = "visitedUKCities"
    private var cancellables = Set<AnyCancellable>()

    // Auto-detection state
    private var lastProcessedTime: Date = .distantPast
    private var lastDetectedLADName: String?
    private var currentSessionLADs: Set<String> = []  // LADs visited this session (prevents duplicate notifications)
    private let processingInterval: TimeInterval = 5.0  // Rate limit: process every 5 seconds max

    // Cached bounding boxes for fast rejection testing
    private var ladBoundingBoxes: [(feature: UKLADFeature, box: (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double))] = []

    // UK bounding box for initial quick check
    private let ukBoundingBox = (minLat: 49.9, maxLat: 60.9, minLon: -8.2, maxLon: 1.8)

    // Mapping from city names to LAD names (for cases where they differ)
    private let cityToLADMapping: [String: String] = [
        "Bristol": "Bristol, City of",
        "Hull": "Kingston upon Hull, City of",
        "Hereford": "Herefordshire, County of",
        "London": "City of London",  // Note: Greater London is split into boroughs
        "Stoke-on-Trent": "Stoke-on-Trent",
        "Edinburgh": "City of Edinburgh",
        "Glasgow": "Glasgow City",
        "Aberdeen": "Aberdeen City",
        "Dundee": "Dundee City",
        "Brighton": "Brighton and Hove",
    ]

    private init() {
        loadCities()
        loadLADBoundaries()
    }

    // MARK: - GeoJSON Loading

    /// Load UK LAD boundary data from GeoJSON file
    func loadLADBoundaries() {
        guard let url = Bundle.main.url(forResource: "uk_lads", withExtension: "geojson") else {
            print("[UKCitiesManager] uk_lads.geojson not found in bundle")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            ladGeoJSON = try JSONDecoder().decode(UKLADGeoJSON.self, from: data)
            print("[UKCitiesManager] Loaded \(ladGeoJSON?.features.count ?? 0) LAD boundaries")

            // Pre-calculate bounding boxes for fast rejection testing
            cacheBoundingBoxes()
        } catch {
            print("[UKCitiesManager] Failed to load LAD boundaries: \(error)")
        }
    }

    /// Pre-calculate bounding boxes for all LADs (performance optimization)
    private func cacheBoundingBoxes() {
        guard let features = ladGeoJSON?.features else { return }

        ladBoundingBoxes = features.compactMap { feature -> (UKLADFeature, (Double, Double, Double, Double))? in
            guard let box = GeoJSONParser.boundingBox(for: feature.geometry) else { return nil }
            return (feature, box)
        }

        print("[UKCitiesManager] Cached \(ladBoundingBoxes.count) LAD bounding boxes")
    }

    // MARK: - Automatic Location Processing

    /// Process a location update and automatically detect UK city/LAD visits
    /// Call this from the location update pipeline for automatic tracking
    func processLocation(_ location: CLLocation) {
        let now = Date()

        // Rate limiting - don't process too frequently
        guard now.timeIntervalSince(lastProcessedTime) >= processingInterval else {
            return
        }
        lastProcessedTime = now

        let coordinate = location.coordinate

        // Quick check: is this even in the UK?
        guard isCoordinateInUK(coordinate) else {
            // Clear last detected LAD when leaving UK
            if lastDetectedLADName != nil {
                DispatchQueue.main.async {
                    self.lastDetectedLAD = nil
                }
                lastDetectedLADName = nil
            }
            return
        }

        // Find which LAD the coordinate is in
        guard let detectedLAD = findLAD(containing: coordinate) else {
            return
        }

        let ladName = detectedLAD.properties.name

        // Update last detected LAD for UI
        if ladName != lastDetectedLADName {
            lastDetectedLADName = ladName
            DispatchQueue.main.async {
                self.lastDetectedLAD = ladName
            }
        }

        // Check if this is a new LAD or existing one
        // Also check reverse mapping (e.g., user added "Bristol" but LAD is "Bristol, City of")
        if let existingCity = getCityForLAD(ladName) {
            // Already visited - update last visit date and increment count
            updateVisit(for: existingCity, at: now)
        } else {
            // New LAD - add it automatically!
            addAutoDetectedLAD(detectedLAD, at: now, coordinate: coordinate)
        }
    }

    /// Quick check if coordinate is within UK bounding box
    private func isCoordinateInUK(_ coordinate: CLLocationCoordinate2D) -> Bool {
        return coordinate.latitude >= ukBoundingBox.minLat &&
               coordinate.latitude <= ukBoundingBox.maxLat &&
               coordinate.longitude >= ukBoundingBox.minLon &&
               coordinate.longitude <= ukBoundingBox.maxLon
    }

    /// Find which LAD contains the given coordinate (optimized with bounding boxes)
    private func findLAD(containing coordinate: CLLocationCoordinate2D) -> UKLADFeature? {
        // First pass: check bounding boxes (fast)
        let candidates = ladBoundingBoxes.filter { _, box in
            GeoJSONParser.isPoint(coordinate, inBoundingBox: box)
        }

        // Second pass: precise point-in-polygon check (slower, but only on candidates)
        for (feature, _) in candidates {
            if GeoJSONParser.isPoint(coordinate, insideLADGeometry: feature.geometry) {
                return feature
            }
        }

        return nil
    }

    /// Update visit info for an existing city
    private func updateVisit(for city: VisitedUKCity, at date: Date) {
        guard let index = visitedCities.firstIndex(where: { $0.id == city.id }) else { return }

        // Only update if this is a new day or significant time has passed
        let calendar = Calendar.current
        let currentDay = calendar.startOfDay(for: date)

        // Check if we should increment visit count (new day since last visit)
        let shouldIncrement: Bool
        if let lastVisit = city.lastVisitDate {
            let lastVisitDay = calendar.startOfDay(for: lastVisit)
            shouldIncrement = currentDay > lastVisitDay
        } else {
            // No last visit date recorded - always update
            shouldIncrement = true
        }

        if shouldIncrement {
            // New day - increment visit count
            var updatedCity = city
            updatedCity.visitCount += 1
            updatedCity.lastVisitDate = date

            DispatchQueue.main.async {
                self.visitedCities[index] = updatedCity
                self.saveCities()
            }

            print("[UKCitiesManager] Updated visit for \(city.name) - now \(updatedCity.visitCount) visits")
        }
    }

    /// Add a newly auto-detected LAD as a visited city
    private func addAutoDetectedLAD(_ feature: UKLADFeature, at date: Date, coordinate: CLLocationCoordinate2D) {
        let ladName = feature.properties.name

        // Determine region name from code
        let regionName = regionFromLADCode(feature.properties.region)

        // Calculate centroid for the city record
        let centroid = GeoJSONParser.calculateCentroid(from: feature.geometry) ?? coordinate

        // Create the new visited city
        let newCity = VisitedUKCity(
            name: ladName,
            region: regionName,
            latitude: centroid.latitude,
            longitude: centroid.longitude,
            radius: 5000,  // Default radius
            visitCount: 1,
            firstVisitDate: date,
            lastVisitDate: date,
            places: []
        )

        DispatchQueue.main.async {
            self.visitedCities.append(newCity)
            self.saveCities()

            // Trigger haptic and notification for new discovery
            HapticManager.shared.success()

            // Only notify if we haven't already notified for this LAD this session
            if !self.currentSessionLADs.contains(ladName) {
                self.currentSessionLADs.insert(ladName)
                self.sendNewLADNotification(ladName, region: regionName)
            }
        }

        print("[UKCitiesManager] Auto-detected NEW UK area: \(ladName) (\(regionName))")
    }

    /// Send a local notification for discovering a new UK area
    private func sendNewLADNotification(_ ladName: String, region: String) {
        let content = UNMutableNotificationContent()
        content.title = "New UK Area Discovered!"
        content.body = "You've visited \(ladName), \(region) for the first time."
        content.sound = .default
        content.categoryIdentifier = "UK_CITY_DISCOVERED"

        let request = UNNotificationRequest(
            identifier: "uk-city-\(ladName)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil  // Deliver immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[UKCitiesManager] Failed to send notification: \(error)")
            }
        }
    }

    /// Reset session tracking (call when app becomes active or tracking starts)
    func resetSessionTracking() {
        currentSessionLADs.removeAll()
        lastDetectedLADName = nil
        lastDetectedLAD = nil
    }

    /// Public method to find LAD at a coordinate (for long-press feature)
    func findLADAtCoordinate(_ coordinate: CLLocationCoordinate2D) -> UKLADFeature? {
        return findLAD(containing: coordinate)
    }

    /// Manually add an area from long-press on map
    func addManualAreaFromMap(
        coordinate: CLLocationCoordinate2D,
        ladFeature: UKLADFeature?,
        customName: String?
    ) {
        let now = Date()

        if let feature = ladFeature {
            // Use the detected LAD
            let ladName = feature.properties.name

            // Check if already visited
            guard getCityForLAD(ladName) == nil else {
                print("[UKCitiesManager] LAD \(ladName) already visited")
                return
            }

            addAutoDetectedLAD(feature, at: now, coordinate: coordinate)
        } else if let name = customName, !name.isEmpty {
            // Custom area without LAD boundary
            let newCity = VisitedUKCity(
                name: name,
                region: "United Kingdom",
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                radius: 3000,  // Default radius for custom areas
                visitCount: 1,
                firstVisitDate: now,
                lastVisitDate: now,
                places: []
            )

            DispatchQueue.main.async {
                self.visitedCities.append(newCity)
                self.saveCities()
                HapticManager.shared.success()
            }

            print("[UKCitiesManager] Manually added custom area: \(name)")
        }
    }

    /// Find a visited city that matches a LAD name (handles mapping both ways)
    /// This prevents duplicates when LAD names differ from UKCityData names
    private func getCityForLAD(_ ladName: String) -> VisitedUKCity? {
        // Direct match first
        if let city = getCity(named: ladName) {
            return city
        }

        // Check reverse mapping: LAD name -> City name
        // e.g., "Bristol, City of" should match "Bristol"
        for (cityName, mappedLAD) in cityToLADMapping {
            if mappedLAD == ladName {
                // Found a mapping - check if user has the city
                if let city = getCity(named: cityName) {
                    return city
                }
            }
        }

        // Check partial matches (e.g., "Nottingham" in LAD should match "Nottingham" in cities)
        for city in visitedCities {
            // Check if LAD name contains city name or vice versa
            if ladName.localizedCaseInsensitiveContains(city.name) ||
               city.name.localizedCaseInsensitiveContains(ladName) {
                return city
            }
        }

        return nil
    }

    /// Get LAD name for a city (using mapping or direct match)
    func getLADName(for cityName: String) -> String {
        // Check if there's a mapping
        if let mappedName = cityToLADMapping[cityName] {
            return mappedName
        }
        // Otherwise return the city name as-is
        return cityName
    }

    /// Find LAD feature for a city
    func getLADFeature(for cityName: String) -> UKLADFeature? {
        guard let features = ladGeoJSON?.features else { return nil }

        let ladName = getLADName(for: cityName)

        // Try exact match first
        if let feature = features.first(where: { $0.properties.name == ladName }) {
            return feature
        }

        // Try contains match (e.g., "Nottingham" matches "Nottingham")
        if let feature = features.first(where: { $0.properties.name.contains(cityName) || cityName.contains($0.properties.name) }) {
            return feature
        }

        return nil
    }

    /// Get set of visited city names that have LAD boundaries
    var visitedLADNames: Set<String> {
        Set(visitedCities.compactMap { city -> String? in
            let ladName = getLADName(for: city.name)
            // Check if this LAD exists in our GeoJSON
            if ladGeoJSON?.features.contains(where: { $0.properties.name == ladName }) == true {
                return ladName
            }
            // Try contains match
            if ladGeoJSON?.features.contains(where: { $0.properties.name.contains(city.name) || city.name.contains($0.properties.name) }) == true {
                return city.name
            }
            return nil
        })
    }

    // MARK: - All UK Areas (Combined)

    /// Returns all UK areas - combining UKCityData.allCities with LAD names
    /// This provides a comprehensive list for manual city addition
    func getAllUKAreas() -> [(name: String, region: String, lat: Double, lon: Double, radius: Double)] {
        var areas: [(name: String, region: String, lat: Double, lon: Double, radius: Double)] = []
        var addedNames = Set<String>()

        // First, add all cities from UKCityData (they have precise coordinates)
        for city in UKCityData.allCities {
            areas.append(city)
            addedNames.insert(city.name.lowercased())
        }

        // Then, add LADs from GeoJSON that aren't already in the list
        if let features = ladGeoJSON?.features {
            for feature in features {
                let ladName = feature.properties.name
                let ladNameLower = ladName.lowercased()

                // Skip if already added or if it's a common substring match
                if addedNames.contains(ladNameLower) {
                    continue
                }

                // Check if any existing city name contains this LAD name or vice versa
                let alreadyHasMatch = addedNames.contains { existingName in
                    existingName.contains(ladNameLower) || ladNameLower.contains(existingName)
                }

                if !alreadyHasMatch {
                    // Calculate centroid from geometry
                    if let centroid = GeoJSONParser.calculateCentroid(from: feature.geometry) {
                        // Determine region from LAD code
                        let region = regionFromLADCode(feature.properties.region)
                        areas.append((
                            name: ladName,
                            region: region,
                            lat: centroid.latitude,
                            lon: centroid.longitude,
                            radius: 5000  // Default radius for LADs
                        ))
                        addedNames.insert(ladNameLower)
                    }
                }
            }
        }

        return areas.sorted { $0.name < $1.name }
    }

    /// Get all unvisited areas (from both UKCityData and LADs)
    func getUnvisitedAreas() -> [(name: String, region: String, lat: Double, lon: Double, radius: Double)] {
        getAllUKAreas().filter { area in
            !isCityVisited(area.name)
        }
    }

    /// Convert LAD region code to readable region name
    private func regionFromLADCode(_ code: String) -> String {
        switch code.uppercased() {
        case "ENG": return "England"
        case "WAL": return "Wales"
        case "SCO": return "Scotland"
        case "NI": return "Northern Ireland"
        default: return "United Kingdom"
        }
    }

    // MARK: - Add Area Directly

    /// Add an area directly with provided coordinates (works for any UK area)
    func addAreaDirectly(
        name: String,
        region: String,
        latitude: Double,
        longitude: Double,
        radius: Double,
        visitDate: Date,
        places: [String] = []
    ) {
        guard !isCityVisited(name) else {
            print("[UKCitiesManager] Area \(name) already visited")
            return
        }

        let city = VisitedUKCity(
            name: name,
            region: region,
            latitude: latitude,
            longitude: longitude,
            radius: radius,
            visitCount: 1,
            firstVisitDate: visitDate,
            lastVisitDate: visitDate,
            places: places
        )

        visitedCities.append(city)
        saveCities()
        HapticManager.shared.success()
        print("[UKCitiesManager] Added area: \(name)")
    }

    // MARK: - Computed Properties

    var totalCities: Int {
        visitedCities.count
    }

    var totalVisits: Int {
        visitedCities.reduce(0) { $0 + $1.visitCount }
    }

    // Group cities by region
    func citiesByRegion() -> [String: [VisitedUKCity]] {
        Dictionary(grouping: visitedCities) { $0.region }
    }

    // MARK: - City Management

    func addCity(_ city: VisitedUKCity) {
        guard !visitedCities.contains(where: { $0.name == city.name }) else { return }
        visitedCities.append(city)
        saveCities()
    }

    func updateCity(_ city: VisitedUKCity) {
        if let index = visitedCities.firstIndex(where: { $0.id == city.id }) {
            visitedCities[index] = city
            saveCities()
        }
    }

    func removeCity(_ city: VisitedUKCity) {
        visitedCities.removeAll { $0.id == city.id }
        saveCities()
    }

    func isCityVisited(_ name: String) -> Bool {
        visitedCities.contains { $0.name.lowercased() == name.lowercased() }
    }

    func getCity(named name: String) -> VisitedUKCity? {
        visitedCities.first { $0.name.lowercased() == name.lowercased() }
    }

    // Get all unvisited cities for manual addition
    func getUnvisitedCities() -> [(name: String, region: String, lat: Double, lon: Double, radius: Double)] {
        UKCityData.allCities.filter { city in
            !isCityVisited(city.name)
        }
    }

    // Add a city manually with optional details
    func addManualCity(
        name: String,
        visitDate: Date? = nil,
        visitYear: Int? = nil,
        places: [String] = [],
        notes: String? = nil
    ) {
        guard let cityData = UKCityData.city(named: name) else {
            print("[UKCitiesManager] City data not found for \(name)")
            return
        }

        guard !isCityVisited(name) else {
            print("[UKCitiesManager] City \(name) already visited")
            return
        }

        // Determine the visit date
        let effectiveDate: Date
        if let date = visitDate {
            effectiveDate = date
        } else if let year = visitYear {
            var components = DateComponents()
            components.year = year
            components.month = 6
            components.day = 15
            components.hour = 12
            effectiveDate = Calendar.current.date(from: components) ?? Date()
        } else {
            effectiveDate = Date()
        }

        let city = VisitedUKCity(
            name: cityData.name,
            region: cityData.region,
            latitude: cityData.lat,
            longitude: cityData.lon,
            radius: cityData.radius,
            visitCount: 1,
            firstVisitDate: effectiveDate,
            lastVisitDate: effectiveDate,
            places: places
        )

        visitedCities.append(city)
        saveCities()
        HapticManager.shared.success()
        print("[UKCitiesManager] Manually added \(name)")
    }

    // MARK: - Historical Import

    /// Import historical UK city visits from pre-analyzed CSV data
    /// Returns the number of cities imported
    func importHistoricalUKCities() -> Int {
        var importedCount = 0

        for visit in HistoricalUKCityVisits.visits {
            // Skip if city already exists
            guard !isCityVisited(visit.cityName) else {
                print("[UKCitiesManager] Skipping \(visit.cityName) - already exists")
                continue
            }

            // Get city data
            guard let cityData = UKCityData.city(named: visit.cityName) else {
                print("[UKCitiesManager] City data not found for \(visit.cityName)")
                continue
            }

            // Create dates
            let firstVisit = makeDate(visit.firstVisit.year, visit.firstVisit.month, visit.firstVisit.day)
            let lastVisit = makeDate(visit.lastVisit.year, visit.lastVisit.month, visit.lastVisit.day)

            // Create city entry
            let city = VisitedUKCity(
                name: cityData.name,
                region: cityData.region,
                latitude: cityData.lat,
                longitude: cityData.lon,
                radius: cityData.radius,
                visitCount: visit.visitCount,
                firstVisitDate: firstVisit,
                lastVisitDate: lastVisit,
                places: visit.places
            )

            visitedCities.append(city)
            importedCount += 1
            print("[UKCitiesManager] Imported \(city.name) with \(city.visitCount) visits")
        }

        if importedCount > 0 {
            saveCities()
            HapticManager.shared.success()
        }

        print("[UKCitiesManager] Historical import complete: \(importedCount) cities imported")
        return importedCount
    }

    // MARK: - Persistence

    private func saveCities() {
        do {
            let data = try JSONEncoder().encode(visitedCities)
            UserDefaults.standard.set(data, forKey: storageKey)
            print("[UKCitiesManager] Saved \(visitedCities.count) cities")
        } catch {
            print("[UKCitiesManager] Failed to save: \(error)")
        }
    }

    private func loadCities() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            print("[UKCitiesManager] No saved cities found")
            return
        }

        do {
            visitedCities = try JSONDecoder().decode([VisitedUKCity].self, from: data)
            print("[UKCitiesManager] Loaded \(visitedCities.count) cities")
        } catch {
            print("[UKCitiesManager] Failed to load: \(error)")
        }
    }

    // MARK: - Debug

    func clearAllCities() {
        visitedCities.removeAll()
        saveCities()
    }

    // MARK: - Helpers

    private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        components.timeZone = TimeZone.current
        return Calendar.current.date(from: components) ?? Date()
    }
}
