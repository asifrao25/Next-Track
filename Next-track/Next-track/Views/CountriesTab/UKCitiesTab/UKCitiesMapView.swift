//
//  UKCitiesMapView.swift
//  Next-track
//
//  Flat UK map with highlighted visited cities using LAD boundaries
//

import SwiftUI
import MapKit

struct UKCitiesMapView: View {
    @ObservedObject var citiesManager = UKCitiesManager.shared
    let visitedCities: [VisitedUKCity]
    let onCityTapped: (VisitedUKCity) -> Void

    @State private var cameraPosition: MapCameraPosition = .camera(
        MapCamera(
            centerCoordinate: UKCityData.ukCenter,
            distance: 1_200_000,  // Show most of UK
            heading: 0,
            pitch: 0
        )
    )

    @State private var currentDistance: Double = 1_200_000

    // Long-press to add area state
    @State private var showAddAreaSheet = false
    @State private var longPressCoordinate: CLLocationCoordinate2D?
    @State private var detectedLADFeature: UKLADFeature?
    @State private var isLongPressing = false
    @State private var longPressProgress: CGFloat = 0

    // Visited city names for quick lookup
    private var visitedCityNames: Set<String> {
        Set(visitedCities.map { $0.name })
    }

    // Check if a LAD matches any visited city
    private func isLADVisited(_ ladName: String) -> Bool {
        // Check direct matches first
        if visitedCityNames.contains(ladName) {
            return true
        }
        // Check mapped names
        for city in visitedCities {
            let mappedName = citiesManager.getLADName(for: city.name)
            if mappedName == ladName || ladName.contains(city.name) || city.name.contains(ladName) {
                return true
            }
        }
        return false
    }

    // Get the visited city for a LAD
    private func getVisitedCityForLAD(_ ladName: String) -> VisitedUKCity? {
        // Try direct match
        if let city = visitedCities.first(where: { $0.name == ladName }) {
            return city
        }
        // Try mapped match
        for city in visitedCities {
            let mappedName = citiesManager.getLADName(for: city.name)
            if mappedName == ladName || ladName.contains(city.name) || city.name.contains(ladName) {
                return city
            }
        }
        return nil
    }

    // Cities that have LAD boundaries
    private var citiesWithBoundaries: Set<String> {
        guard let features = citiesManager.ladGeoJSON?.features else { return [] }
        var matched = Set<String>()
        for city in visitedCities {
            let mappedName = citiesManager.getLADName(for: city.name)
            if features.contains(where: { $0.properties.name == mappedName || $0.properties.name.contains(city.name) || city.name.contains($0.properties.name) }) {
                matched.insert(city.name)
            }
        }
        return matched
    }

    // Cities without LAD boundaries (need circle fallback)
    private var citiesWithoutBoundaries: [VisitedUKCity] {
        let withBoundaries = citiesWithBoundaries
        return visitedCities.filter { !withBoundaries.contains($0.name) }
    }

