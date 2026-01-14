//
//  VisitedView.swift
//  Next-track
//
//  Combined view for visited countries and cities
//  Globe view by default, with list toggle and add options
//

import SwiftUI
import MapKit

struct VisitedView: View {
    @ObservedObject var countriesManager = CountriesManager.shared
    @ObservedObject var cityTracker = CityTracker.shared
    @ObservedObject var locationManager = LocationManager.shared
    @ObservedObject var settingsManager = SettingsManager.shared
    @StateObject private var mapController = VisitedMapController()
    @StateObject private var connectionMonitor = ConnectionMonitor.shared
    @StateObject private var batteryMonitor = BatteryMonitor.shared
    @StateObject private var historyManager = TrackingHistoryManager.shared
    @StateObject private var geofenceManager = GeofenceManager.shared

    @State private var showListView = false
    @State private var showAddActionSheet = false
    @State private var showAddCountrySheet = false
    @State private var showAddCitySheet = false
    @State private var showPhotoImport = false
    @State private var selectedSort: CountrySortOption = .recentVisit

    var body: some View {
        NavigationStack {
            ZStack {
                // Main content
                if !showListView {
                    // Globe/Map view (default)
                    VisitedMapView(mapController: mapController)
                        .ignoresSafeArea(edges: .bottom)
                } else {
                    // List view - add top padding to account for header overlay
                    CountriesListView(
                        countries: countriesManager.visitedCountries,
                        selectedSort: $selectedSort
                    )
                    .padding(.top, 120) // Space for header + stats bar
                }

                // Header overlay at top
                VStack(spacing: 8) {
                    CustomTitleHeaderView(
                        connectionMonitor: connectionMonitor,
                        batteryMonitor: batteryMonitor,
                        isTracking: locationManager.isTracking,
                        hasIssues: false,
                        pendingCount: PendingLocationQueue.shared.count,
                        currentZoneName: geofenceManager.currentZone?.name,
                        connectionStatus: .connected,
                        lastSuccessfulSend: settingsManager.trackingStats.lastSuccessfulSend,
                        todayMiles: historyManager.todaysDistance / 1609.344,
                        sessionDuration: historyManager.currentSession?.duration ?? 0,
                        pointsSent: settingsManager.trackingStats.pointsSentToday,
                        currentElevation: locationManager.currentLocation?.altitude,
                        accentColor: .purple
                    )
                    .padding(.horizontal, 4)

                    // Stats bar - Countries and Cities count
                    HStack(spacing: 20) {
                        // Countries stat
                        HStack(spacing: 6) {
                            Image(systemName: "flag.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(
                                    LinearGradient(colors: [.teal, .purple], startPoint: .leading, endPoint: .trailing)
                                )
                            Text("Countries:")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                            Text("\(countriesManager.visitedCountries.count)/195")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(
                                    LinearGradient(colors: [.teal, .purple], startPoint: .leading, endPoint: .trailing)
                                )
                        }

                        // Divider
                        Rectangle()
                            .fill(Color.secondary.opacity(0.3))
                            .frame(width: 1, height: 16)

                        // Cities stat
                        HStack(spacing: 6) {
                            Image(systemName: "building.2.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(
                                    LinearGradient(colors: [.purple, .teal], startPoint: .leading, endPoint: .trailing)
                                )
                            Text("Cities:")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                            Text("\(cityTracker.visitedCities.count)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(
                                    LinearGradient(colors: [.purple, .teal], startPoint: .leading, endPoint: .trailing)
                                )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    )
                    .overlay(
                        Capsule()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.3),
                                        Color.teal.opacity(0.2),
                                        Color.white.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.5
                            )
                    )

                    Spacer()
                }

                // Bottom controls (flush with navbar) - both left and right in same row
                if !showListView {
                    VStack {
                        Spacer()

                        HStack(alignment: .bottom) {
                            // Left controls - Add and List toggle
                            HStack(spacing: 12) {
                                // Add button
                                VisitedControlButton(icon: "plus") {
                                    showAddActionSheet = true
                                }

                                // List/Globe toggle
                                VisitedControlButton(icon: "list.bullet") {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        showListView.toggle()
                                    }
                                    HapticManager.shared.buttonTap()
                                }
                            }
                            .padding(8)
                            .background(
                                Capsule()
                                    .fill(.ultraThinMaterial)
                                    .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
                            )
                            .overlay(
                                Capsule()
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.3),
                                                Color.teal.opacity(0.2),
                                                Color.white.opacity(0.1)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )

                            Spacer()

                            // Right controls - Zoom controls
                            HStack(spacing: 12) {
                                // Current location
                                VisitedControlButton(icon: "location.fill") {
                                    mapController.zoomToCurrentLocation()
                                }

                                // Globe view
                                VisitedControlButton(icon: "globe") {
                                    mapController.zoomToGlobe()
                                }

                                // Zoom in
                                VisitedControlButton(icon: "plus.magnifyingglass") {
                                    mapController.zoomIn()
                                }

                                // Zoom out
                                VisitedControlButton(icon: "minus.magnifyingglass") {
                                    mapController.zoomOut()
                                }
                            }
                            .padding(8)
                            .background(
                                Capsule()
                                    .fill(.ultraThinMaterial)
                                    .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
                            )
                            .overlay(
                                Capsule()
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.3),
                                                Color.teal.opacity(0.2),
                                                Color.white.opacity(0.1)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 90) // Flush with tab bar
                    }
                } else {
                    // List view controls - just add and globe toggle
                    VStack {
                        Spacer()

                        HStack(alignment: .bottom) {
                            HStack(spacing: 12) {
                                VisitedControlButton(icon: "plus") {
                                    showAddActionSheet = true
                                }

                                VisitedControlButton(icon: "globe.americas.fill") {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        showListView.toggle()
                                    }
                                    HapticManager.shared.buttonTap()
                                }
                            }
                            .padding(8)
                            .background(
                                Capsule()
                                    .fill(.ultraThinMaterial)
                                    .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
                            )
                            .overlay(
                                Capsule()
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.3),
                                                Color.teal.opacity(0.2),
                                                Color.white.opacity(0.1)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )

                            Spacer()
                        }
                        .padding(.leading, 16)
                        .padding(.bottom, 90)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showAddActionSheet) {
                AddOptionsSheet(
                    onAddCountry: { showAddCountrySheet = true },
                    onAddCity: { showAddCitySheet = true },
                    onImportPhotos: { showPhotoImport = true }
                )
                .presentationDetents([.height(340)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)
            }
            .sheet(isPresented: $showAddCountrySheet) {
                AddCountrySheet()
            }
            .sheet(isPresented: $showAddCitySheet) {
                AddCitySheet()
            }
            .sheet(isPresented: $showPhotoImport) {
                PhotoImportView()
            }
        }
    }
}

