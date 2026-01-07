//
//  GeofenceSettingsView.swift
//  Next-track
//
//  Manage geofence zones for auto start/stop tracking
//

import SwiftUI
import MapKit

struct GeofenceSettingsView: View {
    @EnvironmentObject var geofenceManager: GeofenceManager
    @EnvironmentObject var locationManager: LocationManager

    @State private var showAddZone = false
    @State private var selectedZone: GeofenceZone?

    var body: some View {
        List {
            // Info Section
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Auto Start/Stop Tracking", systemImage: "location.circle.fill")
                        .font(.headline)

                    Text("Create zones to automatically start or stop tracking when you enter or leave an area.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }

            // Quick Add Section
            Section {
                Button {
                    addHomeZone(action: .homeMode)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Add Home Zone", systemImage: "house.fill")
                            .font(.body)
                            .foregroundColor(.blue)
                        Text("Stop tracking at home, auto-start when you leave")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .disabled(locationManager.currentLocation == nil)

                Button {
                    showAddZone = true
                } label: {
                    Label("Add Custom Zone", systemImage: "plus.circle.fill")
                }
            } header: {
                Text("Quick Add at Current Location")
            } footer: {
                if locationManager.currentLocation == nil {
                    Text("Location not available. Make sure location services are enabled.")
                        .foregroundColor(.orange)
                }
            }

            // Zones List
            Section("Your Zones") {
                if geofenceManager.zones.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "mappin.slash")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No zones yet")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                } else {
                    ForEach(geofenceManager.zones) { zone in
                        ZoneRowView(zone: zone) {
                            selectedZone = zone
                        } onToggle: {
                            geofenceManager.toggleZone(zone)
                        } onDelete: {
                            geofenceManager.deleteZone(zone)
                        }
                    }
                }
            }

            // Monitoring Status
            Section("Status") {
                HStack {
                    Text("Monitoring Active")
                    Spacer()
                    Text(geofenceManager.isMonitoring ? "Yes" : "No")
                        .foregroundColor(geofenceManager.isMonitoring ? .green : .secondary)
                }

                if let currentZone = geofenceManager.currentZone {
                    HStack {
                        Text("Currently In")
                        Spacer()
                        Text(currentZone.name)
                            .foregroundColor(.blue)
                    }
                }

                Button(geofenceManager.isMonitoring ? "Stop Monitoring" : "Start Monitoring") {
                    if geofenceManager.isMonitoring {
                        geofenceManager.stopMonitoringAllZones()
                    } else {
                        geofenceManager.startMonitoringAllZones()
                    }
                }
            }
        }
        .navigationTitle("Geofencing")
        .sheet(isPresented: $showAddZone) {
            AddZoneView()
                .environmentObject(locationManager)
                .environmentObject(geofenceManager)
        }
        .sheet(item: $selectedZone) { zone in
            EditZoneView(zone: zone)
                .environmentObject(geofenceManager)
        }
    }

    private func addHomeZone(action: GeofenceZone.GeofenceAction) {
        guard let location = locationManager.currentLocation else { return }
        let zone = GeofenceZone.createHome(coordinate: location.coordinate, action: action)
        geofenceManager.addZone(zone)

        // Auto-start monitoring if not already
        if !geofenceManager.isMonitoring {
            geofenceManager.startMonitoringAllZones()
        }
    }
}

// MARK: - Zone Row View

struct ZoneRowView: View {
    let zone: GeofenceZone
    let onEdit: () -> Void
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(zone.name)
                    .font(.headline)

                Text(zone.action.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("\(Int(zone.radius))m radius")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { zone.isEnabled },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onEdit()
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Add Zone View

struct AddZoneView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var geofenceManager: GeofenceManager
    @EnvironmentObject var locationManager: LocationManager

    @State private var name = ""
    @State private var radius: Double = 100
    @State private var action: GeofenceZone.GeofenceAction = .homeMode
    @State private var useCurrentLocation = true
    @State private var customLatitude = ""
    @State private var customLongitude = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Zone Details") {
                    TextField("Zone Name", text: $name)
                }

