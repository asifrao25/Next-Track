//
//  PhotoImportManager.swift
//  Been There
//
//  Service for importing location data from the user's photo library
//

import Foundation
import Photos
import CoreLocation
import Combine
import UIKit

// MARK: - Photo Location Result

struct PhotoLocationResult: Identifiable, Equatable {
    let id = UUID()
    let cityName: String
    let state: String?
    let country: String
    let countryCode: String
    let coordinate: CLLocationCoordinate2D
    var photoCount: Int
    var firstPhotoDate: Date
    var lastPhotoDate: Date
    var isSelected: Bool = true

    var displayName: String {
        if let state = state {
            return "\(cityName), \(state)"
        }
        return "\(cityName), \(country)"
    }

    var dateRangeDisplay: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        if Calendar.current.isDate(firstPhotoDate, inSameDayAs: lastPhotoDate) {
            return formatter.string(from: firstPhotoDate)
        } else {
            return "\(formatter.string(from: firstPhotoDate)) - \(formatter.string(from: lastPhotoDate))"
        }
    }

    static func == (lhs: PhotoLocationResult, rhs: PhotoLocationResult) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Import Statistics

struct PhotoImportStats {
    var totalPhotosScanned: Int = 0
    var photosWithLocation: Int = 0
    var uniqueCitiesFound: Int = 0
    var uniqueCountriesFound: Int = 0
    var newCitiesImported: Int = 0
    var newCountriesImported: Int = 0
    var existingCitiesUpdated: Int = 0
}

// MARK: - Photo Import Manager

@MainActor
class PhotoImportManager: ObservableObject {
    static let shared = PhotoImportManager()

    // MARK: - Published Properties

    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @Published var isScanning = false
    @Published var scanProgress: Double = 0
    @Published var scanStatusMessage: String = ""
    @Published var discoveredLocations: [PhotoLocationResult] = []
    @Published var importStats = PhotoImportStats()
    @Published var error: String?

    // MARK: - Private Properties

    private let geocoder = CLGeocoder()
    // Apple limits to 50 requests per 60 seconds, so use 1.3s interval to stay safe
    private let geocodingInterval: TimeInterval = 1.3
    private var lastGeocodingTime: Date?
    private var isCancelled = false
    private var consecutiveErrors = 0

    // Cache for geocoded locations (coordinate grid -> location info)
    private var geocodeCache: [String: (city: String, state: String?, country: String, countryCode: String)] = [:]

    // MARK: - Initialization

    private init() {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    // MARK: - Permission Management

    func requestPhotoLibraryAccess() async -> Bool {
        let currentStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)

        switch currentStatus {
        case .authorized, .limited:
            authorizationStatus = currentStatus
            return true
        case .notDetermined:
            let newStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            authorizationStatus = newStatus
            return newStatus == .authorized || newStatus == .limited
        case .denied, .restricted:
            authorizationStatus = currentStatus
            return false
        @unknown default:
            return false
        }
    }

    var canAccessPhotos: Bool {
        authorizationStatus == .authorized || authorizationStatus == .limited
    }

    var isLimitedAccess: Bool {
        authorizationStatus == .limited
    }

    // MARK: - Photo Library Scanning

