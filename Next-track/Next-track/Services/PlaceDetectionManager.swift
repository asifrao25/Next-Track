//
//  PlaceDetectionManager.swift
//  Next-track
//
//  Service for detecting and categorizing significant places from location history
//

import Foundation
import CoreLocation
import Combine

class PlaceDetectionManager: ObservableObject {
    static let shared = PlaceDetectionManager()

    // MARK: - Published Properties

    @Published var detectedPlaces: [DetectedPlace] = []
    @Published var isProcessing: Bool = false
    @Published var processingProgress: Double = 0

    // MARK: - Private Properties

    private let geocoder = CLGeocoder()
    private let storageKey = "detectedPlaces"

    // Clustering parameters
    private let gridCellSize: Double = 50.0        // meters
    private let minVisitsForPlace: Int = 2         // minimum visits to consider a place
    private let minDwellTime: TimeInterval = 120   // 2 minutes minimum stop
    private let maxSpeed: Double = 1.0             // m/s - below this is considered stationary

    // Geocoding rate limiting
    private var lastGeocodingTime: Date?
    private let minGeocodingInterval: TimeInterval = 0.25  // 250ms between requests
    private var geocodingQueue: [(DetectedPlace, Int)] = []  // (place, index)
    private var isGeocodingQueueProcessing = false

    // MARK: - Initialization

    private init() {
        loadPlaces()
    }

    // MARK: - Public Methods

    /// Detect places from all historical sessions
    func detectPlacesFromHistory(_ sessions: [TrackingSession]) async {
        await MainActor.run {
            isProcessing = true
            processingProgress = 0
        }

        // Step 1: Extract stationary points from all sessions
        let stationaryPoints = extractStationaryPoints(from: sessions)
        print("[PlaceDetection] Found \(stationaryPoints.count) stationary points")

        await MainActor.run {
            processingProgress = 0.2
        }

        // Step 2: Cluster points into grid cells
        let clusters = clusterPoints(stationaryPoints)
        print("[PlaceDetection] Created \(clusters.count) clusters")

        await MainActor.run {
            processingProgress = 0.4
        }

        // Step 3: Convert clusters to detected places
        var newPlaces = clusters.compactMap { cluster -> DetectedPlace? in
            guard cluster.visits.count >= minVisitsForPlace else { return nil }
            return createPlace(from: cluster)
        }
        print("[PlaceDetection] Created \(newPlaces.count) places from clusters")

        await MainActor.run {
            processingProgress = 0.6
        }

        // Step 4: Merge with existing places
        newPlaces = mergePlaces(existing: detectedPlaces, new: newPlaces)

        // Step 5: Auto-categorize based on time patterns
        for i in 0..<newPlaces.count {
            let (category, confidence) = categorizeByTimePattern(newPlaces[i])
            newPlaces[i].category = category
            newPlaces[i].confidence = confidence
        }

        // Capture final value for MainActor to avoid Swift 6 concurrency warning
        let finalPlaces = newPlaces
        await MainActor.run {
            self.detectedPlaces = finalPlaces
            self.processingProgress = 0.8
        }

        // Step 6: Reverse geocode places (rate limited)
        await reverseGeocodePlaces()

        await MainActor.run {
            self.savePlaces()
            self.isProcessing = false
            self.processingProgress = 1.0
        }

        print("[PlaceDetection] Completed: \(detectedPlaces.count) places detected")
    }

    /// Process a single location during active tracking
    func processLocation(_ location: CLLocation, timestamp: Date) {
        guard location.speed < maxSpeed else { return }

        // Check if this location is near an existing place
        if let index = findNearestPlace(to: location.coordinate, maxDistance: gridCellSize * 1.5) {
            // Update existing place
            var place = detectedPlaces[index]

            // Check if this is a new visit or continuation
            if let lastVisit = place.visitHistory.last,
               lastVisit.departureTime == nil {
                // Continuing current visit - do nothing, departure will be set when we leave
            } else {
                // New visit
                place.recordVisit(arrival: timestamp)
                detectedPlaces[index] = place
                savePlaces()
            }
        }
    }

    /// Mark departure from a place
    func markDeparture(at location: CLLocation, timestamp: Date) {
        if let index = findNearestPlace(to: location.coordinate, maxDistance: gridCellSize * 1.5) {
            var place = detectedPlaces[index]
            place.endCurrentVisit(departure: timestamp)
            detectedPlaces[index] = place
            savePlaces()
        }
    }

    /// Get places sorted by option
    func places(sortedBy option: PlaceSortOption) -> [DetectedPlace] {
        option.sort(detectedPlaces)
    }

    /// Get places by category
    func places(in category: PlaceCategory) -> [DetectedPlace] {
        detectedPlaces.filter { $0.category == category }
    }

