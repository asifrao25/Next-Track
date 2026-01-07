//
//  CustomTitleHeaderView.swift
//  Next-track
//
//  Custom app title header with animated status indicator and latency display
//

import SwiftUI

// MARK: - Pulsing Status Indicator

struct PulsingStatusIndicator: View {
    enum Status {
        case active      // Green pulsing - tracking active and connected
        case paused      // Static gray - tracking paused
        case warning     // Orange pulsing - issues detected
    }

    let status: Status
    let size: CGFloat

    @State private var isPulsing = false

    init(status: Status, size: CGFloat = 10) {
        self.status = status
        self.size = size
    }

    var body: some View {
        Circle()
            .fill(statusColor)
            .frame(width: size, height: size)
            .scaleEffect(shouldPulse ? (isPulsing ? 1.5 : 1.0) : 1.0)
            .opacity(shouldPulse ? (isPulsing ? 0.4 : 1.0) : 1.0)
            .animation(
                shouldPulse
                    ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                    : .default,
                value: isPulsing
            )
            .onAppear {
                if shouldPulse {
                    isPulsing = true
                }
            }
            .onChange(of: status) { _, newStatus in
                isPulsing = newStatus != .paused
            }
    }

    private var statusColor: Color {
        switch status {
        case .active:
            return .green
        case .paused:
            return .gray
        case .warning:
            return .orange
        }
    }

    private var shouldPulse: Bool {
        status != .paused
    }
}

// MARK: - Custom Title Header View

struct CustomTitleHeaderView: View {
    @ObservedObject var connectionMonitor: ConnectionMonitor
    @ObservedObject var batteryMonitor: BatteryMonitor
    let isTracking: Bool
    let hasIssues: Bool
    let pendingCount: Int
    let currentZoneName: String?  // Zone name when inside a geofence

    var body: some View {
        VStack(spacing: 12) {
            // Main title card
            VStack(spacing: 8) {
                // App title - centered
                HStack(spacing: 10) {
                    // Animated status indicator
                    PulsingStatusIndicator(status: indicatorStatus, size: 12)

                    Text("Next Track")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }

                // Status row
                HStack(spacing: 16) {
                    // Tracking status - dynamic based on zone
                    HStack(spacing: 4) {
                        Image(systemName: trackingStatusIcon)
                            .font(.system(size: 11))
                        Text(trackingStatusText)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(trackingStatusColor)

                    // Divider
                    Text("|")
                        .foregroundColor(.secondary.opacity(0.5))
                        .font(.system(size: 12))

                    // Ping/Latency
                    HStack(spacing: 4) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 11))
                        if let latency = connectionMonitor.averageLatency {
                            Text("\(Int(latency))ms")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                        } else {
                            Text("--ms")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                        }
                    }
                    .foregroundColor(latencyColor)

                    // Divider
                    Text("|")
                        .foregroundColor(.secondary.opacity(0.5))
                        .font(.system(size: 12))

                    // Battery
                    HStack(spacing: 4) {
                        Image(systemName: batteryIcon)
                            .font(.system(size: 11))
                        Text("\(batteryMonitor.batteryLevel)%")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(batteryColor)
                }

                // Pending locations indicator (if any)
                if pendingCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "tray.full.fill")
                            .font(.system(size: 10))
                        Text("\(pendingCount) pending")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.orange)
                    .padding(.top, 2)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray6))
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            )
        }
    }

    // MARK: - Computed Properties

    private var indicatorStatus: PulsingStatusIndicator.Status {
        if hasIssues {
            return .warning
        }
        if isTracking {
            return .active
        }
        return .paused
    }

    // Dynamic tracking status based on zone
    private var trackingStatusIcon: String {
        if isTracking {
            return "location.fill"
        } else if currentZoneName != nil {
            return "house.fill"
        }
        return "location.slash"
    }

    private var trackingStatusText: String {
        if isTracking {
            return "Active"
        } else if let zoneName = currentZoneName {
            return "At \(zoneName)"
        }
        return "Paused"
    }

    private var trackingStatusColor: Color {
        if isTracking {
            return .green
        } else if currentZoneName != nil {
            return .blue
        }
        return .secondary
    }

    private var latencyColor: Color {
        guard let latency = connectionMonitor.averageLatency else {
            return .secondary
        }
        switch latency {
        case 0..<100:
            return .green
        case 100..<300:
            return .yellow
        default:
            return .orange
        }
    }

    private var batteryIcon: String {
        if batteryMonitor.isCharging {
            return "battery.100.bolt"
        }
        switch batteryMonitor.batteryLevel {
        case 0...10: return "battery.0"
        case 11...25: return "battery.25"
        case 26...50: return "battery.50"
        case 51...75: return "battery.75"
        default: return "battery.100"
        }
    }

    private var batteryColor: Color {
        if batteryMonitor.isCharging { return .green }
        switch batteryMonitor.batteryLevel {
        case 0...10: return .red
        case 11...20: return .orange
        default: return .secondary
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        // Active tracking
        CustomTitleHeaderView(
            connectionMonitor: ConnectionMonitor.shared,
            batteryMonitor: BatteryMonitor.shared,
            isTracking: true,
            hasIssues: false,
            pendingCount: 0,
            currentZoneName: nil
        )

        // Paused at Home zone
        CustomTitleHeaderView(
            connectionMonitor: ConnectionMonitor.shared,
            batteryMonitor: BatteryMonitor.shared,
            isTracking: false,
            hasIssues: false,
            pendingCount: 0,
            currentZoneName: "Home"
        )

        // Paused with pending
        CustomTitleHeaderView(
            connectionMonitor: ConnectionMonitor.shared,
            batteryMonitor: BatteryMonitor.shared,
            isTracking: false,
            hasIssues: false,
            pendingCount: 3,
            currentZoneName: nil
        )

        // Active with issues
        CustomTitleHeaderView(
            connectionMonitor: ConnectionMonitor.shared,
            batteryMonitor: BatteryMonitor.shared,
            isTracking: true,
            hasIssues: true,
            pendingCount: 0,
            currentZoneName: nil
        )
    }
    .padding()
    .background(Color.black)
}
