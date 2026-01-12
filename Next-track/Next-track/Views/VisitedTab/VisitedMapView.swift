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
    private let longPressDuration: TimeInterval = 1.0

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
                            // Only start timer on initial touch
                            if pressStartTime == nil && !hasFiredLongPress {
                                pressStartTime = Date()

                                // Store touch location for coordinate conversion
                                let touchLocation = value.location

                                // Start timer - will fire after 1 second while finger still down
                                pressTimer = Timer.scheduledTimer(withTimeInterval: longPressDuration, repeats: false) { _ in
                                    DispatchQueue.main.async {
                                        guard !hasFiredLongPress else { return }
                                        hasFiredLongPress = true

                                        // Convert touch location to map coordinate
                                        if let coordinate = proxy.convert(touchLocation, from: .local) {
                                            handleLongPress(at: coordinate)
                                        }
                                    }
                                }
                            }
                        }
                        .onEnded { _ in
                            // Clean up when finger lifted
                            pressTimer?.invalidate()
                            pressTimer = nil
                            pressStartTime = nil
                            hasFiredLongPress = false
                        }
                )
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
