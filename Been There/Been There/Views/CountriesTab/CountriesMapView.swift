//
//  CountriesMapView.swift
//  Next-track
//
//  3D rotatable globe showing visited countries with premium visual effects
//

import SwiftUI
import MapKit

// MARK: - Animated Progress Ring

struct AnimatedProgressRing: View {
    let progress: Double
    let lineWidth: CGFloat
    let gradient: LinearGradient

    @State private var animatedProgress: Double = 0

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: lineWidth)

            // Progress ring with gradient
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))

            // Center percentage text
            Text("\(Int(progress * 100))%")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(.red)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.2)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.easeOut(duration: 0.5)) {
                animatedProgress = newValue
            }
        }
    }
}

// MARK: - Premium Flag Marker

struct PremiumFlagMarker: View {
    let country: VisitedCountry
    let onTap: () -> Void

    @State private var showGlow = true
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            HapticManager.shared.selectionChanged()
            onTap()
        }) {
            ZStack {
                // Outer glow (pulsing)
                Circle()
                    .fill(RadialGradient(
                        colors: [
                            Color.red.opacity(showGlow ? 0.5 : 0.15),
                            Color.orange.opacity(showGlow ? 0.3 : 0.05),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 14,
                        endRadius: 32
                    ))
                    .frame(width: 60, height: 60)

                // Flag container
                ZStack {
                    // Glassmorphic background
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 42, height: 42)

                    // Gradient border
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.6),
                                    Color.red.opacity(0.4),
                                    Color.orange.opacity(0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 42, height: 42)

                    // Flag emoji
                    Text(country.flagEmoji)
                        .font(.system(size: 24))
                }
                .shadow(color: Color.red.opacity(0.4), radius: 8, x: 0, y: 4)
                .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
            }
            .scaleEffect(isPressed ? 0.9 : 1.0)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.15)) {
                isPressed = pressing
            }
        }, perform: {})
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                showGlow.toggle()
            }
        }
    }
}

// MARK: - Premium Control Button

struct PremiumControlButton: View {
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
                    .frame(width: 48, height: 48)

                // Gradient overlay when pressed
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.red, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ).opacity(isPressed ? 0.3 : 0)
                    )
                    .frame(width: 48, height: 48)

                // Border
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.4),
                                Color.red.opacity(0.3),
                                Color.white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .frame(width: 48, height: 48)

                // Icon
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.red, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .shadow(color: Color.red.opacity(isPressed ? 0.4 : 0.2), radius: isPressed ? 4 : 8)
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

// MARK: - Countries Map View

struct CountriesMapView: View {
    let visitedCountries: [VisitedCountry]
    let geoJSON: CountryGeoJSON?
    let onCountryTapped: (VisitedCountry) -> Void

    @State private var cameraPosition: MapCameraPosition = .camera(
        MapCamera(
            centerCoordinate: CLLocationCoordinate2D(latitude: 20, longitude: 0),
            distance: 45_000_000,
            heading: 0,
            pitch: 0
        )
    )

