//
//  VisitedMapView.swift
//  Next-track
//
//  3D rotatable globe showing visited countries and cities
//  Cities appear as pin markers when zoomed in past threshold
//  Map style changes from imagery to standard when zoomed in for better visibility
//

import SwiftUI
import MapKit
import CoreLocation

struct VisitedMapView: View {
    @ObservedObject var countriesManager = CountriesManager.shared
    @ObservedObject var cityTracker = CityTracker.shared
    @ObservedObject var mapController: VisitedMapController
    @StateObject private var searchCompleter = CitySearchCompleter()

    @Environment(\.scenePhase) private var scenePhase
    @State private var isMapActive = true
    @State private var selectedCountry: VisitedCountry?
    @State private var selectedCity: VisitedCity?

    // Long-press to add city
    @State private var longPressLocation: CLLocationCoordinate2D?
    @State private var pendingCityResult: CitySearchResult?
    @State private var showAddCityConfirmation = false
    @State private var isReverseGeocoding = false

    // Long-press gesture tracking
    @State private var pressStartTime: Date?
    @State private var pressTimer: Timer?
    @State private var hasFiredLongPress = false
    @State private var isFingerDown = false  // Track if finger is currently pressed
    private let longPressDuration: TimeInterval = 2.0  // 1s delay + 1s ring fill

    // Long-press timer overlay
    @State private var showTimerOverlay = false
    @State private var timerProgress: CGFloat = 0.0
    @State private var timerTouchLocation: CGPoint = .zero
    @State private var progressTimer: Timer?

    // Zoom thresholds
    private let cityMarkerZoomThreshold: Double = 5_000_000

    private var shouldShowCityMarkers: Bool {
        mapController.currentDistance < cityMarkerZoomThreshold
    }

    private var visitedIsoCodes: Set<String> {
        Set(countriesManager.visitedCountries.map { $0.isoCode.uppercased() })
    }

