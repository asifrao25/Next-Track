//
//  TrackingStateManager.swift
//  Next-track
//
//  Unified tracking state manager - single source of truth for tracking state
//  Resolves state divergence between MainView, LocationManager, and TrackingHistoryManager
//

import Foundation
import Combine
import CoreLocation

/// Single source of truth for tracking state across the app
/// Coordinates between LocationManager and TrackingHistoryManager to ensure state consistency
class TrackingStateManager: ObservableObject {
    static let shared = TrackingStateManager()

    // MARK: - Published Properties

    /// The definitive tracking state - all UI should bind to this
    @Published private(set) var isTracking: Bool = false

    /// What triggered the current tracking session
    @Published private(set) var trackingSource: TrackingSource = .none

    /// Last state change timestamp for debugging
    @Published private(set) var lastStateChange: Date?

    /// Any error from the last operation
    @Published var lastError: String?

    // MARK: - Types

    enum TrackingSource: String, Codable {
        case none = "None"
        case manual = "Manual"
        case geofenceExit = "Geofence Exit"
        case geofenceEnter = "Geofence Enter"
        case autoStart = "Auto Start"
        case recovery = "Session Recovery"
    }

    // MARK: - Private Properties

    /// Prevents rapid state changes (debouncing)
    private var lastActionTime: Date?
    private let debounceInterval: TimeInterval = 5.0 // 5 seconds minimum between changes

    /// Serial queue for thread-safe state changes
    private let stateQueue = DispatchQueue(label: "com.nexttrack.trackingstate")

    /// Internal flag to track if we're in the middle of a state change
    private var isChangingState = false

    // MARK: - Initialization

    private init() {
        // Sync initial state from LocationManager
        syncStateFromComponents()
    }

    // MARK: - State Synchronization

    /// Synchronize state from existing components (used at startup)
    func syncStateFromComponents() {
        let locationManagerTracking = LocationManager.shared.isTracking
        let hasSession = TrackingHistoryManager.shared.currentSession != nil

        print("[TrackingStateManager] Syncing state - LocationManager: \(locationManagerTracking), HasSession: \(hasSession)")

        // If either is tracking, consider us tracking
        if locationManagerTracking || hasSession {
            isTracking = true
            if trackingSource == .none {
                trackingSource = .recovery // We're recovering existing state
            }
        } else {
            isTracking = false
            trackingSource = .none
        }

        lastStateChange = Date()
    }

    // MARK: - Debouncing

    /// Check if enough time has passed since last action to allow a new one
    func shouldAllowAction() -> Bool {
        guard let lastAction = lastActionTime else {
            return true
        }

        let elapsed = Date().timeIntervalSince(lastAction)
        if elapsed < debounceInterval {
            print("[TrackingStateManager] Debouncing - only \(String(format: "%.1f", elapsed))s since last action (need \(debounceInterval)s)")
            return false
        }

        return true
    }

    /// Check if action should be allowed, considering source priority
    func shouldAllowAction(from source: TrackingSource) -> Bool {
        // Manual actions always bypass debounce
        if source == .manual {
            return true
        }

        return shouldAllowAction()
    }

    // MARK: - Tracking Control

    /// Start tracking with verification
    /// - Parameters:
    ///   - source: What triggered this start request
    ///   - interval: Update interval in seconds
    ///   - accuracy: Minimum accuracy in meters
    /// - Returns: True if tracking was successfully started
    @discardableResult
    func startTracking(source: TrackingSource, interval: TimeInterval? = nil, accuracy: Double? = nil) -> Bool {
        // Debounce check (manual bypasses)
        guard shouldAllowAction(from: source) else {
            print("[TrackingStateManager] Start blocked by debounce")
            return false
        }

        // Already tracking - just update source if needed
        if isTracking {
            print("[TrackingStateManager] Already tracking (source: \(trackingSource.rawValue))")
            return true
        }

        // Prevent concurrent state changes
        guard !isChangingState else {
            print("[TrackingStateManager] State change already in progress")
            return false
        }

        isChangingState = true
        defer { isChangingState = false }

        print("[TrackingStateManager] Starting tracking (source: \(source.rawValue))")

        // Get settings
        let settings = SettingsManager.shared.trackingSettings
        let updateInterval = interval ?? settings.effectiveInterval
        let minAccuracy = accuracy ?? settings.minimumAccuracyMeters

        // Check permissions
        guard LocationManager.shared.hasAnyPermission else {
            lastError = "Location permission not granted"
            print("[TrackingStateManager] Failed - no permission")
            return false
        }

        // Start LocationManager
        LocationManager.shared.startTracking(interval: updateInterval, minimumAccuracy: minAccuracy)

        // Start a new session
        TrackingHistoryManager.shared.startNewSession()

        // Update our state
        DispatchQueue.main.async { [weak self] in
            self?.isTracking = true
            self?.trackingSource = source
            self?.lastStateChange = Date()
            self?.lastActionTime = Date()
            self?.lastError = nil
        }

        // Verify state after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.verifyTrackingState()
        }

