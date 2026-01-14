//
//  CustomTitleHeaderView.swift
//  Next-track
//
//  Dynamic header with image banner and live tracking stats
//

import SwiftUI

// MARK: - Connection Status Type

enum ConnectionStatusType {
    case connected
    case disconnected
    case error
    case unknown
}

// MARK: - Dynamic Header View

struct CustomTitleHeaderView: View {
    @ObservedObject var connectionMonitor: ConnectionMonitor
    @ObservedObject var batteryMonitor: BatteryMonitor
    let isTracking: Bool
    let hasIssues: Bool
    let pendingCount: Int
    let currentZoneName: String?
    var connectionStatus: ConnectionStatusType = .unknown
    var lastSuccessfulSend: Date? = nil
    var todayMiles: Double = 0.0
    var sessionDuration: TimeInterval = 0
    var pointsSent: Int = 0
    var currentElevation: Double? = nil  // Current elevation in meters
    var accentColor: Color = .cyan  // Tab accent color for glow

    // Timer for real-time updates
    @State private var currentTime = Date()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        // Unified header pill - image + stats combined
        VStack(spacing: 0) {
            // Top: Header image - full width, maintains aspect ratio
            Image("HeaderImage")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity)
                .opacity(0.75)

            // Bottom: Stats bar integrated into pill
            // Layout: Status | Last Sent | Distance | Elevation
            HStack(spacing: 0) {
                // Status (TRACKING or zone name like HOME/WORK)
                HStack(spacing: 4) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)
                        .shadow(color: statusColor.opacity(0.8), radius: isTracking ? 4 : 0)
                    Text(statusText)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(statusColor)
                }
                .frame(maxWidth: .infinity)

                // Divider
                divider

                // Last sent time (updates every second)
                HStack(spacing: 3) {
                    Image(systemName: lastSuccessfulSend != nil ? "arrow.up.circle.fill" : "arrow.up.circle")
                        .font(.system(size: 9))
                        .foregroundColor(lastSentColor)
                    Text(lastSentText)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity)

                // Divider
                divider

                // Distance today
                HStack(spacing: 3) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 9))
                        .foregroundColor(.blue.opacity(0.9))
                    Text(formatDistance(todayMiles))
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity)

                // Divider
                divider

                // Elevation
                HStack(spacing: 3) {
                    Image(systemName: "mountain.2.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.cyan.opacity(0.9))
                    Text(elevationText)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .background(
                // Frosted glass effect for stats area
                Color(white: 0.05).opacity(0.9)
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.5), accentColor.opacity(0.3), .white.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        // Soft glow layers - uses accent color to match tab bar
        .shadow(color: accentColor.opacity(0.4), radius: 15, x: 0, y: 0)
        .shadow(color: accentColor.opacity(0.3), radius: 25, x: 0, y: 5)
        .shadow(color: shadowColor.opacity(0.5), radius: 20, x: 0, y: 8)
        .onReceive(timer) { time in
            currentTime = time
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: - Subviews

    private var divider: some View {
        Text("•")
            .foregroundColor(.white.opacity(0.25))
            .font(.system(size: 6))
    }

    // MARK: - Computed Properties

    private var statusText: String {
        if isTracking { return "TRACKING" }
        if let zone = currentZoneName { return zone.uppercased() }
        return "IDLE"
    }

    private var statusColor: Color {
        if hasIssues { return .orange }
        if isTracking { return .green }
        if currentZoneName != nil { return .cyan }
        return .gray
    }

    private var lastSentText: String {
        guard let lastSent = lastSuccessfulSend else { return "--" }
        return formatTimeAgo(lastSent)
    }

    private var lastSentColor: Color {
        guard let lastSent = lastSuccessfulSend else { return .gray }
        let seconds = Int(-lastSent.timeIntervalSinceNow)
        // Green if recent (< 2 min), yellow if older (< 10 min), orange if stale
        if seconds < 120 { return .green.opacity(0.9) }
        else if seconds < 600 { return .yellow.opacity(0.9) }
        else { return .orange.opacity(0.9) }
    }

    private var elevationText: String {
        if let elevation = currentElevation {
            let feet = elevation * 3.28084
            return "\(Int(feet))ft"
        }
        return "--"
    }

    private var shadowColor: Color {
        hasIssues ? .orange : (isTracking ? .green : .cyan)
    }

    private var accessibilityDescription: String {
        var description = "Been There. "
        description += isTracking ? "Tracking active. " : "Tracking paused. "
        description += String(format: "%.1f miles today. ", todayMiles)
        if pendingCount > 0 {
            description += "\(pendingCount) points pending. "
        }
        return description
    }

    // MARK: - Formatters

    private func formatTimeAgo(_ date: Date) -> String {
        let seconds = Int(currentTime.timeIntervalSince(date))
        if seconds < 0 { return "now" }
        if seconds < 60 { return "\(seconds)s" }
        else if seconds < 3600 { return "\(seconds / 60)m" }
        else if seconds < 86400 { return "\(seconds / 3600)h" }
        else { return "\(seconds / 86400)d" }
    }

    private func formatDistance(_ miles: Double) -> String {
        if miles >= 10 {
            return String(format: "%.0fmi", miles)
        } else if miles >= 1 {
            return String(format: "%.1fmi", miles)
        } else {
            // Show in feet for small distances
            let feet = miles * 5280
            if feet >= 100 {
                return String(format: "%.0fft", feet)
            }
            return String(format: "%.0fft", feet)
        }
    }
}

// MARK: - Mini Stat (Compact)

struct MiniStat: View {
    let icon: String
    let value: String
    let color: Color
    var isPulsing: Bool = false

    @State private var pulse = false

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(color)
                .scaleEffect(pulse ? 1.1 : 1.0)

            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
        }
        .fixedSize()
        .onAppear {
            if isPulsing {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
        }
    }
}

// MARK: - Mini Last Sent

struct MiniLastSent: View {
    let date: Date

    var body: some View {
        HStack(spacing: 1) {
            Image(systemName: "arrow.up")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.green.opacity(0.6))

            Text(formatTimeAgo(date))
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
        }
        .fixedSize()
    }

    private func formatTimeAgo(_ date: Date) -> String {
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 60 { return "\(seconds)s" }
        else if seconds < 3600 { return "\(seconds / 60)m" }
        else { return "\(seconds / 3600)h" }
    }
}