    var body: some View {
        ZStack {
            // Only render map when app is active to prevent watchdog timeout
            if isMapActive {
                // Main globe map with MapReader for coordinate conversion
                MapReader { proxy in
                    Map(position: $mapController.cameraPosition, interactionModes: .all) {
                    // Country flag pins for visited countries
                    ForEach(countriesManager.visitedCountries) { country in
                        if let center = CountriesManager.shared.getCountryCenter(isoCode: country.isoCode) {
                            Annotation("", coordinate: center) {
                                CountryFlagPinView(flag: country.flagEmoji)
                                    .onTapGesture {
                                        HapticManager.shared.selectionChanged()
                                        selectedCountry = country
                                    }
                            }
                        }
                    }

                    // City pin markers (visible when zoomed in)
                    if shouldShowCityMarkers {
                        ForEach(cityTracker.visitedCities) { city in
                            Annotation("", coordinate: CLLocationCoordinate2D(latitude: city.latitude, longitude: city.longitude)) {
                                PinMarkerView(cityName: city.name, showLabel: false)
                                    .onTapGesture {
                                        HapticManager.shared.selectionChanged()
                                        selectedCity = city
                                    }
                            }
                            .annotationTitles(.hidden)
                        }
                    }

                    // Temporary pin for long-press location
                    if let location = longPressLocation {
                        Annotation("", coordinate: location) {
                            PendingPinMarkerView(isLoading: isReverseGeocoding)
                        }
                    }
                }
                .mapStyle(mapController.currentMapStyle)
                .onMapCameraChange { context in
                    mapController.updateFromCamera(context.camera)
                }
                // Long press detection using timer - fires while finger is still down
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            // Mark finger as down
                            isFingerDown = true

                            // Only start timer on initial touch
                            if pressStartTime == nil && !hasFiredLongPress {
                                pressStartTime = Date()

                                // Store touch location for coordinate conversion and overlay
                                let touchLocation = value.location
                                timerTouchLocation = touchLocation

                                // Timer overlay starts hidden, appears after 1 second delay
                                timerProgress = 0.0
                                showTimerOverlay = false

                                let timerShowDelay: TimeInterval = 1.0  // Show ring after 1 second
                                let ringDuration: TimeInterval = longPressDuration - timerShowDelay  // Ring fills over remaining time

                                // Start progress timer - updates every 50ms for smooth animation
                                let updateInterval: TimeInterval = 0.05
                                progressTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { timer in
                                    DispatchQueue.main.async {
                                        // CRITICAL: Stop immediately if finger lifted
                                        guard isFingerDown else {
                                            timer.invalidate()
                                            progressTimer = nil
                                            showTimerOverlay = false
                                            timerProgress = 0.0
                                            return
                                        }

                                        guard let startTime = pressStartTime, !hasFiredLongPress else {
                                            timer.invalidate()
                                            progressTimer = nil
                                            showTimerOverlay = false
                                            timerProgress = 0.0
                                            return
                                        }

                                        let elapsed = Date().timeIntervalSince(startTime)

                                        // Show timer ring after 1 second delay
                                        if elapsed >= timerShowDelay && !showTimerOverlay {
                                            showTimerOverlay = true
                                            HapticManager.shared.light()  // Haptic when ring appears
                                        }

                                        // Calculate progress (0-1) for the ring fill phase
                                        if elapsed >= timerShowDelay {
                                            let ringElapsed = elapsed - timerShowDelay
                                            let newProgress = min(ringElapsed / ringDuration, 1.0)
                                            timerProgress = CGFloat(newProgress)
                                        }

                                        // Check if we've reached the full threshold AND finger still down
                                        if elapsed >= longPressDuration && isFingerDown {
                                            timer.invalidate()
                                            progressTimer = nil
                                            hasFiredLongPress = true
                                            showTimerOverlay = false
                                            timerProgress = 0.0

                                            // Convert touch location to map coordinate
                                            if let coordinate = proxy.convert(touchLocation, from: .local) {
                                                handleLongPress(at: coordinate)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .onEnded { _ in
                            // Mark finger as lifted FIRST
                            isFingerDown = false

                            // Clean up timers and state
                            pressTimer?.invalidate()
                            pressTimer = nil
                            progressTimer?.invalidate()
                            progressTimer = nil
                            pressStartTime = nil
                            hasFiredLongPress = false
                            showTimerOverlay = false
                            timerProgress = 0.0
                        }
                )
            }
            } else {
                // Placeholder while app is in background - prevents watchdog timeout
                Color.black
            }

            // Long-press timer overlay - positioned above touch point so finger doesn't hide it
            if showTimerOverlay {
                GeometryReader { geometry in
                    LongPressTimerView(progress: timerProgress)
                        .position(
                            x: timerTouchLocation.x,
                            y: timerTouchLocation.y - 80  // Offset above finger
                        )
                        .allowsHitTesting(false)
                }
                .allowsHitTesting(false)
            }
        }
        // Country detail sheet
        .sheet(item: $selectedCountry) { country in
            NavigationStack {
                CountryDetailView(country: country)
            }
            .presentationDetents([.medium, .large])
        }
        // City detail sheet (simple for now)
        .sheet(item: $selectedCity) { city in
            CityDetailSheet(city: city)
                .presentationDetents([.medium])
        }
        // Long-press add city confirmation
        .alert("Add City?", isPresented: $showAddCityConfirmation) {
            Button("Add") {
                confirmAddCity()
            }
            Button("Cancel", role: .cancel) {
                cancelAddCity()
            }
        } message: {
            if let result = pendingCityResult {
                Text("Add \(result.displayName) to your visited cities?")
            } else {
                Text("Unable to identify location")
            }
        }
        .onAppear {
            mapController.playIntroAnimation()
        }
        // Pause map rendering when app goes to background to prevent watchdog timeout
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                isMapActive = false
            case .active:
                // Small delay to ensure smooth transition back
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isMapActive = true
                }
            default:
                break
            }
        }
    }

    // MARK: - Long Press Handling

    private func handleLongPress(at coordinate: CLLocationCoordinate2D) {
        // Haptic feedback
        HapticManager.shared.heavy()

        // Show temporary pin
        longPressLocation = coordinate
        isReverseGeocoding = true

        // Reverse geocode to get city info
        Task {
            if let result = await searchCompleter.reverseGeocode(coordinate: coordinate) {
                await MainActor.run {
                    pendingCityResult = result
                    isReverseGeocoding = false
                    showAddCityConfirmation = true
                    HapticManager.shared.success()
                }
            } else {
                await MainActor.run {
                    isReverseGeocoding = false
                    longPressLocation = nil
                    HapticManager.shared.error()
                }
            }
        }
    }

    private func confirmAddCity() {
        guard let result = pendingCityResult else { return }

        cityTracker.addManualCity(
            name: result.name,
            state: result.state,
            country: result.country,
            countryCode: result.countryCode,
            latitude: result.latitude,
            longitude: result.longitude
        )

        // Clear state
        longPressLocation = nil
        pendingCityResult = nil
        HapticManager.shared.success()
    }

    private func cancelAddCity() {
        longPressLocation = nil
        pendingCityResult = nil
    }
}

// MARK: - City Detail Sheet

struct CityDetailSheet: View {
    let city: VisitedCity
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var cityTracker = CityTracker.shared

    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Flag and city info
                VStack(spacing: 8) {
                    Text(city.flagEmoji)
                        .font(.system(size: 60))

                    Text(city.name)
                        .font(.title)
                        .fontWeight(.bold)

                    if let state = city.state {
                        Text("\(state), \(city.country)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text(city.country)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 20)

                // Stats
                HStack(spacing: 30) {
                    VStack {
                        Text("\(city.visitCount)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(
                                LinearGradient(colors: [.red, .orange], startPoint: .leading, endPoint: .trailing)
                            )
                        Text("Visits")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    VStack {
                        Text(city.firstVisitDate, style: .date)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("First Visit")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)

                Spacer()

                // Delete button
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                    HapticManager.shared.warning()
                } label: {
                    HStack {
                        Image(systemName: "trash.fill")
                        Text("Remove City")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [.red.opacity(0.8), .red],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
                .padding(.bottom, 20)
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog(
                "Remove \(city.name)?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Remove", role: .destructive) {
                    cityTracker.removeCity(city)
                    HapticManager.shared.success()
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will remove \(city.name) from your visited cities. This action cannot be undone.")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VisitedMapView(mapController: VisitedMapController())
}
