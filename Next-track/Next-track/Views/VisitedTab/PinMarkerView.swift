//
//  PinMarkerView.swift
//  Next-track
//
//  Pushpin-style marker for visited cities on the globe
//

import SwiftUI

// MARK: - Triangle Shape for Pin Needle

struct PinTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

// MARK: - City Pin Marker

struct PinMarkerView: View {
    let cityName: String
    var showLabel: Bool = false

    // Total height calculation for anchor offset:
    // Pin head area: 32pt, Needle: 12pt with -3 offset = 9pt visible
    // Total: ~41pt, anchor should be at bottom (needle tip)
    private let totalHeight: CGFloat = 41
    private let anchorOffset: CGFloat = 20.5  // Half of total height to move anchor to bottom

    var body: some View {
        VStack(spacing: 0) {
            // Optional city name label
            if showLabel {
                Text(cityName)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.7))
                    )
                    .offset(y: -4)
            }

            // Pin head (circular top)
            ZStack {
                // Static outer glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.red.opacity(0.4),
                                Color.orange.opacity(0.2),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 4,
                            endRadius: 16
                        )
                    )
                    .frame(width: 32, height: 32)

                // Pin head with gradient
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.red,
                                Color.red.opacity(0.9),
                                Color.orange.opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 16, height: 16)
                    .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 2)

                // Shine highlight
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.6), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .center
                        )
                    )
                    .frame(width: 14, height: 14)
                    .offset(x: -2, y: -2)
            }

            // Pin needle
            PinTriangle()
                .fill(
                    LinearGradient(
                        colors: [Color.gray.opacity(0.8), Color.gray.opacity(0.5)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 6, height: 12)
                .offset(y: -3)
                .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
        }
        // Offset the entire view so the needle tip aligns with the coordinate
        .offset(y: -anchorOffset)
    }
}

// MARK: - Mini Pin Marker (for zoomed out view)

struct MiniPinMarkerView: View {
    var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [.red, .orange],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 8, height: 8)
            .shadow(color: .red.opacity(0.5), radius: 3)
    }
}

// MARK: - Pending Pin Marker (for long-press)

struct PendingPinMarkerView: View {
    let isLoading: Bool

    @State private var pulse = false

    // Anchor offset to position needle tip at coordinate
    private let anchorOffset: CGFloat = 24

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                // Pulsing outer glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.teal.opacity(pulse ? 0.6 : 0.3),
                                Color.purple.opacity(pulse ? 0.3 : 0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 4,
                            endRadius: 20
                        )
                    )
                    .frame(width: 40, height: 40)

                // Pin head with gradient
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.teal, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 18, height: 18)
                    .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 2)

                // Loading indicator
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                        .tint(.white)
                }

                // Shine highlight
                if !isLoading {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.6), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .center
                            )
                        )
                        .frame(width: 16, height: 16)
                        .offset(x: -2, y: -2)
                }
            }

            // Pin needle
            PinTriangle()
                .fill(
                    LinearGradient(
                        colors: [Color.gray.opacity(0.8), Color.gray.opacity(0.5)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 6, height: 12)
                .offset(y: -3)
                .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
        }
        // Offset so needle tip aligns with coordinate
        .offset(y: -anchorOffset)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

// MARK: - Country Flag Pin

struct CountryFlagPinView: View {
    let flag: String

    // Anchor offset: Flag area ~48pt + needle 14pt with -4 offset = ~58pt total
    // Offset to position needle tip at coordinate
    private let anchorOffset: CGFloat = 29

    var body: some View {
        VStack(spacing: 0) {
            // Flag with pin styling
            ZStack {
                // Static outer glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.blue.opacity(0.3),
                                Color.purple.opacity(0.15),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 8,
                            endRadius: 24
                        )
                    )
                    .frame(width: 48, height: 48)

                // Flag circle background
                Circle()
                    .fill(Color.white)
                    .frame(width: 28, height: 28)
                    .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)

                // Flag emoji
                Text(flag)
                    .font(.system(size: 18))
            }

            // Pin needle
            PinTriangle()
                .fill(
                    LinearGradient(
                        colors: [Color.gray.opacity(0.8), Color.gray.opacity(0.5)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 8, height: 14)
                .offset(y: -4)
                .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
        }
        // Offset so needle tip aligns with coordinate
        .offset(y: -anchorOffset)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack(spacing: 40) {
            CountryFlagPinView(flag: "🇬🇧")
            CountryFlagPinView(flag: "🇫🇷")
            PinMarkerView(cityName: "London", showLabel: true)
            PinMarkerView(cityName: "Paris")
            MiniPinMarkerView()
        }
    }
}
