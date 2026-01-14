//
//  QuickGeofencePillView.swift
//  Next-track
//
//  Quick geofence button that adds current location as a 30m geofenced zone
//

import SwiftUI

struct QuickGeofencePillView: View {
    @StateObject private var geofenceManager = GeofenceManager.shared
    @StateObject private var locationManager = LocationManager.shared

    @State private var showConfirmation = false
    @State private var showNoLocationAlert = false

    var body: some View {
        Button {
            addQuickGeofence()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 12, weight: .semibold))

                Text("Geofence")
                    .font(.system(size: 12, weight: .semibold))

                Text("Add")
                    .font(.system(size: 12, weight: .bold))

                Image(systemName: "plus")
                    .font(.system(size: 9, weight: .bold))
                    .opacity(0.8)
            }
            .foregroundColor(.white)
            .frame(width: 145, height: 36)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.orange, Color.red.opacity(0.85)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .alert("Geofence Added", isPresented: $showConfirmation) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("A 30m geofence zone has been added at your current location. Tracking will pause when you're inside this zone.")
        }
        .alert("No Location", isPresented: $showNoLocationAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Unable to get your current location. Please ensure location services are enabled.")
        }
    }

    private func addQuickGeofence() {
        HapticManager.shared.buttonTap()

        guard locationManager.currentLocation != nil else {
            showNoLocationAlert = true
            return
        }

        // Generate a name based on time
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        let zoneName = "Quick Zone - \(formatter.string(from: Date()))"

        // Add the geofence with 30m radius, stop tracking when inside (home mode behavior)
        geofenceManager.addCurrentLocationAsZone(
            name: zoneName,
            radius: 30,
            action: .stopOnEnter
        )

        HapticManager.shared.success()
        showConfirmation = true
    }
}

#Preview {
    QuickGeofencePillView()
}
