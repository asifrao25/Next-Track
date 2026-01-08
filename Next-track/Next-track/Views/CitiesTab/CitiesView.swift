//
//  CitiesView.swift
//  Next-track
//
//  View for displaying visited cities
//

import SwiftUI
import MapKit

struct CitiesView: View {
    @ObservedObject var cityTracker = CityTracker.shared

    @State private var selectedSort: CitySortOption = .recentVisit
    @State private var showMapView: Bool = false
    @State private var searchText: String = ""

    var filteredCities: [VisitedCity] {
        var cities = selectedSort.sort(cityTracker.visitedCities)
        if !searchText.isEmpty {
            cities = cities.filter { city in
                city.name.localizedCaseInsensitiveContains(searchText) ||
                (city.state?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                city.country.localizedCaseInsensitiveContains(searchText)
            }
        }
        return cities
    }

    var body: some View {
        NavigationStack {
            Group {
                if cityTracker.visitedCities.isEmpty {
                    EmptyStateView()
                } else if showMapView {
                    CitiesMapView(cities: filteredCities)
                } else {
                    CitiesListView(
                        cities: filteredCities,
                        selectedSort: $selectedSort
                    )
                }
            }
            .navigationTitle("Cities")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 4) {
                        Text("\(cityTracker.totalCities)")
                            .font(.headline)
                            .foregroundColor(.purple)
                        Text("cities")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        if cityTracker.countriesVisited > 1 {
                            Text("in")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("\(cityTracker.countriesVisited)")
                                .font(.headline)
                                .foregroundColor(.purple)
                            Text("countries")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            showMapView.toggle()
                        }
                    } label: {
                        Image(systemName: showMapView ? "list.bullet" : "map")
                            .foregroundColor(.purple)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search cities")
        }
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "building.2")
                .font(.system(size: 60))
                .foregroundColor(.purple.opacity(0.5))

            Text("No Cities Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Start tracking to discover the cities you visit")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
}

// MARK: - Cities List View

struct CitiesListView: View {
    let cities: [VisitedCity]
    @Binding var selectedSort: CitySortOption

    var body: some View {
        List {
            // Sort picker section
            Section {
                Picker("Sort by", selection: $selectedSort) {
                    ForEach(CitySortOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.menu)
            }

            // Cities list
            Section {
                ForEach(cities) { city in
                    CityRowView(city: city)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - City Row

struct CityRowView: View {
    let city: VisitedCity

    var body: some View {
        HStack(spacing: 12) {
            // Flag emoji
            Text(city.flagEmoji)
                .font(.system(size: 32))
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(Color.purple.opacity(0.1))
                )

            // City info
            VStack(alignment: .leading, spacing: 4) {
                Text(city.name)
                    .font(.headline)

                HStack(spacing: 4) {
                    if let state = city.state {
                        Text(state)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("•")
                            .foregroundColor(.secondary)
                    }
                    Text(city.country)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 8) {
                    Label("\(city.visitCount)", systemImage: "arrow.counterclockwise")
                        .font(.caption)
                        .foregroundColor(.purple)

                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(city.formattedLastVisit)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // First discovered date
            VStack(alignment: .trailing, spacing: 2) {
                Text("First visit")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(city.formattedFirstVisit)
                    .font(.caption)
                    .foregroundColor(.purple)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Cities Map View

struct CitiesMapView: View {
    let cities: [VisitedCity]

    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        Map(position: $cameraPosition) {
            ForEach(cities) { city in
                Annotation(city.name, coordinate: city.coordinate) {
                    VStack(spacing: 2) {
                        Text(city.flagEmoji)
                            .font(.title2)
                        Text(city.name)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(.ultraThinMaterial)
                            )
                    }
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .onAppear {
            if !cities.isEmpty {
                // Fit all cities in view
                let coordinates = cities.map { $0.coordinate }
                let minLat = coordinates.map { $0.latitude }.min() ?? 0
                let maxLat = coordinates.map { $0.latitude }.max() ?? 0
                let minLon = coordinates.map { $0.longitude }.min() ?? 0
                let maxLon = coordinates.map { $0.longitude }.max() ?? 0

                let center = CLLocationCoordinate2D(
                    latitude: (minLat + maxLat) / 2,
                    longitude: (minLon + maxLon) / 2
                )
                let span = MKCoordinateSpan(
                    latitudeDelta: max((maxLat - minLat) * 1.5, 0.1),
                    longitudeDelta: max((maxLon - minLon) * 1.5, 0.1)
                )

                cameraPosition = .region(MKCoordinateRegion(center: center, span: span))
            }
        }
    }
}

// MARK: - Preview

#Preview {
    CitiesView()
}
