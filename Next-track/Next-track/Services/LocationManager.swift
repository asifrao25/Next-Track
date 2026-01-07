//
//  LocationManager.swift
//  Next-track
//
//  Core Location handling with background support
//

import Foundation
import CoreLocation
import Combine

class LocationManager: NSObject, ObservableObject {
    static let shared = LocationManager()

    private let locationManager = CLLocationManager()

    // Published properties for UI updates
    @Published var currentLocation: CLLocation?
    @Published var lastError: String?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isTracking: Bool = false
    @Published var recentLocations: [CLLocation] = [] // For map track display

    // Location update callback
    var onLocationUpdate: ((CLLocation) -> Void)?

    // Settings
    private var updateInterval: TimeInterval = 60
    private var minimumAccuracy: Double = 100
    private var lastSentLocation: CLLocation?
    private var lastSentTime: Date?

    // Timer for interval-based updates
    private var updateTimer: Timer?

    private let maxRecentLocations = 100 // Keep last 100 points for map display

    private override init() {
        super.init()

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // meters
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.showsBackgroundLocationIndicator = true

        authorizationStatus = locationManager.authorizationStatus
    }

    // MARK: - Permissions

    func requestPermissions() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            locationManager.requestAlwaysAuthorization()
        default:
            break
        }
    }

    var hasFullPermission: Bool {
        locationManager.authorizationStatus == .authorizedAlways
    }

    var hasAnyPermission: Bool {
        [.authorizedAlways, .authorizedWhenInUse].contains(locationManager.authorizationStatus)
    }

    // MARK: - Tracking Control

    func startTracking(interval: TimeInterval, minimumAccuracy: Double = 100) {
        guard hasAnyPermission else {
            lastError = "Location permission not granted"
            return
        }

        self.updateInterval = interval
        self.minimumAccuracy = minimumAccuracy

        locationManager.startUpdatingLocation()
        isTracking = true
        lastError = nil

        // Start interval timer
        startUpdateTimer()

        print("[LocationManager] Started tracking with interval: \(interval)s")
    }

    func stopTracking() {
        locationManager.stopUpdatingLocation()
        stopUpdateTimer()
        isTracking = false
        print("[LocationManager] Stopped tracking")
    }

    func startSignificantLocationMonitoring() {
        guard hasFullPermission else {
            lastError = "Always location permission required for significant location monitoring"
            return
        }

        locationManager.startMonitoringSignificantLocationChanges()
        isTracking = true
        print("[LocationManager] Started significant location monitoring")
    }

    func stopSignificantLocationMonitoring() {
        locationManager.stopMonitoringSignificantLocationChanges()
        isTracking = false
    }

    // MARK: - Update Timer

    private func startUpdateTimer() {
        stopUpdateTimer()

        updateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            self?.sendCurrentLocationIfNeeded()
        }

        // Send immediately on start
        sendCurrentLocationIfNeeded()
    }

    private func stopUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    private func sendCurrentLocationIfNeeded() {
        guard let location = currentLocation else { return }

        // Check accuracy threshold
        if location.horizontalAccuracy > minimumAccuracy {
            print("[LocationManager] Skipping location - accuracy too low: \(location.horizontalAccuracy)m")
            return
        }

        // Check if enough time has passed since last send
        if let lastTime = lastSentTime,
           Date().timeIntervalSince(lastTime) < updateInterval * 0.9 {
            return
        }

        // Trigger callback
        onLocationUpdate?(location)
        lastSentLocation = location
        lastSentTime = Date()
    }

    // MARK: - Single Location Request

    /// Request a single location update (for "center on me" button)
    func requestSingleLocation() {
        guard hasAnyPermission else {
            lastError = "Location permission not granted"
            return
        }

        // Request a single location update
        locationManager.requestLocation()
        print("[LocationManager] Requested single location update")
    }

    // MARK: - Helper Methods

    func updateSettings(interval: TimeInterval, minimumAccuracy: Double) {
        self.updateInterval = interval
        self.minimumAccuracy = minimumAccuracy

        if isTracking {
            startUpdateTimer() // Restart timer with new interval
        }
    }

    func getDistanceFromLastSent() -> Double? {
        guard let current = currentLocation,
              let last = lastSentLocation else { return nil }
        return current.distance(from: last)
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus

        switch manager.authorizationStatus {
        case .authorizedAlways:
            print("[LocationManager] Authorization: Always")
        case .authorizedWhenInUse:
            print("[LocationManager] Authorization: When In Use")
            // Prompt for always authorization
            manager.requestAlwaysAuthorization()
        case .denied, .restricted:
            print("[LocationManager] Authorization: Denied/Restricted")
            lastError = "Location access denied. Please enable in Settings."
        case .notDetermined:
            print("[LocationManager] Authorization: Not Determined")
        @unknown default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        currentLocation = location

        // Add to recent locations for map display
        recentLocations.append(location)
        if recentLocations.count > maxRecentLocations {
            recentLocations.removeFirst()
        }

        print("[LocationManager] Location update: \(location.coordinate.latitude), \(location.coordinate.longitude) | Accuracy: \(location.horizontalAccuracy)m")
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        lastError = error.localizedDescription
        print("[LocationManager] Error: \(error.localizedDescription)")
    }
}