    var body: some View {
        ZStack {
            MapReader { proxy in
                Map(position: $cameraPosition, interactionModes: .all) {
                // Render LAD boundary polygons for visited cities
                if let features = citiesManager.ladGeoJSON?.features {
                    ForEach(features) { feature in
                        if isLADVisited(feature.properties.name) {
                            // Render polygon boundaries for this LAD with smoothed coordinates
                            ForEach(Array(GeoJSONParser.parsePolygons(from: feature.geometry).enumerated()), id: \.offset) { _, coordinates in
                                // Simplify polygon for smoother appearance
                                let smoothedCoords = simplifyPolygon(coordinates, tolerance: 0.001)

                                // Soft outer glow layer
                                MapPolygon(coordinates: smoothedCoords)
                                    .foregroundStyle(Color.teal.opacity(0.15))

                                // Main fill layer
                                MapPolygon(coordinates: smoothedCoords)
                                    .foregroundStyle(Color.teal.opacity(0.35))
                                    .stroke(Color.teal.opacity(0.6), lineWidth: 1.0)
                            }
                        }
                    }
                }

                // Fallback: Circle highlights for cities without LAD boundaries
                ForEach(citiesWithoutBoundaries) { city in
                    // Outer glow - soft edge
                    MapCircle(center: city.coordinate, radius: city.radius * 1.3)
                        .foregroundStyle(Color.teal.opacity(0.15))
                        .stroke(Color.teal.opacity(0.3), lineWidth: 1.5)

                    // Main highlight area - solid fill
                    MapCircle(center: city.coordinate, radius: city.radius)
                        .foregroundStyle(Color.teal.opacity(0.4))
                        .stroke(Color.teal, lineWidth: 2.5)
                }

                // Invisible tap targets at city centers for all visited cities
                ForEach(visitedCities) { city in
                    Annotation("", coordinate: city.coordinate) {
                        Color.clear
                            .frame(width: 60, height: 60)
                            .contentShape(Circle())
                            .onTapGesture {
                                HapticManager.shared.selectionChanged()
                                onCityTapped(city)
                            }
                    }
                }
                }
                .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
                .gesture(
                    LongPressGesture(minimumDuration: 2.0)
                        .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
                        .onEnded { value in
                            switch value {
                            case .second(true, let drag):
                                // Haptic feedback on activation
                                HapticManager.shared.success()

                                if let location = drag?.location,
                                   let coordinate = proxy.convert(location, from: .local) {
                                    handleLongPress(at: coordinate)
                                }
                            default:
                                break
                            }
                        }
                )
            }

            // Controls overlay
            VStack {
                Spacer()

                HStack {
                    Spacer()

                    VStack(spacing: 12) {
                        // Reset to UK view
                        MapControlButton(icon: "scope") {
                            resetToUK()
                        }

                        // Zoom in
                        MapControlButton(icon: "plus") {
                            zoomIn()
                        }

                        // Zoom out
                        MapControlButton(icon: "minus") {
                            zoomOut()
                        }
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(.ultraThinMaterial)
                            .shadow(color: Color.black.opacity(0.1), radius: 8)
                    )
                    .padding(.trailing, 16)
                    .padding(.bottom, 100)
                }
            }

            // Stats overlay
            VStack {
                HStack {
                    cityStatsCard
                    Spacer()
                }
                .padding()
                Spacer()

                // Long-press hint
                HStack {
                    Spacer()
                    Text("Long press to add area")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                        )
                    Spacer()
                }
                .padding(.bottom, 8)
            }
        }
        .sheet(isPresented: $showAddAreaSheet) {
            LongPressAddAreaSheet(
                coordinate: longPressCoordinate,
                detectedLAD: detectedLADFeature,
                citiesManager: citiesManager
            )
            .presentationDetents([.medium])
        }
    }

    // MARK: - Polygon Simplification (Douglas-Peucker Algorithm)

    /// Simplify a polygon by reducing the number of points while preserving shape
    /// Uses the Douglas-Peucker algorithm for smooth, clean boundaries
    private func simplifyPolygon(_ coordinates: [CLLocationCoordinate2D], tolerance: Double) -> [CLLocationCoordinate2D] {
        guard coordinates.count > 2 else { return coordinates }

        // Find the point with maximum distance from the line between first and last
        var maxDistance: Double = 0
        var maxIndex = 0

        let first = coordinates[0]
        let last = coordinates[coordinates.count - 1]

        for i in 1..<(coordinates.count - 1) {
            let distance = perpendicularDistance(point: coordinates[i], lineStart: first, lineEnd: last)
            if distance > maxDistance {
                maxDistance = distance
                maxIndex = i
            }
        }

        // If max distance is greater than tolerance, recursively simplify
        if maxDistance > tolerance {
            let leftPart = simplifyPolygon(Array(coordinates[0...maxIndex]), tolerance: tolerance)
            let rightPart = simplifyPolygon(Array(coordinates[maxIndex..<coordinates.count]), tolerance: tolerance)

            // Combine results (avoiding duplicate point at maxIndex)
            return Array(leftPart.dropLast()) + rightPart
        } else {
            // All points between first and last can be removed
            return [first, last]
        }
    }

    /// Calculate perpendicular distance from a point to a line
    private func perpendicularDistance(point: CLLocationCoordinate2D, lineStart: CLLocationCoordinate2D, lineEnd: CLLocationCoordinate2D) -> Double {
        let dx = lineEnd.longitude - lineStart.longitude
        let dy = lineEnd.latitude - lineStart.latitude

        // Line length squared
        let lineLengthSquared = dx * dx + dy * dy

        if lineLengthSquared == 0 {
            // Line is a point
            let pdx = point.longitude - lineStart.longitude
            let pdy = point.latitude - lineStart.latitude
            return sqrt(pdx * pdx + pdy * pdy)
        }

        // Calculate projection
        let t = max(0, min(1, ((point.longitude - lineStart.longitude) * dx + (point.latitude - lineStart.latitude) * dy) / lineLengthSquared))

        let projX = lineStart.longitude + t * dx
        let projY = lineStart.latitude + t * dy

        let distX = point.longitude - projX
        let distY = point.latitude - projY

        return sqrt(distX * distX + distY * distY)
    }

    // MARK: - Long Press Handler

    private func handleLongPress(at coordinate: CLLocationCoordinate2D) {
        // Store the coordinate
        longPressCoordinate = coordinate

        // Try to detect which LAD this coordinate is in
        detectedLADFeature = citiesManager.findLADAtCoordinate(coordinate)

        // Show the sheet
        showAddAreaSheet = true
    }

    // MARK: - Stats Card

    private var cityStatsCard: some View {
        HStack(spacing: 8) {
            Image(systemName: "building.2.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.teal, .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("\(visitedCities.count)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.teal, .cyan],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            Text("cities")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.1), radius: 8)
        )
    }

    // MARK: - Actions

    private func resetToUK() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            cameraPosition = .camera(
                MapCamera(
                    centerCoordinate: UKCityData.ukCenter,
                    distance: 1_200_000,
                    heading: 0,
                    pitch: 0
                )
            )
            currentDistance = 1_200_000
        }
        HapticManager.shared.buttonTap()
    }

    private func zoomIn() {
        let newDistance = max(currentDistance * 0.5, 50_000)
        currentDistance = newDistance
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            cameraPosition = .camera(
                MapCamera(
                    centerCoordinate: UKCityData.ukCenter,
                    distance: newDistance,
                    heading: 0,
                    pitch: 0
                )
            )
        }
        HapticManager.shared.buttonTap()
    }

    private func zoomOut() {
        let newDistance = min(currentDistance * 2.0, 3_000_000)
        currentDistance = newDistance
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            cameraPosition = .camera(
                MapCamera(
                    centerCoordinate: UKCityData.ukCenter,
                    distance: newDistance,
                    heading: 0,
                    pitch: 0
                )
            )
        }
        HapticManager.shared.buttonTap()
    }
}