    @State private var selectedCountry: VisitedCountry?
    @State private var currentDistance: Double = 45_000_000

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
                            if isVisited {
                                // VISITED COUNTRY: Highlighted with teal fill and bright border
                                MapPolygon(coordinates: coordinates)
                                    .foregroundStyle(
                                        Color.red.opacity(0.5)
                                    )
                                    .stroke(
                                        Color.orange,
                                        lineWidth: 2.5
                                    )
                            } else {
                                // UNVISITED COUNTRY: Very subtle styling
                                MapPolygon(coordinates: coordinates)
                                    .foregroundStyle(Color.gray.opacity(0.05))
                                    .stroke(Color.gray.opacity(0.15), lineWidth: 0.3)
                            }
                        }
                    }
                } else {
                    // FALLBACK: No GeoJSON available - use circular highlight zones
                    ForEach(visitedCountries) { country in
                        if let center = CountriesManager.shared.getCountryCenter(isoCode: country.isoCode) {
                            // Outer glow circle
                            MapCircle(center: center, radius: 400000) // 400km radius
                                .foregroundStyle(Color.red.opacity(0.15))
                                .stroke(Color.orange.opacity(0.3), lineWidth: 2)

                            // Inner highlight circle
                            MapCircle(center: center, radius: 200000) // 200km radius
                                .foregroundStyle(Color.red.opacity(0.25))
                                .stroke(Color.orange.opacity(0.5), lineWidth: 3)
                        }
                    }
                }

                // Invisible tap targets at country centers (no visible markers)
                ForEach(visitedCountries) { country in
                    if let center = CountriesManager.shared.getCountryCenter(isoCode: country.isoCode) {
                        Annotation("", coordinate: center) {
                            // Invisible tap area - large enough to tap easily
                            Color.clear
                                .frame(width: 60, height: 60)
                                .contentShape(Circle())
                                .onTapGesture {
                                    HapticManager.shared.selectionChanged()
                                    selectedCountry = country
                                }
                        }
                    }
                }
            }
            .mapStyle(.imagery(elevation: .realistic))

            // Premium globe controls overlay
            VStack {
                Spacer()

                HStack {
                    Spacer()

                    VStack(spacing: 12) {
                        // Reset to globe view
                        PremiumControlButton(icon: "globe") {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                cameraPosition = .camera(
                                    MapCamera(
                                        centerCoordinate: CLLocationCoordinate2D(latitude: 20, longitude: 0),
                                        distance: 45_000_000,
                                        heading: 0,
                                        pitch: 0
                                    )
                                )
                                currentDistance = 45_000_000
                            }
                        }

                        // Zoom in
                        PremiumControlButton(icon: "plus") {
                            zoomIn()
                        }

                        // Zoom out
                        PremiumControlButton(icon: "minus") {
                            zoomOut()
                        }
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 28)
                            .fill(.ultraThinMaterial)
                            .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.3),
                                        Color.red.opacity(0.2),
                                        Color.white.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .padding(.trailing, 16)
                    .padding(.bottom, 100)
                }
            }

            // Premium stats overlay
            VStack {
                HStack {
                    premiumStatsCard
                    Spacer()
                }
                .padding()
                Spacer()
            }
        }
        // Show country detail sheet
        .sheet(item: $selectedCountry) { country in
            NavigationStack {
                CountryDetailView(country: country)
            }
            .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Compact Pie Chart Stats

    private var premiumStatsCard: some View {
        ZStack {
            // Background pie (gray for unvisited)
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 8)

            // Foreground pie (red for visited)
            Circle()
                .trim(from: 0, to: Double(visitedCountries.count) / 195.0)
                .stroke(
                    LinearGradient(
                        colors: [.red, .orange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Center content
            VStack(spacing: 2) {
                Text("\(visitedCountries.count)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.red, .orange],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                Text("/195")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 64, height: 64)
        .padding(10)
        .background(
            Circle()
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
        )
    }

    // MARK: - Helper Functions

    private func zoomIn() {
        let newDistance = max(currentDistance * 0.5, 500_000)
        currentDistance = newDistance
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            cameraPosition = .camera(
                MapCamera(
                    centerCoordinate: getCameraCenter(),
                    distance: newDistance,
                    heading: 0,
                    pitch: 0
                )
            )
        }
    }

    private func zoomOut() {
        let newDistance = min(currentDistance * 2.0, 60_000_000)
        currentDistance = newDistance
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            cameraPosition = .camera(
                MapCamera(
                    centerCoordinate: getCameraCenter(),
                    distance: newDistance,
                    heading: 0,
                    pitch: 0
                )
            )
        }
    }

    private func getCameraCenter() -> CLLocationCoordinate2D {
        // Just return default center - MapKit manages the actual position
        return CLLocationCoordinate2D(latitude: 20, longitude: 0)
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
                    Annotation("", coordinate: center) {
                        PremiumFlagMarker(country: country) {
                            // Handle tap
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