    func scanPhotoLibrary() async {
        guard canAccessPhotos else {
            error = "Photo library access not granted"
            return
        }

        isScanning = true
        isCancelled = false
        scanProgress = 0
        discoveredLocations = []
        importStats = PhotoImportStats()
        error = nil
        consecutiveErrors = 0
        scanStatusMessage = "Preparing to scan..."

        // Keep screen on during scan
        UIApplication.shared.isIdleTimerDisabled = true

        // Small delay to ensure UI shows 0% initially
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Fetch all photos (PhotoKit doesn't support location != nil predicate)
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        let totalCount = assets.count

        scanStatusMessage = "Scanning \(totalCount) photos..."

        if totalCount == 0 {
            isScanning = false
            scanStatusMessage = "No photos found in library"
            return
        }

        // Group photos by location (using coordinate grid)
        var locationGroups: [String: (coordinate: CLLocationCoordinate2D, photos: [(asset: PHAsset, date: Date)])] = [:]
        var photosWithLocationCount = 0

        // First pass: group photos by approximate location
        scanStatusMessage = "Scanning for geotagged photos..."

        assets.enumerateObjects { [weak self] asset, index, stop in
            guard let self = self, !self.isCancelled else {
                stop.pointee = true
                return
            }

            // Only process photos that have location data
            if let location = asset.location {
                photosWithLocationCount += 1
                let gridKey = self.coordinateGridKey(for: location.coordinate)

                if locationGroups[gridKey] == nil {
                    locationGroups[gridKey] = (coordinate: location.coordinate, photos: [])
                }

                let date = asset.creationDate ?? Date()
                locationGroups[gridKey]?.photos.append((asset: asset, date: date))
            }

            // Update progress (first 30%) - update every 100 photos to reduce overhead
            if index % 100 == 0 || index == totalCount - 1 {
                let progress = Double(index + 1) / Double(totalCount) * 0.3
                Task { @MainActor in
                    self.scanProgress = progress
                    self.importStats.totalPhotosScanned = index + 1
                    self.importStats.photosWithLocation = photosWithLocationCount
                }
            }
        }

        // Update final count of geotagged photos
        importStats.photosWithLocation = photosWithLocationCount

        if isCancelled {
            isScanning = false
            scanStatusMessage = "Scan cancelled"
            UIApplication.shared.isIdleTimerDisabled = false
            return
        }

        // Check if any geotagged photos were found
        if photosWithLocationCount == 0 {
            isScanning = false
            scanStatusMessage = "No geotagged photos found"
            UIApplication.shared.isIdleTimerDisabled = false
            return
        }

        // Second pass: geocode unique locations
        scanStatusMessage = "Found \(photosWithLocationCount) geotagged photos. Identifying locations..."
        let uniqueLocations = Array(locationGroups.keys)
        var processedLocations = 0

        for gridKey in uniqueLocations {
            if isCancelled { break }

            guard let group = locationGroups[gridKey] else { continue }

            // Rate limit geocoding
            await throttleGeocoding()

            if let locationInfo = await geocodeLocation(group.coordinate) {
                let sortedPhotos = group.photos.sorted { $0.date < $1.date }
                let firstDate = sortedPhotos.first?.date ?? Date()
                let lastDate = sortedPhotos.last?.date ?? Date()

                let result = PhotoLocationResult(
                    cityName: locationInfo.city,
                    state: locationInfo.state,
                    country: locationInfo.country,
                    countryCode: locationInfo.countryCode,
                    coordinate: group.coordinate,
                    photoCount: group.photos.count,
                    firstPhotoDate: firstDate,
                    lastPhotoDate: lastDate
                )

                // Check if we already have this city in results (merge if so)
                if let existingIndex = discoveredLocations.firstIndex(where: {
                    $0.cityName.lowercased() == result.cityName.lowercased() &&
                    $0.country.lowercased() == result.country.lowercased()
                }) {
                    // Merge with existing
                    var existing = discoveredLocations[existingIndex]
                    existing.photoCount += result.photoCount
                    existing.firstPhotoDate = min(existing.firstPhotoDate, result.firstPhotoDate)
                    existing.lastPhotoDate = max(existing.lastPhotoDate, result.lastPhotoDate)
                    discoveredLocations[existingIndex] = existing
                } else {
                    discoveredLocations.append(result)
                }
            }

            processedLocations += 1

            // Update progress (remaining 70%)
            let progress = 0.3 + (Double(processedLocations) / Double(uniqueLocations.count) * 0.7)
            scanProgress = progress
            scanStatusMessage = "Processed \(processedLocations) of \(uniqueLocations.count) locations"
        }

        // Sort by photo count (descending)
        discoveredLocations.sort { $0.photoCount > $1.photoCount }

        // Update stats
        importStats.uniqueCitiesFound = discoveredLocations.count
        let uniqueCountries = Set(discoveredLocations.map { $0.countryCode })
        importStats.uniqueCountriesFound = uniqueCountries.count

        isScanning = false
        scanProgress = 1.0
        scanStatusMessage = "Found \(discoveredLocations.count) locations from \(importStats.photosWithLocation) photos"

        // Re-enable screen dimming
        UIApplication.shared.isIdleTimerDisabled = false
    }

    func cancelScan() {
        isCancelled = true
        UIApplication.shared.isIdleTimerDisabled = false
    }

    // MARK: - Import Selected Locations

    func importSelectedLocations() async -> PhotoImportStats {
        let selectedLocations = discoveredLocations.filter { $0.isSelected }
        var stats = PhotoImportStats()
        stats.uniqueCitiesFound = selectedLocations.count

        for location in selectedLocations {
            // Import to CityTracker
            let (isNew, _) = CityTracker.shared.importFromPhotos(
                name: location.cityName,
                state: location.state,
                country: location.country,
                countryCode: location.countryCode,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                firstVisitDate: location.firstPhotoDate,
                lastVisitDate: location.lastPhotoDate,
                photoCount: location.photoCount
            )

            if isNew {
                stats.newCitiesImported += 1
            } else {
                stats.existingCitiesUpdated += 1
            }

            // Ensure country is also tracked
            if let countryData = CountryData.allCountries.first(where: { $0.isoCode == location.countryCode }) {
                let countryIsNew = CountriesManager.shared.addOrUpdateCountryFromPhotos(
                    name: countryData.name,
                    isoCode: location.countryCode,
                    continent: countryData.continent,
                    firstVisitDate: location.firstPhotoDate,
                    lastVisitDate: location.lastPhotoDate,
                    photoCount: location.photoCount
                )

                if countryIsNew {
                    stats.newCountriesImported += 1
                }
            }
        }

        // Update unique countries count
        let uniqueCountries = Set(selectedLocations.map { $0.countryCode })
        stats.uniqueCountriesFound = uniqueCountries.count

        // Trigger iCloud sync
        iCloudSyncManager.shared.syncCitiesNow()
        iCloudSyncManager.shared.syncCountriesNow()

        // Haptic feedback
        HapticManager.shared.success()

        return stats
    }

    // MARK: - Toggle Selection

    func toggleSelection(for locationId: UUID) {
        if let index = discoveredLocations.firstIndex(where: { $0.id == locationId }) {
            discoveredLocations[index].isSelected.toggle()
        }
    }

    func selectAll() {
        for index in discoveredLocations.indices {
            discoveredLocations[index].isSelected = true
        }
    }

    func deselectAll() {
        for index in discoveredLocations.indices {
            discoveredLocations[index].isSelected = false
        }
    }

    var selectedCount: Int {
        discoveredLocations.filter { $0.isSelected }.count
    }

    var totalPhotoCountSelected: Int {
        discoveredLocations.filter { $0.isSelected }.reduce(0) { $0 + $1.photoCount }
    }

    // MARK: - Private Helpers

    /// Create a grid key for coordinates (~5km resolution)
    private func coordinateGridKey(for coordinate: CLLocationCoordinate2D) -> String {
        // Round to ~5km grid
        let latGrid = (coordinate.latitude * 20).rounded() / 20
        let lonGrid = (coordinate.longitude * 20).rounded() / 20
        return "\(latGrid),\(lonGrid)"
    }

    /// Rate limit geocoding requests
    private func throttleGeocoding() async {
        // Add extra delay if we've been hitting errors (backoff)
        let backoffMultiplier = min(Double(consecutiveErrors + 1), 5.0)
        let effectiveInterval = geocodingInterval * backoffMultiplier

        if let lastTime = lastGeocodingTime {
            let elapsed = Date().timeIntervalSince(lastTime)
            if elapsed < effectiveInterval {
                let delay = effectiveInterval - elapsed
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        lastGeocodingTime = Date()
    }

    /// Geocode a coordinate to city/country info with retry logic
    private func geocodeLocation(_ coordinate: CLLocationCoordinate2D) async -> (city: String, state: String?, country: String, countryCode: String)? {
        // Check cache first
        let cacheKey = coordinateGridKey(for: coordinate)
        if let cached = geocodeCache[cacheKey] {
            consecutiveErrors = 0  // Reset on cache hit
            return cached
        }

        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        // Retry up to 3 times with increasing backoff
        for attempt in 0..<3 {
            if attempt > 0 {
                // Wait before retry - exponential backoff
                let retryDelay = Double(attempt) * 20.0  // 20s, 40s for retries
                print("[PhotoImportManager] Waiting \(Int(retryDelay))s before retry attempt \(attempt + 1)...")
                try? await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
            }

            do {
                let placemarks = try await geocoder.reverseGeocodeLocation(location)

                if let placemark = placemarks.first {
                    let city = placemark.locality ?? placemark.subAdministrativeArea ?? placemark.administrativeArea ?? "Unknown"
                    let state = placemark.administrativeArea
                    let country = placemark.country ?? "Unknown"
                    let countryCode = placemark.isoCountryCode ?? "XX"

                    let result = (city: city, state: state, country: country, countryCode: countryCode)
                    geocodeCache[cacheKey] = result
                    consecutiveErrors = 0  // Reset on success
                    return result
                }
            } catch let error as NSError {
                // Check for rate limiting error (kCLErrorDomain error 2 = network error, often rate limit)
                if error.domain == kCLErrorDomain && error.code == 2 {
                    consecutiveErrors += 1
                    print("[PhotoImportManager] Rate limited (attempt \(attempt + 1)/3), consecutive errors: \(consecutiveErrors)")
                    continue  // Retry
                } else {
                    print("[PhotoImportManager] Geocoding error: \(error.localizedDescription)")
                    break  // Don't retry non-rate-limit errors
                }
            }
        }

        return nil
    }
}

// MARK: - CityTracker Extension

extension CityTracker {
    /// Import a city from photo library data
    /// Returns (isNew: Bool, city: VisitedCity)
    func importFromPhotos(
        name: String,
        state: String?,
        country: String,
        countryCode: String,
        latitude: Double,
        longitude: Double,
        firstVisitDate: Date,
        lastVisitDate: Date,
        photoCount: Int
    ) -> (isNew: Bool, city: VisitedCity) {
        // Check if city already exists
        if let index = visitedCities.firstIndex(where: {
            $0.name.lowercased() == name.lowercased() &&
            $0.country.lowercased() == country.lowercased()
        }) {
            // Update existing city
            var city = visitedCities[index]
            city.photoCount += photoCount
            city.firstVisitDate = min(city.firstVisitDate, firstVisitDate)
            city.lastVisitDate = max(city.lastVisitDate, lastVisitDate)
            visitedCities[index] = city
            saveCities()
            return (isNew: false, city: city)
        } else {
            // Create new city
            let city = VisitedCity(
                name: name,
                state: state,
                country: country,
                countryCode: countryCode,
                firstVisitDate: firstVisitDate,
                lastVisitDate: lastVisitDate,
                visitCount: 1,
                totalPointsRecorded: 0,
                latitude: latitude,
                longitude: longitude,
                isManuallyAdded: true,
                photoCount: photoCount
            )
            visitedCities.append(city)
            saveCities()

            print("[CityTracker] Photo import - new city: \(name), \(country)")

            return (isNew: true, city: city)
        }
    }
}

// MARK: - CountriesManager Extension

extension CountriesManager {
    /// Add or update a country from photo import
    /// Returns true if country was newly added
    func addOrUpdateCountryFromPhotos(
        name: String,
        isoCode: String,
        continent: String,
        firstVisitDate: Date,
        lastVisitDate: Date,
        photoCount: Int
    ) -> Bool {
        if let index = visitedCountries.firstIndex(where: { $0.isoCode == isoCode }) {
            // Update existing country
            var country = visitedCountries[index]
            country.photoCount += photoCount
            if let existing = country.firstVisitDate {
                country.firstVisitDate = min(existing, firstVisitDate)
            } else {
                country.firstVisitDate = firstVisitDate
            }
            if let existing = country.lastVisitDate {
                country.lastVisitDate = max(existing, lastVisitDate)
            } else {
                country.lastVisitDate = lastVisitDate
            }
            country.updatedAt = Date()
            visitedCountries[index] = country
            saveCountries()
            return false
        } else {
            // Create new country
            let country = VisitedCountry(
                name: name,
                isoCode: isoCode,
                continent: continent,
                isAutoDetected: false,
                isManuallyAdded: true,
                firstVisitDate: firstVisitDate,
                lastVisitDate: lastVisitDate,
                photoCount: photoCount
            )
            visitedCountries.append(country)
            saveCountries()
            return true
        }
    }
}
