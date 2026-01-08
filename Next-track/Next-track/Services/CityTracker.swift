//
//  CityTracker.swift
//  Next-track
//
//  Service for tracking visited cities via reverse geocoding
//

import Foundation
import CoreLocation
import Combine
import UserNotifications

class CityTracker: ObservableObject {
    static let shared = CityTracker()

    // MARK: - Published Properties

    @Published var visitedCities: [VisitedCity] = []
    @Published var isProcessing: Bool = false

    // MARK: - Private Properties

    private let geocoder = CLGeocoder()
    private var cityCache: [String: String] = [:]  // "lat,lon" -> cityName
    private let storageKey = "visitedCities"

    // Rate limiting
    private var lastGeocodingTime: Date?
    private let minGeocodingInterval: TimeInterval = 0.2  // 200ms between requests
    private var geocodingQueue: [CLLocation] = []
    private var isQueueProcessing = false

    // MARK: - Initialization

    private init() {
        loadCities()
    }

    // MARK: - Public Methods

    /// Process a new location and extract city info (rate-limited)
    func processLocation(_ location: CLLocation) {
        // Create cache key based on ~1km grid
        let cacheKey = "\(Int(location.coordinate.latitude * 100)),\(Int(location.coordinate.longitude * 100))"

        // Check cache first
        if cityCache[cacheKey] != nil {
            // Already processed this area
            return
        }

        // Add to queue for processing
        geocodingQueue.append(location)
        processQueue()
    }

    /// Process multiple locations (for historical data)
    func processHistoricalLocations(_ sessions: [TrackingSession]) async {
        await MainActor.run {
            isProcessing = true
        }

        // Sample locations - take first location from each session
        for session in sessions {
            guard let firstLocation = session.locations.first else { continue }

            let location = CLLocation(
                latitude: firstLocation.latitude,
                longitude: firstLocation.longitude
            )

            await processLocationAsync(location)

            // Rate limit
            try? await Task.sleep(nanoseconds: 200_000_000)  // 200ms
        }

        await MainActor.run {
            isProcessing = false
        }
    }

    /// Get statistics
    var totalCities: Int { visitedCities.count }

    var countriesVisited: Int {
        Set(visitedCities.map { $0.country }).count
    }

    var statesVisited: Int {
        Set(visitedCities.compactMap { $0.state }).count
    }

    // MARK: - Private Methods

    private func processQueue() {
        guard !isQueueProcessing, !geocodingQueue.isEmpty else { return }

        isQueueProcessing = true

        // Check rate limit
        if let lastTime = lastGeocodingTime,
           Date().timeIntervalSince(lastTime) < minGeocodingInterval {
            // Schedule retry after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + minGeocodingInterval) { [weak self] in
                self?.isQueueProcessing = false
                self?.processQueue()
            }
            return
        }

        guard let location = geocodingQueue.first else {
            isQueueProcessing = false
            return
        }

        geocodingQueue.removeFirst()
        lastGeocodingTime = Date()

        Task {
            await processLocationAsync(location)
            await MainActor.run {
                self.isQueueProcessing = false
                self.processQueue()
            }
        }
    }

    private func processLocationAsync(_ location: CLLocation) async {
        let cacheKey = "\(Int(location.coordinate.latitude * 100)),\(Int(location.coordinate.longitude * 100))"

        // Check cache again (might have been processed while in queue)
        if cityCache[cacheKey] != nil { return }

        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            guard let placemark = placemarks.first,
                  let cityName = placemark.locality else {
                // Mark as processed but not a city
                cityCache[cacheKey] = ""
                return
            }

            // Cache the result
            cityCache[cacheKey] = cityName

            await MainActor.run {
                updateCity(
                    name: cityName,
                    state: placemark.administrativeArea,
                    country: placemark.country ?? "Unknown",
                    countryCode: placemark.isoCountryCode,
                    coordinate: location.coordinate
                )
            }
        } catch {
            print("[CityTracker] Geocoding error: \(error.localizedDescription)")
            // Mark as processed to avoid retry loops
            cityCache[cacheKey] = ""
        }
    }

    private func updateCity(
        name: String,
        state: String?,
        country: String,
        countryCode: String?,
        coordinate: CLLocationCoordinate2D
    ) {
        // Look for existing city (same name + country)
        if let index = visitedCities.firstIndex(where: {
            $0.name == name && $0.country == country
        }) {
            // Update existing city
            visitedCities[index].lastVisitDate = Date()
            visitedCities[index].visitCount += 1
            visitedCities[index].totalPointsRecorded += 1
            print("[CityTracker] Updated city: \(name) (visits: \(visitedCities[index].visitCount))")
        } else {
            // New city discovered!
            let newCity = VisitedCity(
                name: name,
                state: state,
                country: country,
                countryCode: countryCode,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
            visitedCities.append(newCity)
            print("[CityTracker] New city discovered: \(name), \(state ?? ""), \(country)")

            // Send notification for new city
            sendNewCityNotification(city: newCity)
        }

        saveCities()
    }

    // MARK: - Notifications

    private func sendNewCityNotification(city: VisitedCity) {
        let content = UNMutableNotificationContent()
        content.title = "\(city.flagEmoji) New City Discovered!"
        content.body = "You've visited \(city.displayName) for the first time"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "newCity-\(city.id.uuidString)",
            content: content,
            trigger: nil  // Deliver immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[CityTracker] Notification error: \(error)")
            }
        }
    }

    // MARK: - Persistence

    private func saveCities() {
        do {
            let data = try JSONEncoder().encode(visitedCities)
            UserDefaults.standard.set(data, forKey: storageKey)
            print("[CityTracker] Saved \(visitedCities.count) cities")
        } catch {
            print("[CityTracker] Failed to save cities: \(error)")
        }
    }

    private func loadCities() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            print("[CityTracker] No saved cities found")
            return
        }

        do {
            visitedCities = try JSONDecoder().decode([VisitedCity].self, from: data)
            print("[CityTracker] Loaded \(visitedCities.count) cities")
        } catch {
            print("[CityTracker] Failed to load cities: \(error)")
        }
    }

    // MARK: - Query Methods

    func cities(sortedBy option: CitySortOption) -> [VisitedCity] {
        option.sort(visitedCities)
    }

    func cities(in country: String) -> [VisitedCity] {
        visitedCities.filter { $0.country == country }
    }

    func recentCities(limit: Int = 5) -> [VisitedCity] {
        Array(visitedCities.sorted { $0.lastVisitDate > $1.lastVisitDate }.prefix(limit))
    }

    func mostVisitedCities(limit: Int = 5) -> [VisitedCity] {
        Array(visitedCities.sorted { $0.visitCount > $1.visitCount }.prefix(limit))
    }

    // MARK: - Debug

    func clearAllCities() {
        visitedCities.removeAll()
        cityCache.removeAll()
        saveCities()
        print("[CityTracker] Cleared all cities")
    }
}
