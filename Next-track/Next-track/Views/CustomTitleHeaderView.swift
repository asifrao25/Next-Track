//
//  CustomTitleHeaderView.swift
//  Next-track
//
//  Custom app title header with animated status indicator and latency display
//

import SwiftUI

// MARK: - Techy Status Indicator (Radar-style with radiating rings)

struct PulsingStatusIndicator: View {
    enum Status {
        case active      // Green radiating - tracking active and connected
        case paused      // Static gray - tracking paused
        case warning     // Orange radiating - issues detected
    }

    let status: Status
    let size: CGFloat

    @State private var ring1Scale: CGFloat = 0.5
    @State private var ring2Scale: CGFloat = 0.5
    @State private var ring3Scale: CGFloat = 0.5
    @State private var ring1Opacity: Double = 0.8
    @State private var ring2Opacity: Double = 0.8
    @State private var ring3Opacity: Double = 0.8
    @State private var isAnimating = false

    init(status: Status, size: CGFloat = 10) {
        self.status = status
        self.size = size
    }

    var body: some View {
        ZStack {
            // Outer radiating rings (only when active/warning)
            if shouldAnimate {
                // Ring 3 (outermost)
                Circle()
                    .stroke(statusColor.opacity(ring3Opacity), lineWidth: 1)
                    .frame(width: size * ring3Scale, height: size * ring3Scale)

                // Ring 2
                Circle()
                    .stroke(statusColor.opacity(ring2Opacity), lineWidth: 1.5)
                    .frame(width: size * ring2Scale, height: size * ring2Scale)

                // Ring 1 (innermost ring)
                Circle()
                    .stroke(statusColor.opacity(ring1Opacity), lineWidth: 1.5)
                    .frame(width: size * ring1Scale, height: size * ring1Scale)
            }

            // Center tech element - hexagonal/target style
            ZStack {
                // Outer hexagon frame
                RegularPolygon(sides: 6)
                    .stroke(statusColor.opacity(0.6), lineWidth: 1.5)
                    .frame(width: size * 0.9, height: size * 0.9)

                // Inner filled circle
                Circle()
                    .fill(statusColor)
                    .frame(width: size * 0.45, height: size * 0.45)

                // Tiny center dot for tech effect
                Circle()
                    .fill(Color.white.opacity(0.8))
                    .frame(width: size * 0.15, height: size * 0.15)
            }
        }
        .frame(width: size * 2.5, height: size * 2.5) // Fixed frame to prevent jumping
        .onAppear {
            if shouldAnimate {
                startRadiatingAnimation()
            }
        }
        .onChange(of: status) { _, _ in
            if shouldAnimate {
                startRadiatingAnimation()
            } else {
                stopAnimation()
            }
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

    private var shouldAnimate: Bool {
        status != .paused
    }

    private func startRadiatingAnimation() {
        guard !isAnimating else { return }
        isAnimating = true

        // Reset to initial state
        ring1Scale = 0.5
        ring2Scale = 0.5
        ring3Scale = 0.5
        ring1Opacity = 0.8
        ring2Opacity = 0.8
        ring3Opacity = 0.8

        // Staggered radiating animation for each ring
        withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
            ring1Scale = 2.2
            ring1Opacity = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
                ring2Scale = 2.2
                ring2Opacity = 0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
                ring3Scale = 2.2
                ring3Opacity = 0
            }
        }
    }

    private func stopAnimation() {
        isAnimating = false
        withAnimation(.easeOut(duration: 0.3)) {
            ring1Scale = 0.5
            ring2Scale = 0.5
            ring3Scale = 0.5
            ring1Opacity = 0
            ring2Opacity = 0
            ring3Opacity = 0
        }
    }
}

// MARK: - Regular Polygon Shape

struct RegularPolygon: Shape {
    let sides: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let angleStep = Double.pi * 2 / Double(sides)
        let startAngle = -Double.pi / 2 // Start from top

        for i in 0..<sides {
            let angle = startAngle + angleStep * Double(i)
            let point = CGPoint(
                x: center.x + CGFloat(cos(angle)) * radius,
                y: center.y + CGFloat(sin(angle)) * radius
            )
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - Custom Title Header View

enum ConnectionStatusType {
    case connected
    case disconnected
    case error
    case unknown
}

struct CustomTitleHeaderView: View {
    @ObservedObject var connectionMonitor: ConnectionMonitor
    @ObservedObject var batteryMonitor: BatteryMonitor
    let isTracking: Bool
    let hasIssues: Bool
    let pendingCount: Int
    let currentZoneName: String?  // Zone name when inside a geofence
    var connectionStatus: ConnectionStatusType = .unknown
    var lastSuccessfulSend: Date? = nil

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
                HStack(spacing: 8) {
                    // Tracking status - dynamic based on zone
                    HStack(spacing: 3) {
                        Image(systemName: trackingStatusIcon)
                            .font(.system(size: 10))
                        Text(trackingStatusText)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(trackingStatusColor)

                    // Divider
                    Text("|")
                        .foregroundColor(.secondary.opacity(0.5))
                        .font(.system(size: 10))

                    // Connection + Latency combined
                    HStack(spacing: 3) {
                        Image(systemName: connectionIcon)
                            .font(.system(size: 10))
                        if let latency = connectionMonitor.averageLatency {
                            Text("\(Int(latency))ms")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                        } else {
                            Text("--")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                        }
                    }
                    .foregroundColor(connectionColor)

                    // Divider
                    Text("|")
                        .foregroundColor(.secondary.opacity(0.5))
                        .font(.system(size: 10))

                    // Battery
                    HStack(spacing: 3) {
                        Image(systemName: batteryIcon)
                            .font(.system(size: 10))
                        Text("\(batteryMonitor.batteryLevel)%")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(batteryColor)
                }

                // Last sent row
                if let lastSent = lastSuccessfulSend {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 10))
                        Text("Last sent:")
                            .font(.system(size: 11))
                        Text(lastSent, style: .relative)
                            .font(.system(size: 11, weight: .medium))
                        Text("ago")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.secondary)
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

    private var connectionIcon: String {
        switch connectionStatus {
        case .connected:
            return "checkmark.circle.fill"
        case .disconnected:
            return "wifi.slash"
        case .error:
            return "exclamationmark.triangle.fill"
        case .unknown:
            return "questionmark.circle"
        }
    }

    private var connectionColor: Color {
        switch connectionStatus {
        case .connected:
            return .green
        case .disconnected:
            return .orange
        case .error:
            return .red
        case .unknown:
            return .secondary
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
