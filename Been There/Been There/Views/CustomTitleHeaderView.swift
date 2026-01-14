//
//  CustomTitleHeaderView.swift
//  Been There
//
//  Optimized header with image banner and centered tracking status
//  Performance: No timer, minimal observers, single shadow
//

import SwiftUI

// MARK: - Connection Status Type

enum ConnectionStatusType {
    case connected
    case disconnected
    case error
    case unknown
}

// MARK: - Optimized Header View

struct CustomTitleHeaderView: View {
    // Simplified parameters - only what's needed for display
    let isTracking: Bool
    let hasIssues: Bool
    let currentZoneName: String?
    var accentColor: Color = .cyan  // Tab accent color for glow

    var body: some View {
        // Unified header pill - image + centered status
        VStack(spacing: 0) {
            // Top: Header image - full width, maintains aspect ratio
            Image("HeaderImage")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity)
                .opacity(0.75)

            // Bottom: Simplified stats bar - centered status only
            HStack {
                Spacer()
                // Centered status indicator
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                        .shadow(color: statusColor.opacity(0.8), radius: isTracking ? 4 : 0)
                    Text(statusText)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(statusColor)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
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
        // Single optimized shadow (was 3 shadows before)
        .shadow(color: accentColor.opacity(0.5), radius: 18, x: 0, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
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

    private var accessibilityDescription: String {
        var description = "Been There. "
        description += isTracking ? "Tracking active. " : "Tracking paused. "
        return description
    }
}

// MARK: - Preview

#if DEBUG
struct CustomTitleHeaderView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 30) {
            // Active tracking
            CustomTitleHeaderView(
                isTracking: true,
                hasIssues: false,
                currentZoneName: nil,
                accentColor: .green
            )

            // Idle at home
            CustomTitleHeaderView(
                isTracking: false,
                hasIssues: false,
                currentZoneName: "Home",
                accentColor: .cyan
            )

            // Warning state
            CustomTitleHeaderView(
                isTracking: true,
                hasIssues: true,
                currentZoneName: nil,
                accentColor: .orange
            )
        }
        .padding()
        .background(Color.black)
    }
}
#endif
