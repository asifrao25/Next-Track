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
    let sessionLocations: [StoredLocation]  // Current session track
    let historicalSessions: [TrackingSession]  // Past sessions
    @Binding var position: MapCameraPosition  // Map camera position

    @State private var mapId = UUID()  // Force map refresh

    // Filter to only sessions that have actual location data
    private var sessionsWithLocations: [TrackingSession] {
        historicalSessions.filter { !$0.locations.isEmpty }
    }

    // Get the best locations to display on map
    private var displayLocations: [StoredLocation] {
        // Prefer current session, fall back to most recent historical session with locations
        if !sessionLocations.isEmpty {
            return sessionLocations
        } else if let mostRecent = sessionsWithLocations.first {
            return mostRecent.locations
        }
        return []
    }

    var body: some View {
        Map(position: $position) {
            // Historical session paths (orange, behind current)
            ForEach(sessionsWithLocations.prefix(5)) { session in
                if session.locations.count > 1 {
                    MapPolyline(coordinates: session.locations.map { $0.coordinate })
                        .stroke(Color.orange.opacity(0.6), lineWidth: 3)
                }

                // Show start marker for each historical session
                if let first = session.locations.first {
                    Annotation("", coordinate: first.coordinate) {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 8, height: 8)
                    }
                }
            }

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

            // Current session track path (blue, on top)
            if sessionLocations.count > 1 {
                let coordinates = sessionLocations.map { $0.coordinate }
                MapPolyline(coordinates: coordinates)
                    .stroke(Color.blue, lineWidth: 4)
            }

            // Start point marker for current or most recent session
            if let first = displayLocations.first {
                Annotation("Start", coordinate: first.coordinate) {
                    Image(systemName: "flag.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                }
            }

            // End point marker if session has ended
            if sessionLocations.isEmpty, let lastSession = sessionsWithLocations.first,
               let last = lastSession.locations.last {
                Annotation("End", coordinate: last.coordinate) {
                    Image(systemName: "flag.checkered")
                        .foregroundColor(.red)
                        .font(.title3)
                }
            }
        }
        .id(mapId)  // Force refresh when ID changes
        .mapStyle(.standard(elevation: .realistic))
        .mapControls {
            MapCompass()
        }
        .onChange(of: historicalSessions.count) { _, _ in
            // Force map refresh when sessions change
            mapId = UUID()
        }
        .onAppear {
            // Debug logging
            print("[MapPreview] Total sessions: \(historicalSessions.count)")
            print("[MapPreview] Sessions with locations: \(sessionsWithLocations.count)")
            for (i, session) in sessionsWithLocations.prefix(3).enumerated() {
                print("[MapPreview] Session \(i): \(session.locations.count) locations, points=\(session.pointsCount)")
                if let first = session.locations.first {
                    print("[MapPreview]   First loc: \(first.latitude), \(first.longitude)")
                }
            }

            // Center on current location, or most recent track location
            if let loc = location {
                position = .camera(MapCamera(
                    centerCoordinate: loc.coordinate,
                    distance: 1000,
                    heading: 0,
                    pitch: 0
                ))
            } else if let lastLoc = displayLocations.last {
                print("[MapPreview] Centering on last location: \(lastLoc.latitude), \(lastLoc.longitude)")
                position = .camera(MapCamera(
                    centerCoordinate: lastLoc.coordinate,
                    distance: 1000,
                    heading: 0,
                    pitch: 0
                ))
            } else {
                print("[MapPreview] No locations to center on")
            }
        }
    }
}

// MARK: - Full Map View

struct FullMapView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var locationManager: LocationManager
    @StateObject private var historyManager = TrackingHistoryManager.shared

    @State private var position: MapCameraPosition = .automatic
    @State private var mapStyle: MapStyleOption = .standard
    @State private var showAllHistory = true  // Show historical paths by default

    enum MapStyleOption: String, CaseIterable {
        case standard = "Standard"
        case satellite = "Satellite"
        case hybrid = "Hybrid"
    }

    // Get all locations from current session
    private var sessionLocations: [StoredLocation] {
        historyManager.currentSession?.locations ?? []
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Map(position: $position) {
                    // Historical session paths (gray, behind current)
                    if showAllHistory {
                        ForEach(historyManager.sessions) { session in
                            if session.locations.count > 1 {
                                MapPolyline(coordinates: session.locations.map { $0.coordinate })
                                    .stroke(Color.gray.opacity(0.5), lineWidth: 2)
                            }
                        }
                    }

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

                    // Current session track path (blue, on top)
                    if sessionLocations.count > 1 {
                        let coordinates = sessionLocations.map { $0.coordinate }
                        MapPolyline(coordinates: coordinates)
                            .stroke(Color.blue, lineWidth: 4)

                        // Start point marker
                        if let first = sessionLocations.first {
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
                    HStack(spacing: 16) {
                        // History toggle button
                        Button {
                            withAnimation {
                                showAllHistory.toggle()
                            }
                        } label: {
                            Image(systemName: showAllHistory ? "clock.fill" : "clock")
                                .foregroundColor(showAllHistory ? .blue : .primary)
                        }

                        // Center on location button
                        Button {
                            centerOnCurrentLocation()
                        } label: {
                            Image(systemName: "location.fill")
                        }
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
        sessionLocations: [],
        historicalSessions: [],
        position: .constant(.automatic)
    )
    .frame(height: 200)
}

#Preview("Full Map") {
    FullMapView()
        .environmentObject(LocationManager.shared)
}
