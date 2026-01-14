//
//  GeofenceManager.swift
//  Been There
//
//  Geofencing for auto start/stop tracking
//

import Foundation
import CoreLocation
import UserNotifications

struct GeofenceZone: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var latitude: Double
    var longitude: Double
    var radius: Double // meters
    var action: GeofenceAction
    var isEnabled: Bool

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var region: CLCircularRegion {
        let region = CLCircularRegion(
            center: coordinate,
            radius: radius,
            identifier: id.uuidString
        )
        region.notifyOnEntry = true
        region.notifyOnExit = true
        return region
    }

    enum GeofenceAction: String, Codable, CaseIterable {
        case homeMode = "Home: Stop inside, Track outside"
        case startOnExit = "Start tracking when leaving"
        case stopOnEnter = "Stop tracking when entering"
        case startOnEnter = "Start tracking when entering"
        case stopOnExit = "Stop tracking when leaving"
    }

    static func createHome(coordinate: CLLocationCoordinate2D, action: GeofenceAction = .homeMode) -> GeofenceZone {
        GeofenceZone(
            id: UUID(),
            name: "Home",
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            radius: 100,
            action: action,
            isEnabled: true
        )
    }
}

class GeofenceManager: NSObject, ObservableObject {
    static let shared = GeofenceManager()

    private let locationManager = CLLocationManager()

    // MARK: - Thread-Safe Zones Storage

    /// Thread synchronization queue for zones array (reader-writer pattern)
    private let zonesQueue = DispatchQueue(label: "com.beenthere.geofence.zones", attributes: .concurrent)
    private var _zones: [GeofenceZone] = []

    /// Thread-safe zones array
    var zones: [GeofenceZone] {
        get { zonesQueue.sync { _zones } }
        set { zonesQueue.async(flags: .barrier) { [weak self] in self?._zones = newValue } }
    }

    @Published var isMonitoring: Bool = false
    @Published var currentZone: GeofenceZone?

    private let storageKey = "geofenceZones"
    private let monitoringStateKey = "geofenceMonitoringEnabled"

    // MARK: - Debouncing

    /// Last geofence action time for debouncing
    private var lastGeofenceAction: Date?

    /// Minimum time between geofence-triggered actions (prevents rapid toggling at boundaries)
    private let debounceInterval: TimeInterval = 5.0

    /// Check if enough time has passed to allow another geofence action
    private func shouldTriggerAction() -> Bool {
        if let lastAction = lastGeofenceAction,
           Date().timeIntervalSince(lastAction) < debounceInterval {
            print("[GeofenceManager] Debouncing - ignoring rapid event (\(String(format: "%.1f", Date().timeIntervalSince(lastAction)))s since last)")
            return false
        }
        lastGeofenceAction = Date()
        return true
    }

    // Callback for triggering tracking
    var onShouldStartTracking: (() -> Void)?
    var onShouldStopTracking: (() -> Void)?

    // MARK: - State Check Completion Tracking

    /// Number of pending state check responses
    private var pendingStateChecks: Int = 0

    /// Completion handler for state check
    private var stateCheckCompletion: (() -> Void)?

    /// Decrement pending state checks and call completion if done
    private func decrementPendingStateChecks() {
        pendingStateChecks = max(0, pendingStateChecks - 1)
        print("[GeofenceManager] Pending state checks: \(pendingStateChecks)")

        if pendingStateChecks == 0, let completion = stateCheckCompletion {
            print("[GeofenceManager] All state checks complete - calling completion")
            stateCheckCompletion = nil
            DispatchQueue.main.async {
                completion()
            }
        }
    }

    private override init() {
        super.init()
        print("[GeofenceManager] ========== INITIALIZING ==========")
        locationManager.delegate = self
        loadZones()
        print("[GeofenceManager] Loaded \(zones.count) zones (\(zones.filter { $0.isEnabled }.count) enabled)")
        loadMonitoringState()

        // Auto-restore monitoring if previously enabled
        restoreMonitoringIfNeeded()
        print("[GeofenceManager] ========== INIT COMPLETE ==========")
    }

    // MARK: - Zone Management

    func addZone(_ zone: GeofenceZone) {
        zones.append(zone)
        saveZones()
        if zone.isEnabled {
            startMonitoringZone(zone)
        }
    }

    func updateZone(_ zone: GeofenceZone) {
        if let index = zones.firstIndex(where: { $0.id == zone.id }) {
            let oldZone = zones[index]
            stopMonitoringZone(oldZone)
            zones[index] = zone
            saveZones()
            if zone.isEnabled {
                startMonitoringZone(zone)
            }
        }
    }

    func deleteZone(_ zone: GeofenceZone) {
        stopMonitoringZone(zone)
        zones.removeAll { $0.id == zone.id }
        saveZones()
    }

    func toggleZone(_ zone: GeofenceZone) {
        if let index = zones.firstIndex(where: { $0.id == zone.id }) {
            zones[index].isEnabled.toggle()
            saveZones()
            if zones[index].isEnabled {
                startMonitoringZone(zones[index])
            } else {
                stopMonitoringZone(zones[index])
            }
        }
    }

