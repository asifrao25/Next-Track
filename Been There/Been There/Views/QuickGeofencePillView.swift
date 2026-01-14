//
//  QuickGeofencePillView.swift
//  Next-track
//
//  Quick geofence button that adds current location as a 30m geofenced zone
//

import SwiftUI
import UIKit

struct QuickGeofencePillView: View {
    @StateObject private var geofenceManager = GeofenceManager.shared
    @StateObject private var locationManager = LocationManager.shared

    @State private var showConfirmationPopup = false
    @State private var showSuccessPopup = false
    @State private var showNoLocationAlert = false

    var body: some View {
        Button {
            HapticManager.shared.buttonTap()

            guard locationManager.currentLocation != nil else {
                showNoLocationAlert = true
                return
            }

            // Show confirmation popup before action
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showConfirmationPopup = true
            }
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
        .alert("No Location", isPresented: $showNoLocationAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Unable to get your current location. Please ensure location services are enabled.")
        }
        .fullScreenCover(isPresented: $showConfirmationPopup) {
            GeofenceConfirmationPopup(
                isPresented: $showConfirmationPopup,
                onConfirm: {
                    addQuickGeofence()
                }
            )
            .background(ClearBackgroundView())
        }
        .fullScreenCover(isPresented: $showSuccessPopup) {
            GeofenceSuccessPopup(isPresented: $showSuccessPopup)
                .background(ClearBackgroundView())
        }
    }

    private func addQuickGeofence() {
        // Generate a name based on time
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        let zoneName = "Quick Zone - \(formatter.string(from: Date()))"

        // Add the geofence with 30m radius, stop tracking when inside (home mode behavior)
        geofenceManager.addCurrentLocationAsZone(
            name: zoneName,
            radius: 30,
            action: GeofenceZone.GeofenceAction.stopOnEnter
        )

        HapticManager.shared.success()

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showSuccessPopup = true
        }

        // Auto-dismiss success popup after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeOut(duration: 0.3)) {
                showSuccessPopup = false
            }
        }
    }
}

// MARK: - Clear Background for FullScreenCover

struct ClearBackgroundView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        DispatchQueue.main.async {
            view.superview?.superview?.backgroundColor = .clear
        }
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {}
}

// MARK: - Geofence Confirmation Popup

struct GeofenceConfirmationPopup: View {
    @Binding var isPresented: Bool
    let onConfirm: () -> Void

    @State private var appear = false

    var body: some View {
        ZStack {
            // Background dimming
            Color.black.opacity(appear ? 0.6 : 0)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissPopup()
                }

            // Popup card
            VStack(spacing: 20) {
                // Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.orange.opacity(0.2), .red.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 70, height: 70)

                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 35))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.orange, .red],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                // Title
                Text("Add Geofence Zone?")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                // Description
                Text("This will create a 30m geofence at your current location. Tracking will automatically pause when you're inside this zone.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)

                // Buttons
                HStack(spacing: 12) {
                    // Cancel button
                    Button {
                        HapticManager.shared.light()
                        dismissPopup()
                    } label: {
                        Text("Cancel")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(UIColor.secondarySystemBackground))
                            )
                    }
                    .buttonStyle(.plain)

                    // Confirm button
                    Button {
                        HapticManager.shared.medium()
                        withAnimation(.easeOut(duration: 0.2)) {
                            appear = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            isPresented = false
                            onConfirm()
                        }
                    } label: {
                        Text("Add Zone")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(
                                        LinearGradient(
                                            colors: [.orange, .red],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(UIColor.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        LinearGradient(
                            colors: [.orange.opacity(0.3), .red.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 40)
            .scaleEffect(appear ? 1 : 0.8)
            .opacity(appear ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                appear = true
            }
        }
    }

    private func dismissPopup() {
        withAnimation(.easeOut(duration: 0.2)) {
            appear = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            isPresented = false
        }
    }
}

// MARK: - Geofence Success Popup

struct GeofenceSuccessPopup: View {
    @Binding var isPresented: Bool

    @State private var appear = false
    @State private var checkmarkScale: CGFloat = 0

    var body: some View {
        ZStack {
            // Background dimming
            Color.black.opacity(appear ? 0.6 : 0)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissPopup()
                }

            // Success card
            VStack(spacing: 16) {
                // Animated checkmark
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.green.opacity(0.2), .teal.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 45))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.green, .teal],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(checkmarkScale)
                }

                Text("Geofence Added!")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Text("Tracking will pause when you're in this zone")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(UIColor.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        LinearGradient(
                            colors: [.green.opacity(0.3), .teal.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 50)
            .scaleEffect(appear ? 1 : 0.8)
            .opacity(appear ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                appear = true
            }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5).delay(0.15)) {
                checkmarkScale = 1
            }
        }
    }

    private func dismissPopup() {
        withAnimation(.easeOut(duration: 0.2)) {
            appear = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            isPresented = false
        }
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3).ignoresSafeArea()
        QuickGeofencePillView()
    }
}

#Preview("Confirmation Popup") {
    GeofenceConfirmationPopup(isPresented: .constant(true), onConfirm: {})
}

#Preview("Success Popup") {
    GeofenceSuccessPopup(isPresented: .constant(true))
}