    /// Update a place's name (user override)
    func updatePlaceName(_ placeId: UUID, name: String) {
        if let index = detectedPlaces.firstIndex(where: { $0.id == placeId }) {
            detectedPlaces[index].name = name
            detectedPlaces[index].isConfirmed = true
            savePlaces()
        }
    }

    /// Update a place's category (user override)
    func updatePlaceCategory(_ placeId: UUID, category: PlaceCategory) {
        if let index = detectedPlaces.firstIndex(where: { $0.id == placeId }) {
            detectedPlaces[index].category = category
            detectedPlaces[index].confidence = 1.0  // User confirmed
            detectedPlaces[index].isConfirmed = true
            savePlaces()
        }
    }

    // MARK: - Private Methods - Clustering

    private struct StationaryPoint {
        let coordinate: CLLocationCoordinate2D
        let timestamp: Date
        let duration: TimeInterval
    }

    private struct LocationCluster {
        var centroid: CLLocationCoordinate2D
        var visits: [StationaryPoint]
        var totalDwellTime: TimeInterval
        var spread: Double  // max distance from centroid

        var visitCount: Int { visits.count }
    }

    private func extractStationaryPoints(from sessions: [TrackingSession]) -> [StationaryPoint] {
        var points: [StationaryPoint] = []

        for session in sessions {
            let locations = session.locations
            guard locations.count > 1 else { continue }

            var stationaryStart: (location: StoredLocation, index: Int)?

            for i in 0..<locations.count {
                let loc = locations[i]
                let speed = loc.speed ?? 0

                if speed < maxSpeed {
                    // Stationary
                    if stationaryStart == nil {
                        stationaryStart = (loc, i)
                    }
                } else {
                    // Moving - check if we had a stationary period
                    if let start = stationaryStart {
                        let duration = loc.timestamp.timeIntervalSince(start.location.timestamp)
                        if duration >= minDwellTime {
                            // Valid stationary point
                            let point = StationaryPoint(
                                coordinate: CLLocationCoordinate2D(
                                    latitude: start.location.latitude,
                                    longitude: start.location.longitude
                                ),
                                timestamp: start.location.timestamp,
                                duration: duration
                            )
                            points.append(point)
                        }
                    }
                    stationaryStart = nil
                }
            }

            // Check final stationary period
            if let start = stationaryStart,
               let lastLoc = locations.last {
                let duration = lastLoc.timestamp.timeIntervalSince(start.location.timestamp)
                if duration >= minDwellTime {
                    let point = StationaryPoint(
                        coordinate: CLLocationCoordinate2D(
                            latitude: start.location.latitude,
                            longitude: start.location.longitude
                        ),
                        timestamp: start.location.timestamp,
                        duration: duration
                    )
                    points.append(point)
                }
            }
        }

        return points
    }

    private func clusterPoints(_ points: [StationaryPoint]) -> [LocationCluster] {
        // Grid-based clustering
        var grid: [String: [StationaryPoint]] = [:]

        for point in points {
            let key = gridKey(for: point.coordinate)
            grid[key, default: []].append(point)
        }

        // Convert grid cells to clusters
        var clusters: [LocationCluster] = []

        for (_, cellPoints) in grid {
            // Calculate centroid
            let sumLat = cellPoints.reduce(0.0) { $0 + $1.coordinate.latitude }
            let sumLon = cellPoints.reduce(0.0) { $0 + $1.coordinate.longitude }
            let centroid = CLLocationCoordinate2D(
                latitude: sumLat / Double(cellPoints.count),
                longitude: sumLon / Double(cellPoints.count)
            )

            // Calculate spread (max distance from centroid)
            let centroidLocation = CLLocation(latitude: centroid.latitude, longitude: centroid.longitude)
            var maxSpread: Double = 0
            for point in cellPoints {
                let pointLocation = CLLocation(latitude: point.coordinate.latitude, longitude: point.coordinate.longitude)
                let distance = centroidLocation.distance(from: pointLocation)
                maxSpread = max(maxSpread, distance)
            }

            // Calculate total dwell time
            let totalDwell = cellPoints.reduce(0.0) { $0 + $1.duration }

            let cluster = LocationCluster(
                centroid: centroid,
                visits: cellPoints,
                totalDwellTime: totalDwell,
                spread: max(maxSpread, 25)  // Minimum 25m radius
            )
            clusters.append(cluster)
        }

        return clusters
    }

    private func gridKey(for coordinate: CLLocationCoordinate2D) -> String {
        // Convert to grid cell (approximately 50m cells)
        // At equator: 1 degree ≈ 111km, so 0.00045 degrees ≈ 50m
        let latKey = Int(coordinate.latitude / 0.00045)
        let lonKey = Int(coordinate.longitude / 0.00045)
        return "\(latKey),\(lonKey)"
    }