    // MARK: - Monitoring

    func startMonitoringAllZones() {
        // Validate permission first
        guard hasRequiredPermission() else {
            print("[GeofenceManager] Cannot start monitoring - need .authorizedAlways permission")
            // Request permission upgrade if only "When In Use"
            if locationManager.authorizationStatus == .authorizedWhenInUse {
                locationManager.requestAlwaysAuthorization()
            }
            return
        }

        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else {
            print("[GeofenceManager] Geofencing not available on this device")
            return
        }

        for zone in zones where zone.isEnabled {
            startMonitoringZone(zone)
        }
        isMonitoring = true
        saveMonitoringState()
        print("[GeofenceManager] Started monitoring \(zones.filter { $0.isEnabled }.count) zones")

        // Check current state for all zones (triggers didDetermineState delegate)
        checkCurrentZoneStates()
    }

    /// Check if user is currently inside any monitored zones
    /// - Parameter completion: Called when all zone state checks have completed
    func checkCurrentZoneStates(completion: (() -> Void)? = nil) {
        let enabledZones = zones.filter { $0.isEnabled }
        print("[GeofenceManager] Checking current zone states for \(enabledZones.count) zones...")

        guard !enabledZones.isEmpty else {
            print("[GeofenceManager] No enabled zones to check")
            completion?()
            return
        }

        // Set up completion tracking
        pendingStateChecks = enabledZones.count
        stateCheckCompletion = completion

        // Request state for each zone
        for zone in enabledZones {
            locationManager.requestState(for: zone.region)
        }

        // Timeout fallback - if delegate never responds, call completion anyway
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            guard let self = self, self.pendingStateChecks > 0 else { return }
            print("[GeofenceManager] State check timeout - forcing completion")
            self.pendingStateChecks = 0
            if let completion = self.stateCheckCompletion {
                self.stateCheckCompletion = nil
                completion()
            }
        }
    }

    func stopMonitoringAllZones() {
        for zone in zones {
            stopMonitoringZone(zone)
        }
        isMonitoring = false
        saveMonitoringState()
        print("[GeofenceManager] Stopped monitoring all zones")
    }

    private func startMonitoringZone(_ zone: GeofenceZone) {
        let region = zone.region
        locationManager.startMonitoring(for: region)
        print("[GeofenceManager] Started monitoring: \(zone.name)")
    }

    private func stopMonitoringZone(_ zone: GeofenceZone) {
        let region = zone.region
        locationManager.stopMonitoring(for: region)
        print("[GeofenceManager] Stopped monitoring: \(zone.name)")
    }

    // MARK: - Add Current Location as Zone

    func addCurrentLocationAsZone(name: String, radius: Double = 100, action: GeofenceZone.GeofenceAction = .startOnExit) {
        guard let location = LocationManager.shared.currentLocation else {
            print("[GeofenceManager] No current location available")
            return
        }

        let zone = GeofenceZone(
            id: UUID(),
            name: name,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            radius: radius,
            action: action,
            isEnabled: true
        )
        addZone(zone)
    }

    // MARK: - Persistence

    private func loadZones() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let loadedZones = try? JSONDecoder().decode([GeofenceZone].self, from: data) else {
            return
        }
        // Use _zones directly during init (before queue is fully set up)
        _zones = loadedZones
    }

    private func saveZones() {
        // Get zones in a thread-safe manner
        let zonesToSave = zones
        do {
            let data = try JSONEncoder().encode(zonesToSave)
            UserDefaults.standard.set(data, forKey: storageKey)

            // Sync to iCloud
            iCloudSyncManager.shared.syncGeofencesNow()
        } catch {
            print("[GeofenceManager] ERROR: Failed to save zones: \(error.localizedDescription)")
        }
    }

    // MARK: - Monitoring State Persistence

    private func loadMonitoringState() {
        // Load the saved monitoring state (but don't apply it yet)
        let wasMonitoring = UserDefaults.standard.bool(forKey: monitoringStateKey)
        print("[GeofenceManager] Loaded monitoring state: \(wasMonitoring)")
    }

    private func saveMonitoringState() {
        UserDefaults.standard.set(isMonitoring, forKey: monitoringStateKey)
        print("[GeofenceManager] Saved monitoring state: \(isMonitoring)")
    }

    private func restoreMonitoringIfNeeded() {
        // Only restore if:
        // 1. Monitoring was previously enabled
        // 2. There are zones to monitor
        // 3. User has proper permissions

        let wasMonitoring = UserDefaults.standard.bool(forKey: monitoringStateKey)
        let enabledZones = zones.filter({ $0.isEnabled })
        let hasEnabledZones = !enabledZones.isEmpty

        print("[GeofenceManager] Restore check - wasMonitoring: \(wasMonitoring), enabledZones: \(enabledZones.count)")

        guard wasMonitoring, hasEnabledZones else {
            print("[GeofenceManager] Skipping restore (wasMonitoring: \(wasMonitoring), hasEnabledZones: \(hasEnabledZones))")
            return
        }

        // Delay slightly to ensure LocationManager is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }

            let hasPermission = self.hasRequiredPermission()
            print("[GeofenceManager] Permission check for restore: \(hasPermission) (status: \(self.locationManager.authorizationStatus.rawValue))")

            guard hasPermission else {
                print("[GeofenceManager] Cannot restore - need .authorizedAlways permission")
                return
            }

            print("[GeofenceManager] Auto-restoring geofence monitoring...")
            self.startMonitoringAllZones()
        }
    }

    private func hasRequiredPermission() -> Bool {
        let status = locationManager.authorizationStatus
        return status == .authorizedAlways
    }

    func checkAndRequestPermissions() -> Bool {
        let status = locationManager.authorizationStatus

        switch status {
        case .authorizedAlways:
            return true
        case .authorizedWhenInUse:
            // Need to upgrade to "Always" for geofencing to work in background
            print("[GeofenceManager] Need 'Always' permission for geofencing")
            locationManager.requestAlwaysAuthorization()
            return false
        case .notDetermined:
            locationManager.requestAlwaysAuthorization()
            return false
        default:
            print("[GeofenceManager] Location permission denied")
            return false
        }
    }

    // MARK: - Notifications

    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - CLLocationManagerDelegate

