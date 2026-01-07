//
//  MapPreviewView.swift
//  Next-track
//
//  MapKit mini-map and full-screen map view
//

import SwiftUI
import MapKit
import CoreLocation

struct MapPreviewView: View {
    let location: CLLocation?
    let recentLocations: [CLLocation]

    @State private var position: MapCameraPosition = .automatic

    var body: some View {
        Map(position: $position) {
            // Current location marker
            if let loc = location {
                Annotation("Current", coordinate: loc.coordinate) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.3))
                            .frame(width: 40, height: 40)
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 14, height: 14)
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                            .frame(width: 14, height: 14)
                    }
                }

                // Accuracy circle
                MapCircle(center: loc.coordinate, radius: loc.horizontalAccuracy)
                    .foregroundStyle(Color.blue.opacity(0.1))
                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
            }

            // Track path
            if recentLocations.count > 1 {
                let coordinates = recentLocations.map { $0.coordinate }
                MapPolyline(coordinates: coordinates)
                    .stroke(Color.blue, lineWidth: 3)
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .mapControls {
            MapCompass()
        }
        .onChange(of: location) { _, newLocation in
            if let loc = newLocation {
                withAnimation {
                    position = .camera(MapCamera(
                        centerCoordinate: loc.coordinate,
                        distance: 1000,
                        heading: 0,
                        pitch: 0
                    ))
                }
            }
        }
        .onAppear {
            if let loc = location {
                position = .camera(MapCamera(
                    centerCoordinate: loc.coordinate,
                    distance: 1000,
                    heading: 0,
                    pitch: 0
                ))
            }
        }
    }
}

// MARK: - Full Map View

struct FullMapView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var locationManager: LocationManager

    @State private var position: MapCameraPosition = .automatic
    @State private var mapStyle: MapStyleOption = .standard

    enum MapStyleOption: String, CaseIterable {
        case standard = "Standard"
        case satellite = "Satellite"
        case hybrid = "Hybrid"
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Map(position: $position) {
                    // Current location
                    if let loc = locationManager.currentLocation {
                        Annotation("Current Location", coordinate: loc.coordinate) {
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.3))
                                    .frame(width: 50, height: 50)
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 20, height: 20)
                                Circle()
                                    .stroke(Color.white, lineWidth: 3)
                                    .frame(width: 20, height: 20)
                            }
                        }

                        // Accuracy circle
                        MapCircle(center: loc.coordinate, radius: loc.horizontalAccuracy)
                            .foregroundStyle(Color.blue.opacity(0.1))
                            .stroke(Color.blue.opacity(0.4), lineWidth: 2)
                    }

                    // Track path
                    if locationManager.recentLocations.count > 1 {
                        let coordinates = locationManager.recentLocations.map { $0.coordinate }
                        MapPolyline(coordinates: coordinates)
                            .stroke(Color.blue, lineWidth: 4)

                        // Start point marker
                        if let first = locationManager.recentLocations.first {
                            Annotation("Start", coordinate: first.coordinate) {
                                Image(systemName: "flag.fill")
                                    .foregroundColor(.green)
                                    .font(.title2)
                            }
                        }
                    }
                }
                .mapStyle(currentMapStyle)
                .mapControls {
                    MapCompass()
                    MapScaleView()
                    MapUserLocationButton()
                }

                // Map style picker
                Picker("Map Style", selection: $mapStyle) {
                    ForEach(MapStyleOption.allCases, id: \.self) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                .background(.ultraThinMaterial)
            }
            .navigationTitle("Track Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        centerOnCurrentLocation()
                    } label: {
                        Image(systemName: "location.fill")
                    }
                }
            }
            .onAppear {
                centerOnCurrentLocation()
            }
        }
    }

    private var currentMapStyle: MapStyle {
        switch mapStyle {
        case .standard:
            return .standard(elevation: .realistic)
        case .satellite:
            return .imagery(elevation: .realistic)
        case .hybrid:
            return .hybrid(elevation: .realistic)
        }
    }

    private func centerOnCurrentLocation() {
        if let loc = locationManager.currentLocation {
            withAnimation {
                position = .camera(MapCamera(
                    centerCoordinate: loc.coordinate,
                    distance: 500,
                    heading: 0,
                    pitch: 0
                ))
            }
        }
    }
}

// MARK: - Preview

#Preview("Map Preview") {
    MapPreviewView(
        location: CLLocation(latitude: 37.7749, longitude: -122.4194),
        recentLocations: []
    )
    .frame(height: 200)
}

#Preview("Full Map") {
    FullMapView()
        .environmentObject(LocationManager.shared)
}
