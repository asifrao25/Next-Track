//
//  VisitedMapController.swift
//  Next-track
//
//  Controller for coordinating map zoom actions between VisitedView and VisitedMapView
//

import SwiftUI
import MapKit
import CoreLocation
import Combine

// MARK: - Globe Style Mode

enum GlobeStyleMode: String, CaseIterable {
    case globe = "Globe"        // .hybrid - 3D satellite globe with continent/country names
    case flat = "Flat"          // .standard - flat world map view
}

@MainActor
class VisitedMapController: ObservableObject {
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Background State Management (Prevents Watchdog Crashes)

    /// Whether the app is currently in background - IMMEDIATELY set on scene change
    /// Map overlays should check this flag and skip heavy operations when true
    @Published private(set) var isInBackground = false

    /// Flag to trigger overlay refresh when returning from background
    @Published var needsOverlayRefresh = false

    /// Overlay operations are deferred when this is true
    var shouldDeferOverlayOperations: Bool {
        isInBackground
    }

    // Zoom distance for current location (5M meters = country/region level)
    private let locationZoomDistance: Double = 5_000_000

    // Zoom constraints
    private let minZoomDistance: Double = 1_000       // 1 km - street level
    private let maxGlobeDistance: Double = 40_000_000  // Full 3D globe view
    private let maxFlatDistance: Double = 60_000_000   // Max flat map zoom (shows full world)
    private let zoomFactor: Double = 2.0              // 2x zoom per button press

    // Dynamic max zoom based on current mode
    private var maxZoomDistance: Double {
        globeStyleMode == .globe ? maxGlobeDistance : maxFlatDistance
    }

    // Track if intro animation is complete
    private var introAnimationComplete = false

    // Start fully zoomed out (globe view)
    @Published var cameraPosition: MapCameraPosition = .camera(
        MapCamera(
            centerCoordinate: CLLocationCoordinate2D(latitude: 20, longitude: 0),
            distance: 40_000_000,  // Full globe view
            heading: 0,
            pitch: 0
        )
    )

