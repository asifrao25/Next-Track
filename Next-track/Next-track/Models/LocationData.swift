//
//  LocationData.swift
//  Next-track
//
//  Location payload model for PhoneTrack API
//

import Foundation
import CoreLocation

struct LocationData: Codable, Equatable {
    let latitude: Double
    let longitude: Double
    let timestamp: TimeInterval // Unix epoch in seconds
    let altitude: Double?
    let accuracy: Double?
    let speed: Double?
    let bearing: Double?
    let batteryLevel: Int?

    // Create from CLLocation
    init(from location: CLLocation, batteryLevel: Int? = nil) {
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.timestamp = location.timestamp.timeIntervalSince1970
        self.altitude = location.altitude >= 0 ? location.altitude : nil
        self.accuracy = location.horizontalAccuracy >= 0 ? location.horizontalAccuracy : nil
        self.speed = location.speed >= 0 ? location.speed : nil
        self.bearing = location.course >= 0 ? location.course : nil
        self.batteryLevel = batteryLevel
    }

    // Build query parameters for PhoneTrack GET request
    func toQueryParameters(settings: TrackingSettings) -> [String: String] {
        var params: [String: String] = [
            "lat": String(format: "%.6f", latitude),
            "lon": String(format: "%.6f", longitude),
            "timestamp": String(Int(timestamp))
        ]

        if settings.sendAltitude, let alt = altitude {
            params["alt"] = String(format: "%.1f", alt)
        }

        if settings.sendAccuracy, let acc = accuracy {
            params["acc"] = String(format: "%.1f", acc)
        }

        if settings.sendSpeed, let spd = speed {
            params["speed"] = String(format: "%.2f", spd)
        }

        if settings.sendBearing, let brg = bearing {
            params["bearing"] = String(format: "%.1f", brg)
        }

        if settings.sendBatteryLevel, let bat = batteryLevel {
            params["bat"] = String(bat)
        }

        // Add user agent
        params["useragent"] = "Next-track iOS"

        return params
    }

    // Build full URL with query parameters
    func buildURL(baseURL: String, settings: TrackingSettings) -> URL? {
        guard var components = URLComponents(string: baseURL) else { return nil }

        let params = toQueryParameters(settings: settings)
        components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }

        return components.url
    }
}

// MARK: - Pending Location Queue
struct PendingLocation: Codable, Identifiable {
    let id: UUID
    let locationData: LocationData
    let createdAt: Date
    var retryCount: Int

    init(locationData: LocationData) {
        self.id = UUID()
        self.locationData = locationData
        self.createdAt = Date()
        self.retryCount = 0
    }
}

class PendingLocationQueue {
    static let shared = PendingLocationQueue()

    private let storageKey = "pendingLocations"
    private var queue: [PendingLocation] = []

    // Thread synchronization queue
    private let accessQueue = DispatchQueue(label: "com.nexttrack.pendingqueue", attributes: .concurrent)

    // Maximum queue size to prevent unbounded growth
    private let maxQueueSize = 1000

    private init() {
        load()
    }

    var count: Int {
        accessQueue.sync { queue.count }
    }

    var isEmpty: Bool {
        accessQueue.sync { queue.isEmpty }
    }

    func add(_ location: LocationData) {
        accessQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }

            // Enforce max queue size - remove oldest if full
            if self.queue.count >= self.maxQueueSize {
                self.queue.removeFirst()
                print("[PendingQueue] Queue full, removed oldest entry")
            }

            self.queue.append(PendingLocation(locationData: location))
            self.saveInternal()
        }
    }

    func getAll() -> [PendingLocation] {
        accessQueue.sync { queue }
    }

    func remove(id: UUID) {
        accessQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.queue.removeAll { $0.id == id }
            self.saveInternal()
        }
    }

    func incrementRetry(id: UUID) {
        accessQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            if let index = self.queue.firstIndex(where: { $0.id == id }) {
                self.queue[index].retryCount += 1
                self.saveInternal()
            }
        }
    }

    func removeExceedingRetries(maxRetries: Int) {
        accessQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.queue.removeAll { $0.retryCount >= maxRetries }
            self.saveInternal()
        }
    }

    func clear() {
        accessQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.queue.removeAll()
            self.saveInternal()
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let locations = try? JSONDecoder().decode([PendingLocation].self, from: data) else {
            print("[PendingQueue] No saved queue or failed to decode")
            return
        }
        queue = locations
        print("[PendingQueue] Loaded \(queue.count) pending locations")
    }

    // Internal save - must be called within accessQueue barrier
    private func saveInternal() {
        do {
            let data = try JSONEncoder().encode(queue)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("[PendingQueue] Failed to save: \(error.localizedDescription)")
        }
    }
}
