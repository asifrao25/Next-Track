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

    // Get track appearance settings
    private var trackAppearance: TrackAppearanceSettings {
        TrackingSettings.load().trackAppearance
    }

    // Get today's color as SwiftUI Color
    private var todayTrackColor: Color {
        let c = trackAppearance.todayColor.color
        return Color(red: c.red, green: c.green, blue: c.blue)
    }

    // Today's completed sessions (from historical)
    private var todaysCompletedSessions: [TrackingSession] {
        let calendar = Calendar.current
        return historicalSessions.filter { calendar.isDateInToday($0.startTime) }
    }

    // All today's locations for centering
    private var allTodaysLocations: [StoredLocation] {
        var locations = sessionLocations
        for session in todaysCompletedSessions {
            locations.append(contentsOf: session.locations)
        }
        return locations
    }

    var body: some View {
        Map(position: $position) {
            // Today's completed sessions (not the active one)
            ForEach(todaysCompletedSessions) { session in
                if session.locations.count > 1 {
                    MapPolyline(coordinates: session.locations.map { $0.coordinate })
                        .stroke(todayTrackColor.opacity(0.7), lineWidth: CGFloat(trackAppearance.todayWidth.rawValue))
                }
            }

            // Current session track path (active tracking)
            if sessionLocations.count > 1 {
                let coordinates = sessionLocations.map { $0.coordinate }
                MapPolyline(coordinates: coordinates)
                    .stroke(todayTrackColor, lineWidth: CGFloat(trackAppearance.todayWidth.rawValue))
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

            // Start point marker for current session
            if let first = sessionLocations.first {
                Annotation("Start", coordinate: first.coordinate) {
                    Image(systemName: "flag.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                }
            }
        }
        .id(mapId)  // Force refresh when ID changes
        .mapStyle(.standard(elevation: .realistic))
        .mapControls {
            MapCompass()
        }
        .onAppear {
            // Center on current location, or most recent track location
            if let loc = location {
                position = .camera(MapCamera(
                    centerCoordinate: loc.coordinate,
                    distance: 1000,
                    heading: 0,
                    pitch: 0
                ))
            } else if let lastLoc = allTodaysLocations.last {
                position = .camera(MapCamera(
                    centerCoordinate: lastLoc.coordinate,
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
    @StateObject private var historyManager = TrackingHistoryManager.shared

    @State private var position: MapCameraPosition = .automatic
    @State private var mapStyle: MapStyleOption = .standard
    @State private var showAllHistory = true  // Show historical paths by default

    enum MapStyleOption: String, CaseIterable {
        case standard = "Standard"
        case satellite = "Satellite"
        case hybrid = "Hybrid"
    }

    // Get track appearance settings
    private var trackAppearance: TrackAppearanceSettings {
        TrackingSettings.load().trackAppearance
    }

    // Helper to convert TrackColorOption to SwiftUI Color
    private func colorFor(_ option: TrackColorOption, opacity: Double = 1.0) -> Color {
        let c = option.color
        return Color(red: c.red, green: c.green, blue: c.blue).opacity(opacity)
    }

    // Get all locations from current session
    private var sessionLocations: [StoredLocation] {
        historyManager.currentSession?.locations ?? []
    }

    // Sessions from today (completed, not the active one)
    private var todaysSessions: [TrackingSession] {
        let calendar = Calendar.current
        return historyManager.sessions.filter { calendar.isDateInToday($0.startTime) }
    }

    // Sessions from last week (excluding today)
    private var lastWeekSessions: [TrackingSession] {
        let calendar = Calendar.current
        let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return historyManager.sessions.filter { session in
            !calendar.isDateInToday(session.startTime) && session.startTime >= oneWeekAgo
        }
    }

    // Sessions older than a week
    private var olderSessions: [TrackingSession] {
        let calendar = Calendar.current
        let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return historyManager.sessions.filter { session in
            session.startTime < oneWeekAgo
        }
    }

    // Control button size for consistency
    private let controlButtonSize: CGFloat = 44

    var body: some View {
        ZStack(alignment: .bottom) {
            // Full screen map
            Map(position: $position) {
                // Older session paths (oldest, at the bottom)
                if showAllHistory {
                    ForEach(olderSessions) { session in
                        if session.locations.count > 1 {
                            MapPolyline(coordinates: session.locations.map { $0.coordinate })
                                .stroke(
                                    colorFor(trackAppearance.olderColor, opacity: 0.5),
                                    lineWidth: CGFloat(trackAppearance.olderWidth.rawValue)
                                )
                        }
                    }

                    // Last week session paths
                    ForEach(lastWeekSessions) { session in
                        if session.locations.count > 1 {
                            MapPolyline(coordinates: session.locations.map { $0.coordinate })
                                .stroke(
                                    colorFor(trackAppearance.lastWeekColor, opacity: 0.7),
                                    lineWidth: CGFloat(trackAppearance.lastWeekWidth.rawValue)
                                )
                        }
                    }
                }

                // Today's completed sessions
                ForEach(todaysSessions) { session in
                    if session.locations.count > 1 {
                        MapPolyline(coordinates: session.locations.map { $0.coordinate })
                            .stroke(
                                colorFor(trackAppearance.todayColor),
                                lineWidth: CGFloat(trackAppearance.todayWidth.rawValue)
                            )
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

                // Current session track path (today's track, on top)
                if sessionLocations.count > 1 {
                    let coordinates = sessionLocations.map { $0.coordinate }
                    MapPolyline(coordinates: coordinates)
                        .stroke(
                            colorFor(trackAppearance.todayColor),
                            lineWidth: CGFloat(trackAppearance.todayWidth.rawValue)
                        )

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
            }
            .ignoresSafeArea()

            // Bottom control bar
            VStack(spacing: 12) {
                // Map style picker
                Picker("Map Style", selection: $mapStyle) {
                    ForEach(MapStyleOption.allCases, id: \.self) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                .pickerStyle(.segmented)

                // Control buttons row
                HStack {
                    // Close button (left)
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(width: controlButtonSize, height: controlButtonSize)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                            )
                    }

                    Spacer()

                    // History toggle (right side)
                    Button {
                        withAnimation {
                            showAllHistory.toggle()
                        }
                        HapticManager.shared.buttonTap()
                    } label: {
                        Image(systemName: showAllHistory ? "clock.fill" : "clock")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(showAllHistory ? .blue : .primary)
                            .frame(width: controlButtonSize, height: controlButtonSize)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                            )
                            .overlay(
                                Circle()
                                    .stroke(showAllHistory ? Color.blue.opacity(0.5) : Color.primary.opacity(0.2), lineWidth: 1)
                            )
                    }

                    // My location button (right side)
                    Button {
                        centerOnCurrentLocation()
                        HapticManager.shared.buttonTap()
                    } label: {
                        Image(systemName: "location.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.blue)
                            .frame(width: controlButtonSize, height: controlButtonSize)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: -2)
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .onAppear {
            centerOnCurrentLocation()
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
