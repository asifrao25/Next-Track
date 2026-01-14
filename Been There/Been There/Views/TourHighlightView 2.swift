//
//  TourHighlightView.swift
//  Been There
//
//  Spotlight/cutout effect for tour highlighting with pulsing glow
//

import SwiftUI

struct TourHighlightView: View {
    let frame: CGRect
    let cornerRadius: CGFloat

    @State private var pulsePhase: CGFloat = 0

    // Padding around the element for the cutout
    private let padding: CGFloat = 10

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size

            ZStack {
                // Dark overlay with hole cut out
                Canvas { context, canvasSize in
                    let fullRect = CGRect(origin: .zero, size: canvasSize)
                    let cutoutRect = CGRect(
                        x: frame.minX - padding,
                        y: frame.minY - padding,
                        width: frame.width + padding * 2,
                        height: frame.height + padding * 2
                    )

                    var path = Path()
                    path.addRect(fullRect)
                    path.addRoundedRect(
                        in: cutoutRect,
                        cornerRadii: RectangleCornerRadii(
                            topLeading: cornerRadius + padding,
                            bottomLeading: cornerRadius + padding,
                            bottomTrailing: cornerRadius + padding,
                            topTrailing: cornerRadius + padding
                        )
                    )

                    context.fill(path, with: .color(.black.opacity(0.85)), style: FillStyle(eoFill: true))
                }

                // Pulsing glow ring
                RoundedRectangle(cornerRadius: cornerRadius + padding)
                    .stroke(
                        LinearGradient(
                            colors: [.cyan, .purple, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3 + pulsePhase * 2
                    )
                    .frame(
                        width: frame.width + padding * 2,
                        height: frame.height + padding * 2
                    )
                    .opacity(1.0 - pulsePhase * 0.5)
                    .position(x: frame.midX, y: frame.midY)

                // Outer glow pulse
                RoundedRectangle(cornerRadius: cornerRadius + padding + 8)
                    .stroke(
                        LinearGradient(
                            colors: [.cyan.opacity(0.6), .purple.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(
                        width: frame.width + padding * 2 + 16,
                        height: frame.height + padding * 2 + 16
                    )
                    .scaleEffect(1.0 + pulsePhase * 0.15)
                    .opacity(0.6 - pulsePhase * 0.4)
                    .position(x: frame.midX, y: frame.midY)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1.2)
                .repeatForever(autoreverses: true)
            ) {
                pulsePhase = 1.0
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.blue.opacity(0.3)

        TourHighlightView(
            frame: CGRect(x: 160, y: 500, width: 70, height: 70),
            cornerRadius: 35
        )
    }
}