// MARK: - Visited Control Button

struct VisitedControlButton: View {
    let icon: String
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            HapticManager.shared.buttonTap()
            action()
        }) {
            ZStack {
                // Background
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 44, height: 44)

                // Gradient overlay when pressed
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.teal, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ).opacity(isPressed ? 0.3 : 0)
                    )
                    .frame(width: 44, height: 44)

                // Border
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.4),
                                Color.teal.opacity(0.3),
                                Color.white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .frame(width: 44, height: 44)

                // Icon
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.teal, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .shadow(color: Color.teal.opacity(isPressed ? 0.4 : 0.2), radius: isPressed ? 4 : 8)
            .scaleEffect(isPressed ? 0.92 : 1.0)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Add City Sheet

struct AddCitySheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var searchCompleter = CitySearchCompleter()
    @ObservedObject var cityTracker = CityTracker.shared

    @State private var searchText = ""
    @State private var isAdding = false
    @State private var addedCityName: String?
    @State private var showAddedConfirmation = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search results list
                if searchCompleter.results.isEmpty && !searchText.isEmpty && !searchCompleter.isSearching {
                    // No results state
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary.opacity(0.5))

                        Text("No cities found")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Text("Try searching for a different city name")
                            .font(.subheadline)
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else if searchText.isEmpty {
                    // Initial state
                    VStack(spacing: 16) {
                        Image(systemName: "globe.americas.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(
                                LinearGradient(colors: [.teal, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )

                        Text("Search Cities Worldwide")
                            .font(.headline)

                        Text("Type a city name to search from millions of cities around the world")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    // Search results
                    List {
                        ForEach(searchCompleter.results, id: \.self) { result in
                            Button {
                                addCity(from: result)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(result.title)
                                            .font(.headline)
                                            .foregroundColor(.primary)

                                        if !result.subtitle.isEmpty {
                                            Text(result.subtitle)
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
                                    }

                                    Spacer()

                                    Image(systemName: "plus.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(
                                            LinearGradient(colors: [.teal, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                                        )
                                }
                                .padding(.vertical, 4)
                            }
                            .disabled(isAdding)
                        }
                    }
                    .listStyle(.plain)
                }

                // Loading indicator
                if searchCompleter.isSearching {
                    ProgressView()
                        .padding()
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search cities worldwide...")
            .onChange(of: searchText) { _, newValue in
                searchCompleter.search(query: newValue)
            }
            .navigationTitle("Add City")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("City Added", isPresented: $showAddedConfirmation) {
                Button("Add Another") { }
                Button("Done") { dismiss() }
            } message: {
                if let name = addedCityName {
                    Text("\(name) has been added to your visited cities.")
                }
            }
            .overlay {
                if isAdding {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView("Adding city...")
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                }
            }
        }
    }

    private func addCity(from completion: MKLocalSearchCompletion) {
        isAdding = true

        Task {
            if let cityResult = await searchCompleter.getLocationDetails(for: completion) {
                await MainActor.run {
                    cityTracker.addManualCity(
                        name: cityResult.name,
                        state: cityResult.state,
                        country: cityResult.country,
                        countryCode: cityResult.countryCode,
                        latitude: cityResult.latitude,
                        longitude: cityResult.longitude
                    )

                    addedCityName = cityResult.shortDisplayName
                    isAdding = false
                    showAddedConfirmation = true
                    searchText = ""
                    searchCompleter.clearResults()

                    HapticManager.shared.success()
                }
            } else {
                await MainActor.run {
                    isAdding = false
                    HapticManager.shared.error()
                }
            }
        }
    }
}

// MARK: - Add Options Sheet

struct AddOptionsSheet: View {
    @Environment(\.dismiss) private var dismiss

    let onAddCountry: () -> Void
    let onAddCity: () -> Void
    let onImportPhotos: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Text("Add to Visited")
                    .font(.title3)
                    .fontWeight(.bold)

                Text("Choose how to add new places")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)
            .padding(.bottom, 24)

            // Options
            VStack(spacing: 12) {
                // Add Country Option
                AddOptionButton(
                    icon: "globe.americas.fill",
                    title: "Add Country",
                    subtitle: "Mark a country as visited",
                    gradientColors: [.teal, .cyan]
                ) {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onAddCountry()
                    }
                }

                // Add City Option
                AddOptionButton(
                    icon: "building.2.fill",
                    title: "Add City",
                    subtitle: "Search cities worldwide",
                    gradientColors: [.purple, .indigo]
                ) {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onAddCity()
                    }
                }

                // Import from Photos Option
                AddOptionButton(
                    icon: "photo.stack.fill",
                    title: "Import from Photos",
                    subtitle: "Discover places from your photo library",
                    gradientColors: [.orange, .pink]
                ) {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onImportPhotos()
                    }
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .background(Color(UIColor.systemBackground))
    }
}

// MARK: - Add Option Button

struct AddOptionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let gradientColors: [Color]
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            HapticManager.shared.medium()
            action()
        }) {
            HStack(spacing: 16) {
                // Icon with gradient background
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: gradientColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)

                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                }

                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Arrow
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(UIColor.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [
                                gradientColors[0].opacity(isPressed ? 0.5 : 0.2),
                                gradientColors[1].opacity(isPressed ? 0.3 : 0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.15)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Preview

#Preview {
    VisitedView()
}