    private func createPlace(from cluster: LocationCluster) -> DetectedPlace {
        let visits = cluster.visits.map { point in
            PlaceVisit(
                arrivalTime: point.timestamp,
                departureTime: point.timestamp.addingTimeInterval(point.duration)
            )
        }

        // Determine first and last visit dates
        let sortedVisits = visits.sorted { $0.arrivalTime < $1.arrivalTime }
        let firstVisit = sortedVisits.first?.arrivalTime ?? Date()
        let lastVisit = sortedVisits.last?.arrivalTime ?? Date()

        return DetectedPlace(
            latitude: cluster.centroid.latitude,
            longitude: cluster.centroid.longitude,
            radius: max(cluster.spread, 30),  // Minimum 30m radius
            category: .other,
            confidence: 0.5,
            visitHistory: visits,
            createdAt: firstVisit,
            lastVisitedAt: lastVisit
        )
    }

    private func mergePlaces(existing: [DetectedPlace], new: [DetectedPlace]) -> [DetectedPlace] {
        var merged = existing

        for newPlace in new {
            // Check if there's an overlapping existing place
            let existingIndex = merged.firstIndex { existingPlace in
                let existingLoc = CLLocation(latitude: existingPlace.latitude, longitude: existingPlace.longitude)
                let newLoc = CLLocation(latitude: newPlace.latitude, longitude: newPlace.longitude)
                return existingLoc.distance(from: newLoc) < (existingPlace.radius + newPlace.radius)
            }

            if let index = existingIndex {
                // Merge visits
                var existingPlace = merged[index]
                existingPlace.visitHistory.append(contentsOf: newPlace.visitHistory)
                existingPlace.lastVisitedAt = max(existingPlace.lastVisitedAt, newPlace.lastVisitedAt)

                // Update centroid (weighted average)
                let totalVisits = existingPlace.visitCount
                let existingWeight = Double(existingPlace.visitCount - newPlace.visitCount) / Double(totalVisits)
                let newWeight = Double(newPlace.visitCount) / Double(totalVisits)
                existingPlace.latitude = existingPlace.latitude * existingWeight + newPlace.latitude * newWeight
                existingPlace.longitude = existingPlace.longitude * existingWeight + newPlace.longitude * newWeight

                merged[index] = existingPlace
            } else {
                // Add new place
                merged.append(newPlace)
            }
        }

        return merged
    }

    private func findNearestPlace(to coordinate: CLLocationCoordinate2D, maxDistance: Double) -> Int? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        var nearestIndex: Int?
        var nearestDistance: Double = maxDistance

        for (index, place) in detectedPlaces.enumerated() {
            let placeLocation = CLLocation(latitude: place.latitude, longitude: place.longitude)
            let distance = location.distance(from: placeLocation)

            if distance < nearestDistance {
                nearestDistance = distance
                nearestIndex = index
            }
        }