        print("[TrackingStateManager] Tracking started successfully")
        return true
    }

    /// Stop tracking with verification
    /// - Parameter source: What triggered this stop request
    /// - Returns: True if tracking was successfully stopped
    @discardableResult
    func stopTracking(source: TrackingSource) -> Bool {
        // Debounce check (manual bypasses)
        guard shouldAllowAction(from: source) else {
            print("[TrackingStateManager] Stop blocked by debounce")
            return false
        }

        // Not tracking - nothing to do
        if !isTracking {
            print("[TrackingStateManager] Not currently tracking")
            return true
        }

        // Prevent concurrent state changes
        guard !isChangingState else {
            print("[TrackingStateManager] State change already in progress")
            return false
        }

        isChangingState = true
        defer { isChangingState = false }

        print("[TrackingStateManager] Stopping tracking (source: \(source.rawValue), was: \(trackingSource.rawValue))")

        // Stop LocationManager
        LocationManager.shared.stopTracking()

        // End the current session
        TrackingHistoryManager.shared.endCurrentSession()

        // Update our state
        DispatchQueue.main.async { [weak self] in
            self?.isTracking = false
            self?.trackingSource = .none
            self?.lastStateChange = Date()
            self?.lastActionTime = Date()
            self?.lastError = nil
        }

        print("[TrackingStateManager] Tracking stopped successfully")
        return true
    }

    // MARK: - State Verification

    /// Verify that all components agree on tracking state
    /// - Returns: True if all components are in sync
    @discardableResult
    func verifyTrackingState() -> Bool {
        let locationManagerTracking = LocationManager.shared.isTracking
        let hasSession = TrackingHistoryManager.shared.currentSession != nil

        let allAgree = (isTracking == locationManagerTracking) && (isTracking == hasSession)

        if !allAgree {
            print("[TrackingStateManager] STATE MISMATCH DETECTED!")
            print("  - TrackingStateManager: \(isTracking)")
            print("  - LocationManager: \(locationManagerTracking)")
            print("  - HasSession: \(hasSession)")

            // Attempt to fix the mismatch
            resolveStateMismatch(locationManagerTracking: locationManagerTracking, hasSession: hasSession)
            return false
        }

        print("[TrackingStateManager] State verified: all components in sync (\(isTracking ? "tracking" : "stopped"))")
        return true
    }

    /// Attempt to resolve a state mismatch between components
    private func resolveStateMismatch(locationManagerTracking: Bool, hasSession: Bool) {
        print("[TrackingStateManager] Attempting to resolve state mismatch...")

        // If we think we're tracking but LocationManager isn't, restart LocationManager
        if isTracking && !locationManagerTracking {
            print("[TrackingStateManager] Restarting LocationManager to match state")
            let settings = SettingsManager.shared.trackingSettings
            LocationManager.shared.startTracking(
                interval: settings.effectiveInterval,
                minimumAccuracy: settings.minimumAccuracyMeters
            )
        }

        // If we think we're tracking but there's no session, create one
        if isTracking && !hasSession {
            print("[TrackingStateManager] Starting session to match state")
            TrackingHistoryManager.shared.startNewSession()
        }

        // If we think we're stopped but LocationManager is tracking, stop it
        if !isTracking && locationManagerTracking {
            print("[TrackingStateManager] Stopping LocationManager to match state")
            LocationManager.shared.stopTracking()
        }

        // If we think we're stopped but there's a session, end it
        if !isTracking && hasSession {
            print("[TrackingStateManager] Ending session to match state")
            TrackingHistoryManager.shared.endCurrentSession()
        }
    }

    // MARK: - Query Methods

    /// Check if currently inside a geofence stop zone
    func isInStopZone() -> Bool {
        guard let zone = GeofenceManager.shared.currentZone else {
            return false
        }

        switch zone.action {
        case .homeMode, .stopOnEnter:
            return true
        default:
            return false
        }
    }

    /// Get a human-readable status string
    var statusDescription: String {
        if isTracking {
            return "Tracking (\(trackingSource.rawValue))"
        } else {
            return "Not Tracking"
        }
    }

    // MARK: - Debug

    func logState() {
        print("========== TrackingStateManager State ==========")
        print("  isTracking: \(isTracking)")
        print("  trackingSource: \(trackingSource.rawValue)")
        print("  lastStateChange: \(lastStateChange?.description ?? "never")")
        print("  lastActionTime: \(lastActionTime?.description ?? "never")")
        print("  LocationManager.isTracking: \(LocationManager.shared.isTracking)")
        print("  HasSession: \(TrackingHistoryManager.shared.currentSession != nil)")
        print("  isInStopZone: \(isInStopZone())")
        print("================================================")
    }
}
