//
//  LocationManager.swift
//  Next-track
//
//  Core Location handling with background support
//

import Foundation
import CoreLocation
import Combine
import UserNotifications

class LocationManager: NSObject, ObservableObject {
    static let shared = LocationManager()

    private let locationManager = CLLocationManager()

    // Published properties for UI updates
    @Published var currentLocation: CLLocation?
    @Published var lastError: String?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isTracking: Bool = false
    @Published var recentLocations: [CLLocation] = [] // For map track display
    @Published var isInStationaryMode: Bool = false  // Smart tracking state
    @Published var currentFrequencyMultiplier: Double = 1.0  // For UI display

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

    // MARK: - Smart Movement Tracking Properties

    /// Whether smart movement tracking is enabled
    var smartTrackingEnabled: Bool = true

    /// Location where we last detected significant movement
    private var lastSignificantLocation: CLLocation?

    /// When we started being stationary (GPS-based)
    private var stationarySince: Date?

    /// Current frequency tier index
    private var currentTierIndex: Int = 0

    /// Movement threshold in meters - if user moves less than this, considered stationary
    private let movementThreshold: Double = 20.0

    /// Progressive frequency tiers: (stationary duration in seconds, multiplier)
    private let frequencyTiers: [(duration: TimeInterval, multiplier: Double, name: String)] = [
        (0, 1.0, "Normal"),           // Normal frequency
        (60, 2.0, "Reduced"),         // 1 min stationary → 2x interval
        (180, 4.0, "Low"),            // 3 min → 4x
        (300, 8.0, "Very Low"),       // 5 min → 8x
        (600, 15.0, "Minimal"),       // 10 min → 15x
        (900, 30.0, "Ultra Low")      // 15 min → 30x (max)
    ]

    /// Whether we've sent the stationary mode notification
    private var hasSentStationaryNotification: Bool = false

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

    /// Start location tracking
    /// - Parameters:
    ///   - interval: Update interval in seconds
    ///   - minimumAccuracy: Minimum required accuracy in meters
    /// - Returns: True if tracking started successfully
    @discardableResult
    func startTracking(interval: TimeInterval, minimumAccuracy: Double = 100) -> Bool {
        guard hasAnyPermission else {
            lastError = "Location permission not granted"
            print("[LocationManager] Failed to start: no permission")
            return false
        }

        self.updateInterval = interval
        self.minimumAccuracy = minimumAccuracy

        // Load smart tracking setting
        smartTrackingEnabled = SettingsManager.shared.trackingSettings.smartMovementTrackingEnabled

        locationManager.startUpdatingLocation()
        isTracking = true
        lastError = nil

        // Start interval timer
        startUpdateTimer()

        print("[LocationManager] Started tracking with interval: \(interval)s, smart tracking: \(smartTrackingEnabled)")
        return true
    }

    /// Stop location tracking
    /// - Returns: True if tracking was stopped (or already stopped)
    @discardableResult
    func stopTracking() -> Bool {
        locationManager.stopUpdatingLocation()
        stopUpdateTimer()
        isTracking = false
        print("[LocationManager] Stopped tracking")
        return true
    }

    /// Start significant location change monitoring (low power mode)
    /// - Returns: True if monitoring started successfully
    @discardableResult
    func startSignificantLocationMonitoring() -> Bool {
        guard hasFullPermission else {
            lastError = "Always location permission required for significant location monitoring"
            print("[LocationManager] Failed to start significant monitoring: need Always permission")
            return false
        }

        locationManager.startMonitoringSignificantLocationChanges()
        isTracking = true
        print("[LocationManager] Started significant location monitoring")
        return true
    }

    /// Stop significant location change monitoring
    /// - Returns: True if monitoring was stopped (or already stopped)
    @discardableResult
    func stopSignificantLocationMonitoring() -> Bool {
        locationManager.stopMonitoringSignificantLocationChanges()
        isTracking = false
        print("[LocationManager] Stopped significant location monitoring")
        return true
    }

    // MARK: - Update Timer (Smart Movement Tracking)

    private func startUpdateTimer() {
        stopUpdateTimer()
        resetSmartTrackingState()
        scheduleNextUpdate()

        // Send immediately on start
        sendCurrentLocationIfNeeded()
    }