        return nearestIndex
    }

    // MARK: - Private Methods - Categorization

    private func categorizeByTimePattern(_ place: DetectedPlace) -> (PlaceCategory, Double) {
        let calendar = Calendar.current

        var nightVisits = 0      // 11pm - 7am
        var workdayVisits = 0    // Mon-Fri, 9am - 5pm
        var mealTimeVisits = 0   // 11am-2pm or 5pm-9pm
        var morningVisits = 0    // 5am - 9am

        for visit in place.visitHistory {
            let hour = calendar.component(.hour, from: visit.arrivalTime)
            let weekday = calendar.component(.weekday, from: visit.arrivalTime)
            let isWeekday = weekday >= 2 && weekday <= 6  // Mon = 2, Fri = 6

            if hour >= 23 || hour < 7 {
                nightVisits += 1
            }
            if isWeekday && hour >= 9 && hour < 17 {
                workdayVisits += 1
            }
            if (hour >= 11 && hour < 14) || (hour >= 17 && hour < 21) {
                mealTimeVisits += 1
            }
            if hour >= 5 && hour < 9 {
                morningVisits += 1
            }
        }

        let totalVisits = Double(place.visitCount)
        guard totalVisits > 0 else { return (.other, 0.3) }

        let nightRatio = Double(nightVisits) / totalVisits
        let workRatio = Double(workdayVisits) / totalVisits
        let avgDwell = place.averageDwellTime

        // Home detection: high night visits + long dwell time
        if nightRatio > 0.5 && avgDwell > 4 * 3600 {  // 4+ hours average
            return (.home, min(0.9, 0.5 + nightRatio * 0.4))
        }

        // Work detection: high weekday visits during work hours
        if workRatio > 0.6 && avgDwell > 2 * 3600 {  // 2+ hours average during work hours
            return (.work, min(0.85, 0.4 + workRatio * 0.4))
        }

        // Gym detection: regular short-ish visits
        if avgDwell > 30 * 60 && avgDwell < 2 * 3600 && morningVisits > 0 {
            return (.gym, 0.5)
        }

        // Default to other with low confidence
        return (.other, 0.3)
    }

    /// Enhanced categorization using geocoded name + time patterns
    func categorizePlace(_ place: DetectedPlace, geocodedName: String?) -> (PlaceCategory, Double) {
        // First try to categorize from geocoded name
        if let name = geocodedName?.lowercased() {
            for category in PlaceCategory.allCases {
                for keyword in category.keywords {
                    if name.contains(keyword.lowercased()) {
                        return (category, 0.85)  // High confidence from name match
                    }
                }
            }
        }

        // Fall back to time-based patterns
        return categorizeByTimePattern(place)
    }

    // MARK: - Private Methods - Reverse Geocoding

    private func reverseGeocodePlaces() async {
        // Queue all places that need geocoding
        for (index, place) in detectedPlaces.enumerated() {
            if place.name == nil && !place.isConfirmed {
                geocodingQueue.append((place, index))
            }
        }

        // Process queue with rate limiting
        for (queueIndex, item) in geocodingQueue.enumerated() {
            let (place, index) = item

            await MainActor.run {
                processingProgress = 0.8 + (0.2 * Double(queueIndex) / Double(max(geocodingQueue.count, 1)))
            }

            // Rate limit
            if let lastTime = lastGeocodingTime {
                let elapsed = Date().timeIntervalSince(lastTime)
                if elapsed < minGeocodingInterval {
                    try? await Task.sleep(nanoseconds: UInt64((minGeocodingInterval - elapsed) * 1_000_000_000))
                }
            }

            lastGeocodingTime = Date()

            do {
                let location = CLLocation(latitude: place.latitude, longitude: place.longitude)
                let placemarks = try await geocoder.reverseGeocodeLocation(location)

                if let placemark = placemarks.first {
                    await MainActor.run {
                        // Update place with geocoded info
                        var updatedPlace = self.detectedPlaces[index]
                        updatedPlace.name = placemark.name ?? placemark.thoroughfare
                        updatedPlace.streetAddress = [placemark.subThoroughfare, placemark.thoroughfare]
                            .compactMap { $0 }
                            .joined(separator: " ")

                        // Re-categorize with geocoded name
                        let (category, confidence) = self.categorizePlace(updatedPlace, geocodedName: placemark.name)
                        if !updatedPlace.isConfirmed {
                            updatedPlace.category = category
                            updatedPlace.confidence = confidence
                        }

                        self.detectedPlaces[index] = updatedPlace
                    }
                }
            } catch {
                print("[PlaceDetection] Geocoding error for place \(index): \(error.localizedDescription)")
            }
        }

        geocodingQueue.removeAll()
    }

    // MARK: - Persistence

    private func savePlaces() {
        do {
            let data = try JSONEncoder().encode(detectedPlaces)
            UserDefaults.standard.set(data, forKey: storageKey)
            print("[PlaceDetection] Saved \(detectedPlaces.count) places")
        } catch {
            print("[PlaceDetection] Failed to save places: \(error)")
        }
    }

    private func loadPlaces() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            print("[PlaceDetection] No saved places found")
            return
        }

        do {
            detectedPlaces = try JSONDecoder().decode([DetectedPlace].self, from: data)
            print("[PlaceDetection] Loaded \(detectedPlaces.count) places")
        } catch {
            print("[PlaceDetection] Failed to load places: \(error)")
        }
    }

    // MARK: - Statistics

    var totalPlaces: Int { detectedPlaces.count }

    var confirmedPlaces: Int {
        detectedPlaces.filter { $0.isConfirmed }.count
    }

    var placesByCategory: [PlaceCategory: Int] {
        var counts: [PlaceCategory: Int] = [:]
        for place in detectedPlaces {
            counts[place.category, default: 0] += 1
        }
        return counts
    }

    func recentPlaces(limit: Int = 5) -> [DetectedPlace] {
        Array(detectedPlaces.sorted { $0.lastVisitedAt > $1.lastVisitedAt }.prefix(limit))
    }

    func mostVisitedPlaces(limit: Int = 5) -> [DetectedPlace] {
        Array(detectedPlaces.sorted { $0.visitCount > $1.visitCount }.prefix(limit))
    }

    // MARK: - Debug

    func clearAllPlaces() {
        detectedPlaces.removeAll()
        savePlaces()
        print("[PlaceDetection] Cleared all places")
    }
}