// MARK: - Mini Status Badge

struct MiniStatusBadge: View {
    let isTracking: Bool
    let hasIssues: Bool
    let zoneName: String?

    @State private var blink = false

    var body: some View {
        HStack(spacing: 4) {
            // Dot
            ZStack {
                if isTracking {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 10, height: 10)
                        .opacity(blink ? 0.2 : 0)
                        .scaleEffect(blink ? 1.5 : 1)
                }
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)
            }

            Text(statusText)
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundColor(statusColor)
        }
        .fixedSize()
        .onAppear {
            if isTracking {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    blink = true
                }
            }
        }
        .onChange(of: isTracking) { _, newValue in
            if newValue {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    blink = true
                }
            } else {
                blink = false
            }
        }
    }

    private var statusText: String {
        if hasIssues { return "WARN" }
        if isTracking { return "LIVE" }
        if let zone = zoneName { return zone.prefix(4).uppercased() }
        return "IDLE"
    }

    private var statusColor: Color {
        if hasIssues { return .orange }
        if isTracking { return .green }
        if zoneName != nil { return .cyan }
        return .gray
    }
}

// MARK: - Connection Dot

struct ConnectionDot: View {
    let status: ConnectionStatusType

    var body: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 8, height: 8)
            .shadow(color: statusColor.opacity(0.5), radius: 3)
    }

    private var statusColor: Color {
        switch status {
        case .connected: return .green
        case .disconnected: return .orange
        case .error: return .red
        case .unknown: return .gray
        }
    }
}

// MARK: - Clouds Overlay View

struct CloudsOverlayView: View {
    @State private var cloud1Offset: CGFloat = 20
    @State private var cloud2Offset: CGFloat = 120
    @State private var cloud3Offset: CGFloat = 220

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Cloud 1 - left side
                Image(systemName: "cloud.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white.opacity(0.35))
                    .blur(radius: 1)
                    .offset(x: cloud1Offset - geometry.size.width/2, y: -8)

                // Cloud 2 - center
                Image(systemName: "cloud.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.white.opacity(0.3))
                    .blur(radius: 1.5)
                    .offset(x: cloud2Offset - geometry.size.width/2, y: 12)

                // Cloud 3 - right side
                Image(systemName: "cloud.fill")
                    .font(.system(size: 25))
                    .foregroundColor(.white.opacity(0.32))
                    .blur(radius: 1)
                    .offset(x: cloud3Offset - geometry.size.width/2, y: -2)
            }
            .onAppear {
                // Cloud 1 - slow drift
                withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                    cloud1Offset = 80
                }

                // Cloud 2 - medium drift
                withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true)) {
                    cloud2Offset = 180
                }

                // Cloud 3 - gentle drift
                withAnimation(.easeInOut(duration: 12).repeatForever(autoreverses: true)) {
                    cloud3Offset = 280
                }
            }
        }
    }
}

// MARK: - Cloud Shape

