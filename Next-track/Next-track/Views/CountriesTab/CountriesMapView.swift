//
//  CountriesMapView.swift
//  Next-track
//
//  3D rotatable globe showing visited countries
//

import SwiftUI
import MapKit

struct CountriesMapView: View {
    let visitedCountries: [VisitedCountry]
    let geoJSON: CountryGeoJSON?
    let onCountryTapped: (VisitedCountry) -> Void

    @State private var cameraPosition: MapCameraPosition = .camera(
        MapCamera(
            centerCoordinate: CLLocationCoordinate2D(latitude: 20, longitude: 0),
            distance: 45_000_000,  // Globe view distance - shows full Earth
            heading: 0,
            pitch: 0
        )
    )

    @State private var selectedCountry: VisitedCountry?
    @State private var showCountryDetail: Bool = false

    private var visitedIsoCodes: Set<String> {
        Set(visitedCountries.map { $0.isoCode.uppercased() })
    }

    var body: some View {
        ZStack {
            Map(position: $cameraPosition, interactionModes: .all) {
                // Render country polygons if GeoJSON is available
                if let features = geoJSON?.features {
                    ForEach(features) { feature in
                        let isVisited = visitedIsoCodes.contains(feature.properties.isoA2?.uppercased() ?? "")

                        ForEach(Array(GeoJSONParser.parsePolygons(from: feature.geometry).enumerated()), id: \.offset) { _, coordinates in
                            MapPolygon(coordinates: coordinates)
                                .foregroundStyle(
                                    isVisited
                                        ? Color.teal.opacity(0.6)
                                        : Color.gray.opacity(0.15)
                                )
                                .stroke(
                                    isVisited ? Color.teal : Color.gray.opacity(0.3),
                                    lineWidth: isVisited ? 1.5 : 0.5
                                )
                        }
                    }
                }

                // Add flag markers for visited countries
                ForEach(visitedCountries) { country in
                    if let center = CountriesManager.shared.getCountryCenter(isoCode: country.isoCode) {
                        Annotation(country.name, coordinate: center) {
                            Button {
                                selectedCountry = country
                                showCountryDetail = true
                                HapticManager.shared.selectionChanged()
                            } label: {
                                VStack(spacing: 2) {
                                    Text(country.flagEmoji)
                                        .font(.title2)
                                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                                }
                            }
                        }
                    }
                }
            }
            .mapStyle(.imagery(elevation: .realistic))

            // Globe controls overlay
            VStack {
                Spacer()

                HStack {
                    Spacer()

                    VStack(spacing: 12) {
                        // Reset to globe view
                        Button {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                cameraPosition = .camera(
                                    MapCamera(
                                        centerCoordinate: CLLocationCoordinate2D(latitude: 20, longitude: 0),
                                        distance: 45_000_000,
                                        heading: 0,
                                        pitch: 0
                                    )
                                )
                            }
                            HapticManager.shared.buttonTap()
                        } label: {
                            Image(systemName: "globe")
                                .font(.title2)
                                .foregroundColor(.teal)
                                .frame(width: 44, height: 44)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 100)
                }
            }

            // Stats overlay
            VStack {
                HStack {
                    statsCard
                    Spacer()
                }
                .padding()
                Spacer()
            }
        }
        .sheet(isPresented: $showCountryDetail) {
            if let country = selectedCountry {
                NavigationStack {
                    CountryDetailView(country: country)
                }
                .presentationDetents([.medium, .large])
            }
        }
    }

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text("\(visitedCountries.count)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.teal)
                Text("/ 195")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Text("countries visited")
                .font(.caption)
                .foregroundColor(.secondary)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.teal)
                        .frame(width: geo.size.width * CGFloat(min(visitedCountries.count, 195)) / 195, height: 4)
                }
            }
            .frame(height: 4)
            .frame(width: 100)
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .shadow(radius: 4)
    }
}

// MARK: - Fallback Map View (when no GeoJSON)

struct CountriesMapFallbackView: View {
    let visitedCountries: [VisitedCountry]

    @State private var cameraPosition: MapCameraPosition = .camera(
        MapCamera(
            centerCoordinate: CLLocationCoordinate2D(latitude: 20, longitude: 0),
            distance: 40_000_000,
            heading: 0,
            pitch: 0
        )
    )

    var body: some View {
        Map(position: $cameraPosition, interactionModes: [.rotate, .zoom, .pan]) {
            ForEach(visitedCountries) { country in
                if let center = CountriesManager.shared.getCountryCenter(isoCode: country.isoCode) {
                    // Country marker
                    Annotation(country.name, coordinate: center) {
                        VStack(spacing: 2) {
                            Text(country.flagEmoji)
                                .font(.largeTitle)
                                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)

                            Text(country.name)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.ultraThinMaterial)
                                .cornerRadius(4)
                        }
                    }
                }
            }
        }
        .mapStyle(.imagery(elevation: .realistic))
    }
}

// MARK: - Preview

#Preview {
    CountriesMapView(
        visitedCountries: [
            VisitedCountry(name: "United States", isoCode: "US", continent: "North America", isAutoDetected: true, firstVisitDate: Date()),
            VisitedCountry(name: "France", isoCode: "FR", continent: "Europe", isManuallyAdded: true, firstVisitDate: Date())
        ],
        geoJSON: nil,
        onCountryTapped: { _ in }
    )
}
