//
//  TourTooltipView.swift
//  Been There
//
//  Tooltip bubble with text and navigation for guided tours
//

import SwiftUI

enum TooltipPosition {
    case above
    case below
}

struct TourTooltipView: View {
    let step: TourStep
    let totalSteps: Int
    let elementFrame: CGRect
    let onNext: () -> Void

    private let tooltipWidth: CGFloat = 280
    private let tooltipPadding: CGFloat = 16
    private let arrowSize: CGFloat = 12
    private let tooltipHeight: CGFloat = 160
    private let gapFromElement: CGFloat = 24

    private var screenHeight: CGFloat {
        UIScreen.main.bounds.height
    }

    private var screenWidth: CGFloat {
        UIScreen.main.bounds.width
    }

    // Always show above for elements in bottom half of screen
    private var position: TooltipPosition {
        let elementCenterY = elementFrame.midY
        return elementCenterY > screenHeight * 0.4 ? .above : .below
    }

    private var tooltipX: CGFloat {
        // Center tooltip horizontally, but keep within screen bounds
        let minX = tooltipWidth / 2 + 16
        let maxX = screenWidth - tooltipWidth / 2 - 16
        return min(max(screenWidth / 2, minX), maxX)
    }

    // Calculate Y so tooltip doesn't overlap element
    private var tooltipCenterY: CGFloat {
        switch position {
        case .above:
            // Position tooltip so its bottom is above the element with gap
            let bottomY = elementFrame.minY - gapFromElement
            return bottomY - tooltipHeight / 2
        case .below:
            // Position tooltip so its top is below the element with gap
            let topY = elementFrame.maxY + gapFromElement
            return topY + tooltipHeight / 2
        }
    }

    private var arrowX: CGFloat {
        // Arrow points to center of element
        elementFrame.midX
    }

    private var arrowY: CGFloat {
        switch position {
        case .above:
            // Arrow at bottom of tooltip pointing down to element
            return tooltipCenterY + tooltipHeight / 2 + arrowSize / 2
        case .below:
            // Arrow at top of tooltip pointing up to element
            return tooltipCenterY - tooltipHeight / 2 - arrowSize / 2
        }
    }

    var body: some View {
        ZStack {
            // Arrow pointing to element
            Triangle()
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.15), Color(white: 0.1)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: arrowSize * 2, height: arrowSize)
                .rotationEffect(.degrees(position == .below ? 0 : 180))
                .position(x: arrowX, y: arrowY)

            // Tooltip box
            tooltipContent
                .frame(width: tooltipWidth)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [Color(white: 0.15), Color(white: 0.1)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [.cyan.opacity(0.5), .purple.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .cyan.opacity(0.3), radius: 20, x: 0, y: 0)
                .position(x: tooltipX, y: tooltipCenterY)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var tooltipContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Step indicator
            HStack {
                Text("Step \(step.id) of \(totalSteps)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.cyan)

                Spacer()

                // Progress dots
                HStack(spacing: 4) {
                    ForEach(1...totalSteps, id: \.self) { i in
                        Circle()
                            .fill(i == step.id ? Color.cyan : Color.white.opacity(0.3))
                            .frame(width: 6, height: 6)
                    }
                }
            }

            // Title
            Text(step.title)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)

            // Description
            Text(step.description)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)

            // Next/Done button - centered
            HStack {
                Spacer()

                Button {
                    onNext()
                } label: {
                    HStack(spacing: 4) {
                        Text(step.id == totalSteps ? "Done" : "Next")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        if step.id < totalSteps {
                            Image(systemName: "chevron.right")
                                .font(.caption)
                        }
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(
                            colors: [.cyan, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Spacer()
            }
        }
        .padding(tooltipPadding)
    }
}

// MARK: - Triangle Shape

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        TourTooltipView(
            step: TourStep.trackTabSteps[0],
            totalSteps: 6,
            elementFrame: CGRect(x: 150, y: 600, width: 70, height: 70),
            onNext: {}
        )
    }
}