// MARK: - Map Control Button

struct MapControlButton: View {
    let icon: String
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 44, height: 44)

                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.teal.opacity(0.5), .cyan.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.teal, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
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

// MARK: - Long Press Add Area Sheet

struct LongPressAddAreaSheet: View {
    let coordinate: CLLocationCoordinate2D?
    let detectedLAD: UKLADFeature?
    @ObservedObject var citiesManager: UKCitiesManager
    @Environment(\.dismiss) var dismiss

    @State private var customName: String = ""
    @State private var useDetectedLAD: Bool = true
    @State private var alreadyVisited: Bool = false

    private var ladName: String? {
        detectedLAD?.properties.name
    }

    private var regionName: String {
        guard let region = detectedLAD?.properties.region else {
            return "United Kingdom"
        }
        switch region.uppercased() {
        case "ENG": return "England"
        case "WAL": return "Wales"
        case "SCO": return "Scotland"
        case "NI": return "Northern Ireland"
        default: return "United Kingdom"
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Location icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.teal.opacity(0.2), .cyan.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)

                    Image(systemName: detectedLAD != nil ? "mappin.circle.fill" : "plus.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.teal, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .padding(.top)

                // Detected LAD info
                if let name = ladName {
                    VStack(spacing: 8) {
                        Text("Detected Area")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(name)
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text(regionName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        if alreadyVisited {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Already visited")
                                    .foregroundColor(.green)
                            }
                            .font(.subheadline)
                            .padding(.top, 4)
                        }
                    }
                } else {
                    VStack(spacing: 8) {
                        Text("No LAD boundary detected")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text("Enter a custom name for this location")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Custom name input (shown if no LAD or user wants custom)
                if detectedLAD == nil || !useDetectedLAD {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Area Name")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        TextField("Enter area name", text: $customName)
                            .textFieldStyle(.roundedBorder)
                    }
                    .padding(.horizontal)
                }

                // Option to use custom name even if LAD detected
                if detectedLAD != nil && !alreadyVisited {
                    Toggle("Use detected area name", isOn: $useDetectedLAD)
                        .tint(.teal)
                        .padding(.horizontal)
                }

                // Coordinates display
                if let coord = coordinate {
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundColor(.secondary)
                        Text(String(format: "%.4f, %.4f", coord.latitude, coord.longitude))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Add button
                if !alreadyVisited {
                    Button {
                        addArea()
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Mark as Visited")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [.teal, .cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                    }
                    .disabled(detectedLAD == nil && customName.isEmpty)
                    .opacity((detectedLAD == nil && customName.isEmpty) ? 0.5 : 1)
                    .padding(.horizontal)
                }
            }
            .padding(.bottom)
            .navigationTitle("Add Visited Area")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                checkIfAlreadyVisited()
                // Default to showing custom name input if no LAD detected
                if detectedLAD == nil {
                    useDetectedLAD = false
                }
            }
        }
    }

    private func checkIfAlreadyVisited() {
        if let name = ladName {
            alreadyVisited = citiesManager.isCityVisited(name) ||
                             citiesManager.getCity(named: name) != nil
        }
    }

    private func addArea() {
        guard let coord = coordinate else { return }

        // Determine what to pass based on user choice and what's available
        let ladToUse: UKLADFeature?
        let nameToUse: String?

        if let lad = detectedLAD, useDetectedLAD {
            // User wants to use the detected LAD
            ladToUse = lad
            nameToUse = nil
        } else if !customName.isEmpty {
            // Use custom name (either no LAD detected, or user toggled off)
            ladToUse = nil
            nameToUse = customName
        } else if let lad = detectedLAD {
            // Fallback: use detected LAD even if toggle is off but no custom name
            ladToUse = lad
            nameToUse = nil
        } else {
            // Nothing to add
            return
        }

        citiesManager.addManualAreaFromMap(
            coordinate: coord,
            ladFeature: ladToUse,
            customName: nameToUse
        )

        dismiss()
    }
}

// MARK: - Preview

#Preview {
    UKCitiesMapView(
        visitedCities: [
            VisitedUKCity(
                name: "Nottingham",
                region: "East Midlands",
                latitude: 52.9548,
                longitude: -1.1581,
                radius: 8000,
                visitCount: 47,
                firstVisitDate: Date(),
                lastVisitDate: Date(),
                places: ["QMC", "Castle Blvd"]
            ),
            VisitedUKCity(
                name: "London",
                region: "Greater London",
                latitude: 51.5074,
                longitude: -0.1278,
                radius: 25000,
                visitCount: 1,
                firstVisitDate: Date(),
                lastVisitDate: Date(),
                places: ["Stansted Airport"]
            )
        ],
        onCityTapped: { _ in }
    )
}
