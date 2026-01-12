//
//  iCloudSyncPopupView.swift
//  Next-track
//
//  Custom popup for iCloud sync status and setup instructions
//

import SwiftUI

struct iCloudSyncPopupView: View {
    @ObservedObject var syncManager = iCloudSyncManager.shared
    @Binding var isPresented: Bool

    @State private var showingInstructions = false

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.3)) {
                        isPresented = false
                    }
                }

            // Popup card
            VStack(spacing: 0) {
                // Header with icon
                ZStack {
                    // Gradient background
                    LinearGradient(
                        colors: [
                            Color.cyan.opacity(0.3),
                            Color.blue.opacity(0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    VStack(spacing: 12) {
                        // iCloud icon with status
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.3))
                                .frame(width: 80, height: 80)

                            Image(systemName: syncManager.iCloudAvailable ? "icloud.fill" : "icloud.slash.fill")
                                .font(.system(size: 36))
                                .foregroundColor(syncManager.iCloudAvailable ? .cyan : .orange)
                                .shadow(color: syncManager.iCloudAvailable ? .cyan.opacity(0.5) : .orange.opacity(0.5), radius: 10)
                        }

                        Text(syncManager.iCloudAvailable ? "iCloud Sync Active" : "iCloud Not Available")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.vertical, 24)
                }
                .frame(height: 160)

                // Content
                VStack(spacing: 16) {
                    if syncManager.iCloudAvailable {
                        // iCloud is available - show sync status
                        availableContent
                    } else {
                        // iCloud not available - show setup instructions
                        unavailableContent
                    }
                }
                .padding(20)
                .background(Color(white: 0.1))

                // Action buttons
                HStack(spacing: 12) {
                    if !syncManager.iCloudAvailable {
                        Button(action: openSettings) {
                            HStack {
                                Image(systemName: "gear")
                                Text("Open Settings")
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [.cyan, .blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                        }
                    } else {
                        Button(action: syncNow) {
                            HStack {
                                if syncManager.isSyncing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                }
                                Text(syncManager.isSyncing ? "Syncing..." : "Sync Now")
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [.cyan, .blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                        }
                        .disabled(syncManager.isSyncing)
                    }

                    Button(action: { isPresented = false }) {
                        Text("Dismiss")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                    }
                }
                .padding(20)
                .background(Color(white: 0.1))
            }
            .frame(width: 320)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        LinearGradient(
                            colors: [.cyan.opacity(0.5), .blue.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .cyan.opacity(0.3), radius: 20, x: 0, y: 10)
        }
    }

    // MARK: - Available Content

    private var availableContent: some View {
        VStack(spacing: 16) {
            // Sync status
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Connected to iCloud")
                    .foregroundColor(.white.opacity(0.9))
                Spacer()
            }
            .font(.system(size: 14))

            // Last sync time
            if let lastSync = syncManager.lastSyncDate {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.cyan.opacity(0.7))
                    Text("Last sync: \(lastSync.formatted(date: .abbreviated, time: .shortened))")
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                }
                .font(.system(size: 13))
            }

            // Sync progress
            if syncManager.isSyncing {
                VStack(spacing: 8) {
                    ProgressView(value: syncManager.syncProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .cyan))
                    Text("Syncing your data...")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }
            }

            // Info text
            Text("Your data is automatically synced across all your devices signed into the same Apple ID.")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Unavailable Content

    private var unavailableContent: some View {
        VStack(spacing: 16) {
            // Error message
            if let error = syncManager.syncError {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .foregroundColor(.white.opacity(0.9))
                        .font(.system(size: 14))
                    Spacer()
                }
            }

            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 1)

            // Instructions
            VStack(alignment: .leading, spacing: 12) {
                Text("To enable iCloud sync:")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                instructionRow(number: 1, text: "Open iPhone Settings")
                instructionRow(number: 2, text: "Tap your name at the top")
                instructionRow(number: 3, text: "Tap \"iCloud\"")
                instructionRow(number: 4, text: "Sign in or enable iCloud Drive")
            }

            // Benefits
            VStack(spacing: 8) {
                benefitRow(icon: "arrow.triangle.2.circlepath", text: "Sync across all devices")
                benefitRow(icon: "lock.shield", text: "Secure Apple encryption")
                benefitRow(icon: "bolt.fill", text: "Automatic background sync")
            }
            .padding(.top, 8)
        }
    }

    private func instructionRow(number: Int, text: String) -> some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.black)
                .frame(width: 22, height: 22)
                .background(
                    Circle()
                        .fill(Color.cyan)
                )

            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.8))

            Spacer()
        }
    }

    private func benefitRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.cyan)
                .frame(width: 20)

            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.6))

            Spacer()
        }
    }

    // MARK: - Actions

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func syncNow() {
        Task {
            await syncManager.syncAllData()
        }
        HapticManager.shared.success()
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        iCloudSyncPopupView(isPresented: .constant(true))
    }
}