    @Published var currentDistance: Double = 40_000_000
    private var currentCenter: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 20, longitude: 0)

    // User-controlled globe style mode
    @Published var globeStyleMode: GlobeStyleMode = .globe

    // Map style based on user selection
    var currentMapStyle: MapStyle {
        switch globeStyleMode {
        case .globe:
            // 3D satellite globe with continent/country names
            return .hybrid(elevation: .realistic, pointsOfInterest: .excludingAll)
        case .flat:
            // Flat standard map - clean aesthetic with good world view
            // Uses flat elevation for best zoomed-out appearance
            return .standard(elevation: .flat, pointsOfInterest: .excludingAll)
        }
    }

    /// Toggle between globe and flat map styles
    func toggleGlobeStyle() {
        stopSpinAnimation()
        HapticManager.shared.buttonTap()

        if globeStyleMode == .globe {
            // Switching to flat - zoom out to show world
            globeStyleMode = .flat
            zoomToFlatWorld()
        } else {
            // Switching to globe
            globeStyleMode = .globe
            zoomToGlobe()
        }
    }

    /// Zoom out to show flat world map - optimized for best world view
    private func zoomToFlatWorld() {
        // Center slightly north of equator for balanced view of continents
        // This shows more landmass (most is in northern hemisphere)
        let center = CLLocationCoordinate2D(latitude: 25, longitude: 10)

        self.currentCenter = center
        // Optimal zoom for flat map - shows entire world with good detail
        // 60M meters gives a nice full-world view without excessive distortion
        let flatMapDistance: Double = maxFlatDistance

        withAnimation(.easeOut(duration: 1.0)) {
            self.cameraPosition = .camera(
                MapCamera(
                    centerCoordinate: center,
                    distance: flatMapDistance,
                    heading: 0,
                    pitch: 0
                )
            )
        }
        self.currentDistance = flatMapDistance
    }

    // MARK: - Intro Animation

    private var introTask: Task<Void, Never>?

    // MARK: - Spin Animation

    private var spinTask: Task<Void, Never>?
    @Published var isSpinning = false
    private var currentHeading: Double = 0
    private var spinStartTime: Date?  // Grace period before detecting user interaction

    /// Called when view appears - starts spinning the already zoomed-out globe
    func playIntroAnimation() {
        print("🌍 Starting globe intro")

        // Small delay to let the view settle, then start spinning
        introTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)  // 0.5 second delay

            guard !Task.isCancelled && !isSpinning else { return }
            print("🎬 Starting spin animation")
            introAnimationComplete = true
            startSpinAnimation()
        }
    }

    /// Cancel intro animation
    private func cancelIntroAnimation() {
        introTask?.cancel()
        introTask = nil
        introAnimationComplete = true
    }

    /// Start spin animation (8 seconds per rotation, 60 FPS smooth)
    /// Auto-stops after specified duration to prevent memory leak
    /// - Parameter duration: How long to spin (default 15 seconds for auto-play, longer for manual)
    func startSpinAnimation(duration: TimeInterval = 15.0) {
        guard !isSpinning else { return }

        print("🔄 Starting globe spin animation for \(Int(duration))s")
        isSpinning = true
        currentHeading = 0
        spinStartTime = Date()  // Set start time for grace period

        // Store the current state to use during spin
        let spinDistance = currentDistance

        spinTask = Task { @MainActor in
            let spinDuration: Double = 8.0  // 8 seconds for full 360° rotation
            let frameRate: Double = 60.0  // 60 FPS for smooth animation
            let stepInterval: UInt64 = 16_666_666  // ~16.67ms per step (60 FPS)
            let degreesPerStep = 360.0 / (spinDuration * frameRate)  // 0.75° per step

            print("🔄 Spin loop starting - \(Int(frameRate)) FPS, auto-stop in \(Int(duration))s")

            var currentLongitude: Double = 0
            var frameCount = 0
            let animationStartTime = Date()

            while !Task.isCancelled && isSpinning {
                // Auto-stop after duration to prevent memory leak
                if Date().timeIntervalSince(animationStartTime) > duration {
                    print("🛑 Auto-stopping spin after \(Int(duration))s to save memory")
                    break
                }

                // Rotate globe by changing longitude (not heading)
                currentLongitude += degreesPerStep
                if currentLongitude >= 180 { currentLongitude -= 360 }

                let spinCoordinate = CLLocationCoordinate2D(
                    latitude: 20,  // Keep latitude fixed
                    longitude: currentLongitude
                )

                self.cameraPosition = .camera(
                    MapCamera(
                        centerCoordinate: spinCoordinate,
                        distance: spinDistance,
                        heading: 0,
                        pitch: 0
                    )
                )

                frameCount += 1
                if frameCount % 60 == 0 {  // Log every second
                    print("🔄 Spinning... longitude: \(Int(currentLongitude))°")
                }

                try? await Task.sleep(nanoseconds: stepInterval)
            }

            // Clean up spin state
            self.isSpinning = false
            print("🛑 Globe spin stopped after \(frameCount) frames (\(frameCount / 60)s)")
        }
    }

    /// Manually trigger globe spin (called from UI button)
    func manualSpinGlobe() {
        HapticManager.shared.buttonTap()
        startSpinAnimation(duration: 15.0)  // 15 second spin when manually triggered
    }

    /// Stop spin animation - sets flag FIRST for immediate loop termination
    func stopSpinAnimation() {
        // Set flag FIRST to stop the while loop immediately (prevents race condition)
        isSpinning = false
        spinTask?.cancel()
        spinTask = nil
        spinStartTime = nil
    }

    /// Handle scene phase changes - stop ALL animations when app goes to background
    /// This prevents watchdog timeout (0x8BADF00D) crashes
    ///
    /// CRITICAL: Sets isInBackground flag FIRST to immediately stop overlay operations
    /// MapKit overlay updates can cause watchdog timeout if they run during scene transitions
    func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .background, .inactive:
            // CRITICAL: Set background flag FIRST - this immediately stops overlay operations
            // Must happen before any other cleanup to prevent watchdog crash
            isInBackground = true
            print("[MapController] ⚠️ Entering background - overlay operations deferred")

            // Cancel ALL animations immediately
            introTask?.cancel()
            introTask = nil
            stopSpinAnimation()

        case .active:
            // Delay slightly before re-enabling overlays to let the view settle
            // This prevents a burst of overlay updates during transition
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                guard let self = self else { return }
                self.isInBackground = false
                self.needsOverlayRefresh = true
                print("[MapController] ✅ Returning to foreground - overlays re-enabled")
            }

        @unknown default:
            break
        }
    }

    // MARK: - Zoom Functions

    /// Zoom to user's current location at country level
    func zoomToCurrentLocation() {
        print("🗺️ zoomToCurrentLocation called")

        // Cancel any ongoing animations
        cancelIntroAnimation()
        stopSpinAnimation()

        // Use existing location if available
        if let location = LocationManager.shared.currentLocation {
            print("📍 Using existing location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
            zoomToCountry(at: location.coordinate)
            return
        }

        // No location yet - request one and wait for it
        print("📍 No location, requesting...")
        HapticManager.shared.selectionChanged()

        // Subscribe to location updates
        LocationManager.shared.$currentLocation
            .compactMap { $0 }
            .first()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] location in
                print("📍 Location received: \(location.coordinate.latitude), \(location.coordinate.longitude)")
                self?.zoomToCountry(at: location.coordinate)
            }
            .store(in: &cancellables)

        // Request a single location update
        LocationManager.shared.requestSingleLocation()
    }

    /// Zoom to show country at given coordinate
    private func zoomToCountry(at coordinate: CLLocationCoordinate2D) {
        print("🎯 Zooming to country at: \(coordinate.latitude), \(coordinate.longitude)")

        HapticManager.shared.buttonTap()

        withAnimation(.easeOut(duration: 1.0)) {
            self.cameraPosition = .camera(
                MapCamera(
                    centerCoordinate: coordinate,
                    distance: locationZoomDistance,
                    heading: 0,
                    pitch: 0
                )
            )
        }
        self.currentDistance = locationZoomDistance
        self.currentCenter = coordinate
    }

    /// Zoom out to full globe view
    func zoomToGlobe() {
        print("🌍 Zooming to globe view from distance: \(currentDistance)")

        // Cancel any ongoing animations
        cancelIntroAnimation()
        stopSpinAnimation()

        HapticManager.shared.buttonTap()

        // Update distance first to trigger map style change to imagery
        // This ensures we're in satellite mode before zooming out to globe
        self.currentDistance = maxGlobeDistance

        let globeCenter = CLLocationCoordinate2D(latitude: 20, longitude: 0)
        self.currentCenter = globeCenter

        // Small delay to let style change take effect, then animate zoom
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 50_000_000)  // 50ms

            withAnimation(.easeOut(duration: 1.5)) {
                self.cameraPosition = .camera(
                    MapCamera(
                        centerCoordinate: globeCenter,
                        distance: maxGlobeDistance,
                        heading: 0,
                        pitch: 0
                    )
                )
            }
        }
    }

    /// Zoom in by factor of 2
    func zoomIn() {
        stopSpinAnimation()

        let newDistance = max(currentDistance / zoomFactor, minZoomDistance)
        let center = currentCenter
        print("➕ Zooming in: \(currentDistance) → \(newDistance)")

        HapticManager.shared.selectionChanged()

        withAnimation(.easeOut(duration: 0.5)) {
            self.cameraPosition = .camera(
                MapCamera(
                    centerCoordinate: center,
                    distance: newDistance,
                    heading: 0,
                    pitch: 0
                )
            )
        }
        self.currentDistance = newDistance
    }

    /// Zoom out by factor of 2
    func zoomOut() {
        stopSpinAnimation()

        let newDistance = min(currentDistance * zoomFactor, maxZoomDistance)
        let center = currentCenter
        print("➖ Zooming out: \(currentDistance) → \(newDistance)")

        HapticManager.shared.selectionChanged()

        withAnimation(.easeOut(duration: 0.5)) {
            self.cameraPosition = .camera(
                MapCamera(
                    centerCoordinate: center,
                    distance: newDistance,
                    heading: 0,
                    pitch: 0
                )
            )
        }
        self.currentDistance = newDistance
    }

    /// Get current camera center coordinate
    private func getCurrentCenter() -> CLLocationCoordinate2D {
        return currentCenter
    }

    /// Update camera state from map changes
    func updateFromCamera(_ camera: MapCamera) {
        // If spinning, detect user interaction via zoom (pinch) or latitude change
        // Longitude changes are from our spin animation, so ignore those
        if isSpinning {
            // Short grace period to let camera settle after spin starts
            if let startTime = spinStartTime, Date().timeIntervalSince(startTime) > 0.3 {
                // Detect zoom changes (pinch) - even small pinch should stop
                let zoomChanged = abs(camera.distance - currentDistance) > 500_000  // 500km threshold
                // Detect latitude changes (drag up/down) - we keep lat at 20
                let latitudeChanged = abs(camera.centerCoordinate.latitude - 20) > 2  // 2° threshold

                if zoomChanged || latitudeChanged {
                    print("👆 User interaction detected - zoom: \(zoomChanged), lat: \(latitudeChanged)")
                    stopSpinAnimation()
                    // Update tracking with new values
                    currentDistance = camera.distance
                    currentCenter = camera.centerCoordinate
                    return
                }
            }
            return  // Don't update tracking while spinning
        }

        // Only update tracking when not spinning
        if abs(camera.distance - currentDistance) > 1000 {
            print("📷 Camera distance changed: \(currentDistance) → \(camera.distance)")
        }
        currentDistance = camera.distance
        currentCenter = camera.centerCoordinate
    }
}