struct CloudShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        let width = rect.width
        let height = rect.height

        // Create a fluffy cloud shape
        path.move(to: CGPoint(x: width * 0.2, y: height * 0.8))

        // Bottom left bump
        path.addQuadCurve(
            to: CGPoint(x: width * 0.1, y: height * 0.5),
            control: CGPoint(x: 0, y: height * 0.7)
        )

        // Left bump
        path.addQuadCurve(
            to: CGPoint(x: width * 0.25, y: height * 0.2),
            control: CGPoint(x: width * 0.05, y: height * 0.2)
        )

        // Top left bump
        path.addQuadCurve(
            to: CGPoint(x: width * 0.5, y: height * 0.1),
            control: CGPoint(x: width * 0.35, y: 0)
        )

        // Top right bump
        path.addQuadCurve(
            to: CGPoint(x: width * 0.75, y: height * 0.2),
            control: CGPoint(x: width * 0.65, y: 0)
        )

        // Right bump
        path.addQuadCurve(
            to: CGPoint(x: width * 0.9, y: height * 0.5),
            control: CGPoint(x: width * 0.95, y: height * 0.2)
        )

        // Bottom right bump
        path.addQuadCurve(
            to: CGPoint(x: width * 0.8, y: height * 0.8),
            control: CGPoint(x: width, y: height * 0.7)
        )

        // Close bottom
        path.addLine(to: CGPoint(x: width * 0.2, y: height * 0.8))

        return path
    }
}

// MARK: - Aurora Waves Animation

struct AuroraWavesView: View {
    @State private var phase1: CGFloat = 0
    @State private var phase2: CGFloat = 0
    @State private var phase3: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Wave 1 - Cyan/Teal (moves right)
                AuroraWave(
                    colors: [.cyan.opacity(0.4), .teal.opacity(0.3)],
                    phase: phase1,
                    amplitude: 20,
                    frequency: 1.5
                )

                // Wave 2 - Blue/Purple (moves left)
                AuroraWave(
                    colors: [.blue.opacity(0.35), .purple.opacity(0.25)],
                    phase: -phase2,
                    amplitude: 25,
                    frequency: 1.2
                )

                // Wave 3 - Teal/Blue (moves right slower)
                AuroraWave(
                    colors: [.teal.opacity(0.3), .blue.opacity(0.2)],
                    phase: phase3,
                    amplitude: 15,
                    frequency: 2.0
                )
            }
        }
        .blur(radius: 8)
        .onAppear {
            startAnimations()
        }
    }

    private func startAnimations() {
        // Wave 1 - 8 second cycle
        withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
            phase1 = 1
        }

        // Wave 2 - 10 second cycle (delayed start)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true)) {
                phase2 = 1
            }
        }

        // Wave 3 - 12 second cycle (more delayed)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeInOut(duration: 12).repeatForever(autoreverses: true)) {
                phase3 = 1
            }
        }
    }
}

// MARK: - Aurora Wave Shape

struct AuroraWave: View {
    let colors: [Color]
    let phase: CGFloat
    let amplitude: CGFloat
    let frequency: CGFloat

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                let midHeight = height / 2

                path.move(to: CGPoint(x: 0, y: height))

                // Draw wave using sine function
                for x in stride(from: 0, through: width, by: 2) {
                    let relativeX = x / width
                    let sine = sin((relativeX * frequency * .pi * 2) + (phase * .pi * 2))
                    let y = midHeight + (sine * amplitude)
                    path.addLine(to: CGPoint(x: x, y: y))
                }

                path.addLine(to: CGPoint(x: width, y: height))
                path.closeSubpath()
            }
            .fill(
                LinearGradient(
                    colors: colors,
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .offset(x: phase * 50)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct CustomTitleHeaderView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 30) {
            // Active tracking
            CustomTitleHeaderView(
                connectionMonitor: ConnectionMonitor.shared,
                batteryMonitor: BatteryMonitor.shared,
                isTracking: true,
                hasIssues: false,
                pendingCount: 0,
                currentZoneName: nil,
                connectionStatus: .connected,
                lastSuccessfulSend: Date().addingTimeInterval(-45),
                todayMiles: 12.4,
                sessionDuration: 3720,
                pointsSent: 847,
                currentElevation: 152.4,
                accentColor: .green
            )

            // Idle at home
            CustomTitleHeaderView(
                connectionMonitor: ConnectionMonitor.shared,
                batteryMonitor: BatteryMonitor.shared,
                isTracking: false,
                hasIssues: false,
                pendingCount: 0,
                currentZoneName: "Home",
                connectionStatus: .connected,
                todayMiles: 8.2,
                pointsSent: 234,
                currentElevation: 85.0,
                accentColor: .cyan
            )

            // Warning state
            CustomTitleHeaderView(
                connectionMonitor: ConnectionMonitor.shared,
                batteryMonitor: BatteryMonitor.shared,
                isTracking: true,
                hasIssues: true,
                pendingCount: 12,
                currentZoneName: nil,
                connectionStatus: .error,
                todayMiles: 5.7,
                sessionDuration: 1800,
                currentElevation: 220.0,
                accentColor: .orange
            )
        }
        .padding()
        .background(Color.black)
    }
}
#endif