                Section {
                    ForEach(GeofenceZone.GeofenceAction.allCases, id: \.self) { actionOption in
                        Button {
                            action = actionOption
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(actionLabel(actionOption))
                                        .foregroundColor(.primary)
                                    Text(actionOption.rawValue)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if action == actionOption {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                } header: {
                    Text("What should happen?")
                }

                Section("Location") {
                    Toggle("Use Current Location", isOn: $useCurrentLocation)

                    if !useCurrentLocation {
                        TextField("Latitude", text: $customLatitude)
                            .keyboardType(.decimalPad)
                        TextField("Longitude", text: $customLongitude)
                            .keyboardType(.decimalPad)
                    } else if let loc = locationManager.currentLocation {
                        HStack {
                            Text("Current")
                            Spacer()
                            Text("\(loc.coordinate.latitude, specifier: "%.4f"), \(loc.coordinate.longitude, specifier: "%.4f")")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                }

                Section("Radius") {
                    VStack {
                        HStack {
                            Text("Radius")
                            Spacer()
                            Text("\(Int(radius))m")
                                .foregroundColor(.secondary)
                        }

                        Slider(value: $radius, in: 50...500, step: 25)
                    }
                }
            }
            .navigationTitle("Add Zone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addZone()
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }

    private func addZone() {
        let latitude: Double
        let longitude: Double

        if useCurrentLocation, let loc = locationManager.currentLocation {
            latitude = loc.coordinate.latitude
            longitude = loc.coordinate.longitude
        } else if let lat = Double(customLatitude), let lon = Double(customLongitude) {
            latitude = lat
            longitude = lon
        } else {
            return
        }

        let zone = GeofenceZone(
            id: UUID(),
            name: name,
            latitude: latitude,
            longitude: longitude,
            radius: radius,
            action: action,
            isEnabled: true
        )
        geofenceManager.addZone(zone)

        // Auto-start monitoring
        if !geofenceManager.isMonitoring {
            geofenceManager.startMonitoringAllZones()
        }
    }

    private func actionLabel(_ action: GeofenceZone.GeofenceAction) -> String {
        switch action {
        case .homeMode:
            return "Home Mode (Recommended)"
        case .stopOnEnter:
            return "Stop tracking when I arrive"
        case .startOnEnter:
            return "Start tracking when I arrive"
        case .startOnExit:
            return "Start tracking when I leave"
        case .stopOnExit:
            return "Stop tracking when I leave"
        }
    }
}

// MARK: - Edit Zone View

struct EditZoneView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var geofenceManager: GeofenceManager

    let zone: GeofenceZone

    @State private var name: String = ""
    @State private var radius: Double = 100
    @State private var action: GeofenceZone.GeofenceAction = .stopOnEnter

    var body: some View {
        NavigationStack {
            Form {
                Section("Zone Details") {
                    TextField("Zone Name", text: $name)
                }

                Section {
                    ForEach(GeofenceZone.GeofenceAction.allCases, id: \.self) { actionOption in
                        Button {
                            action = actionOption
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(actionLabel(actionOption))
                                        .foregroundColor(.primary)
                                    Text(actionOption.rawValue)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if action == actionOption {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                } header: {
                    Text("What should happen?")
                }

                Section("Location") {
                    HStack {
                        Text("Coordinates")
                        Spacer()
                        Text("\(zone.latitude, specifier: "%.4f"), \(zone.longitude, specifier: "%.4f")")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }

                Section("Radius") {
                    VStack {
                        HStack {
                            Text("Radius")
                            Spacer()
                            Text("\(Int(radius))m")
                                .foregroundColor(.secondary)
                        }

                        Slider(value: $radius, in: 50...500, step: 25)
                    }
                }
            }
            .navigationTitle("Edit Zone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveZone()
                        dismiss()
                    }
                }
            }
            .onAppear {
                name = zone.name
                radius = zone.radius
                action = zone.action
            }
        }
    }

    private func saveZone() {
        var updatedZone = zone
        updatedZone.name = name
        updatedZone.radius = radius
        updatedZone.action = action
        geofenceManager.updateZone(updatedZone)
    }

    private func actionLabel(_ action: GeofenceZone.GeofenceAction) -> String {
        switch action {
        case .homeMode:
            return "Home Mode (Recommended)"
        case .stopOnEnter:
            return "Stop tracking at this location"
        case .startOnEnter:
            return "Start tracking at this location"
        case .startOnExit:
            return "Start tracking when I leave"
        case .stopOnExit:
            return "Stop tracking when I leave"
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        GeofenceSettingsView()
            .environmentObject(LocationManager.shared)
    }
}
