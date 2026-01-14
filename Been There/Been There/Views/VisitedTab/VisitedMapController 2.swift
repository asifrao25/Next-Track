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

@MainActor
class VisitedMapController: ObservableObject {
    private var cancellables = Set<AnyCancellable>()

    // Zoom distance for current location (5M meters = country/region level)
    private let locationZoomDistance: Double = 5_000_000

    // Zoom constraints
    private let minZoomDistance: Double = 1_000       // 1 km - street level
    private let maxZoomDistance: Double = 40_000_000  // Full globe
    private let zoomFactor: Double = 2.0              // 2x zoom per button press

    // Track if intro animation is complete
    private var introAnimationComplete = false

    // Start zoomed in (will animate out on appear)
    @Published var cameraPosition: MapCameraPosition = .camera(
        MapCamera(
            centerCoordinate: CLLocationCoordinate2D(latitude: 30, longitude: 0),
            distance: 10_000_000,  // Start zoomed in
            heading: 0,
            pitch: 0
        )
    )

    @Published var currentDistance: Double = 10_000_000
    private var currentCenter: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 30, longitude: 0)

    // Dynamic map style based on zoom level
    var currentMapStyle: MapStyle {
        if currentDistance < 3_000_000 {
            return .standard(elevation: .realistic, pointsOfInterest: .including([.airport, .nationalPark, .park]))
        } else {
            return .imagery(elevation: .realistic)
        }
    }

    // MARK: - Intro Animation

    private var introTask: Task<Void, Never>?

    /// Called when view appears - zooms out from zoomed-in state to full globe
    func playIntroAnimation() {
        print("🌍 Playing intro zoom-out animation")
        introAnimationComplete = false

        introTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 800_000_000)  // 0.8 seconds

            // Check if cancelled (user tapped a button)
            guard !Task.isCancelled else {
                print("🛑 Intro animation cancelled")
                return
            }

            print("🎬 Starting animation NOW")

            // Use camera with max distance MapKit allows (~40M)
            let globeCenter = CLLocationCoordinate2D(latitude: 20, longitude: 0)
            withAnimation(.easeOut(duration: 2.0)) {
                self.cameraPosition = .camera(
                    MapCamera(
                        centerCoordinate: globeCenter,
                        distance: 40_000_000,
                        heading: 0,
                        pitch: 0
                    )
                )
            }
            self.currentDistance = 40_000_000
            self.currentCenter = globeCenter

            // Mark intro as complete after animation
            try? await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds
            self.introAnimationComplete = true
            print("✅ Intro animation complete")
        }
    }

    /// Cancel any ongoing intro animation
    private func cancelIntroAnimation() {
        introTask?.cancel()
        introTask = nil
        introAnimationComplete = true
    }

    // MARK: - Zoom Functions

    /// Zoom to user's current location at country level
    func zoomToCurrentLocation() {
        print("🗺️ zoomToCurrentLocation called")

        // Cancel any ongoing intro animation
        cancelIntroAnimation()

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

        // Cancel any ongoing intro animation
        cancelIntroAnimation()

        HapticManager.shared.buttonTap()

        // Update distance first to trigger map style change to imagery
        // This ensures we're in satellite mode before zooming out to globe
        self.currentDistance = maxZoomDistance

        let globeCenter = CLLocationCoordinate2D(latitude: 20, longitude: 0)
        self.currentCenter = globeCenter

        // Small delay to let style change take effect, then animate zoom
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 50_000_000)  // 50ms

            withAnimation(.easeOut(duration: 1.5)) {
                self.cameraPosition = .camera(
                    MapCamera(
                        centerCoordinate: globeCenter,
                        distance: maxZoomDistance,
                        heading: 0,
                        pitch: 0
                    )
                )
            }
        }
    }

    /// Zoom in by factor of 2
    func zoomIn() {
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
        // Log what MapKit actually sets the distance to (might be capped)
        if abs(camera.distance - currentDistance) > 1000 {
            print("📷 Camera distance changed: \(currentDistance) → \(camera.distance)")
        }
        currentDistance = camera.distance
        currentCenter = camera.centerCoordinate
    }
}