extension GeofenceManager: CLLocationManagerDelegate {

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let zone = zones.first(where: { $0.id.uuidString == region.identifier }) else { return }

        print("[GeofenceManager] Entered zone: \(zone.name)")
        currentZone = zone

        // Apply debouncing to prevent rapid toggling at boundaries
        guard shouldTriggerAction() else {
            print("[GeofenceManager] Entry action debounced for \(zone.name)")
            return
        }

        switch zone.action {
        case .homeMode, .stopOnEnter:
            sendNotification(title: "📍 Arrived at \(zone.name)", body: "Stopping location tracking...")
            onShouldStopTracking?()
        case .startOnEnter:
            sendNotification(title: "📍 Entered \(zone.name)", body: "Starting location tracking...")
            onShouldStartTracking?()
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard let zone = zones.first(where: { $0.id.uuidString == region.identifier }) else { return }

        print("[GeofenceManager] Exited zone: \(zone.name)")
        currentZone = nil

        // Apply debouncing to prevent rapid toggling at boundaries
        guard shouldTriggerAction() else {
            print("[GeofenceManager] Exit action debounced for \(zone.name)")
            return
        }

        switch zone.action {
        case .homeMode, .startOnExit:
            sendNotification(title: "📍 Left \(zone.name)", body: "Starting location tracking...")
            onShouldStartTracking?()
        case .stopOnExit:
            sendNotification(title: "📍 Left \(zone.name)", body: "Stopping location tracking...")
            onShouldStopTracking?()
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        print("[GeofenceManager] Monitoring failed for region: \(region?.identifier ?? "unknown") - \(error.localizedDescription)")
    }

    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        guard let zone = zones.first(where: { $0.id.uuidString == region.identifier }) else {
            // Notify completion if this was the last pending state check
            decrementPendingStateChecks()
            return
        }

        let stateString = state == .inside ? "INSIDE" : (state == .outside ? "OUTSIDE" : "UNKNOWN")
        print("[GeofenceManager] State check: \(zone.name) = \(stateString)")

        // Track this for state check completion callback
        decrementPendingStateChecks()

        // If user is currently inside the zone, trigger the "enter" action
        if state == .inside {
            print("[GeofenceManager] User is inside \(zone.name) - triggering enter action")
            currentZone = zone

            // Apply debouncing to prevent rapid toggling
            guard shouldTriggerAction() else {
                print("[GeofenceManager] State action debounced for \(zone.name)")
                return
            }

            switch zone.action {
            case .homeMode, .stopOnEnter:
                sendNotification(title: "📍 At \(zone.name)", body: "Stopping location tracking...")
                onShouldStopTracking?()
            case .startOnEnter:
                sendNotification(title: "📍 At \(zone.name)", body: "Starting location tracking...")
                onShouldStartTracking?()
            default:
                break
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        print("[GeofenceManager] Authorization changed: \(status.rawValue)")

        // If we now have always permission and monitoring was enabled, restart
        let wasMonitoring = UserDefaults.standard.bool(forKey: monitoringStateKey)
        let hasEnabledZones = !zones.filter({ $0.isEnabled }).isEmpty

        if status == .authorizedAlways && wasMonitoring && hasEnabledZones {
            print("[GeofenceManager] Permission granted - restoring monitoring")
            startMonitoringAllZones()
        }

        // If permission was revoked, stop monitoring
        if status == .denied || status == .restricted {
            print("[GeofenceManager] Permission revoked - stopping monitoring")
            stopMonitoringAllZones()
        }
    }
}