    private func stopUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = nil
        resetSmartTrackingState()
    }

    /// Reset smart tracking state to normal
    private func resetSmartTrackingState() {
        currentTierIndex = 0
        stationarySince = nil
        lastSignificantLocation = nil
        isInStationaryMode = false
        currentFrequencyMultiplier = 1.0
        hasSentStationaryNotification = false
    }

    /// Schedule the next location update based on current frequency tier
    private func scheduleNextUpdate() {
        updateTimer?.invalidate()

        let tier = frequencyTiers[currentTierIndex]
        let interval = updateInterval * tier.multiplier
        currentFrequencyMultiplier = tier.multiplier

        updateTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.sendCurrentLocationIfNeeded()
            self?.scheduleNextUpdate()
        }

        print("[LocationManager] Scheduled next update in \(Int(interval))s (tier: \(tier.name), \(tier.multiplier)x)")
    }

    private func sendCurrentLocationIfNeeded() {
        guard let location = currentLocation else { return }

        // Check accuracy threshold
        if location.horizontalAccuracy > minimumAccuracy {
            print("[LocationManager] Skipping location - accuracy too low: \(location.horizontalAccuracy)m")
            return
        }

        // Smart tracking: Check for movement
        if smartTrackingEnabled {
            checkMovementAndUpdateTier(location)
        }

        // Check if enough time has passed since last send (with current multiplier)
        let effectiveInterval = updateInterval * currentFrequencyMultiplier
        if let lastTime = lastSentTime,
           Date().timeIntervalSince(lastTime) < effectiveInterval * 0.9 {
            return
        }

        // Trigger callback
        onLocationUpdate?(location)
        lastSentLocation = location
        lastSentTime = Date()
    }

    // MARK: - Smart Movement Detection

    /// Check if user has moved and update frequency tier accordingly
    private func checkMovementAndUpdateTier(_ location: CLLocation) {
        // Initialize significant location if needed
        if lastSignificantLocation == nil {
            lastSignificantLocation = location
            return
        }

        let distance = location.distance(from: lastSignificantLocation!)

        if distance > movementThreshold {
            // User has moved! Reset to normal frequency
            handleMovementDetected(location)
        } else {
            // User is stationary
            handleStationaryState()
        }
    }

    /// Called when significant movement is detected
    private func handleMovementDetected(_ location: CLLocation) {
        let wasStationary = isInStationaryMode

        // Reset to normal frequency
        lastSignificantLocation = location
        stationarySince = nil
        currentTierIndex = 0
        isInStationaryMode = false
        currentFrequencyMultiplier = 1.0

        if wasStationary {
            print("[LocationManager] 🚶 Movement detected! Resuming normal tracking frequency")

            // Reschedule with normal frequency
            scheduleNextUpdate()

            // Send notification that tracking resumed
            sendMovementResumedNotification()
            hasSentStationaryNotification = false
        }
    }

    /// Called when user appears to be stationary
    private func handleStationaryState() {
        // Start tracking stationary time if not already
        if stationarySince == nil {
            stationarySince = Date()
        }

        let stationaryDuration = Date().timeIntervalSince(stationarySince!)

        // Find appropriate tier based on duration
        var newTierIndex = 0
        for (index, tier) in frequencyTiers.enumerated() {
            if stationaryDuration >= tier.duration {
                newTierIndex = index
            }
        }

        // If tier changed, update and reschedule
        if newTierIndex > currentTierIndex {
            let oldTier = frequencyTiers[currentTierIndex]
            let newTier = frequencyTiers[newTierIndex]
            currentTierIndex = newTierIndex
            currentFrequencyMultiplier = newTier.multiplier

            print("[LocationManager] 💤 Stationary for \(Int(stationaryDuration))s - reducing frequency: \(oldTier.name) → \(newTier.name) (\(newTier.multiplier)x)")

            // Enter stationary mode on first reduction
            if !isInStationaryMode && newTierIndex >= 1 {
                isInStationaryMode = true

                // Send notification only once per stationary session
                if !hasSentStationaryNotification {
                    sendStationaryModeNotification()
                    hasSentStationaryNotification = true
                }
            }

            // Reschedule with new interval
            scheduleNextUpdate()
        }
    }

    // MARK: - Notifications

    /// Send notification when entering stationary mode
    private func sendStationaryModeNotification() {
        let content = UNMutableNotificationContent()
        content.title = "💤 Low Movement Detected"
        content.body = "Tracking frequency reduced to save battery. Will resume when you start moving."
        content.sound = .default
        content.interruptionLevel = .passive

        let request = UNNotificationRequest(
            identifier: "stationaryMode-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[LocationManager] Failed to send stationary notification: \(error)")
            } else {
                print("[LocationManager] Sent stationary mode notification")
            }
        }
    }

    /// Send notification when movement is detected and tracking resumes
    private func sendMovementResumedNotification() {
        let content = UNMutableNotificationContent()
        content.title = "🚶 Movement Detected"
        content.body = "Tracking resumed at normal frequency."
        content.sound = .default
        content.interruptionLevel = .passive

        let request = UNNotificationRequest(
            identifier: "movementResumed-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[LocationManager] Failed to send movement notification: \(error)")
            } else {
                print("[LocationManager] Sent movement resumed notification")
            }
        }
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
