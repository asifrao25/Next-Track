//
//  TourOverlayView.swift
//  Been There
//
//  Main tour overlay component that combines highlight and tooltip
//

import SwiftUI

struct TourOverlayView: View {
    @Binding var isShowing: Bool
    let anchors: [TourElement: Anchor<CGRect>]
    let geometry: GeometryProxy
    let steps: [TourStep]
    let onComplete: () -> Void

    @State private var currentStepIndex: Int = 0

    private var currentStep: TourStep {
        steps[currentStepIndex]
    }

    private var currentFrame: CGRect {
        guard let anchor = anchors[currentStep.element] else { return .zero }
        return geometry[anchor]
    }

    private var cornerRadius: CGFloat {
        switch currentStep.element {
        // Track tab - circular buttons
        case .playButton, .locationButton, .fullScreenButton:
            return currentFrame.width / 2
        // Track tab - pills
        case .frequencyPill, .geofencePill:
            return 20
        // Track tab - header
        case .headerStats:
            return 16

        // Visited tab - circular buttons
        case .visitedAddButton, .visitedMyLocationButton, .visitedGlobeButton, .visitedMapButton:
            return currentFrame.width / 2
        // Visited tab - square-ish buttons
        case .visitedListButton, .visitedZoomIn, .visitedZoomOut:
            return 12
        // Visited tab - top stats bar
        case .visitedTopStats:
            return 16
        }
    }

    var body: some View {
        ZStack {
            if currentFrame != .zero {
                // Highlight with pulsing glow
                TourHighlightView(
                    frame: currentFrame,
                    cornerRadius: cornerRadius
                )
                .transition(.opacity)

                // Tooltip with info and navigation
                TourTooltipView(
                    step: currentStep,
                    totalSteps: steps.count,
                    elementFrame: currentFrame,
                    onNext: nextStep
                )
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: currentStepIndex)
    }

    private func nextStep() {
        HapticManager.shared.light()

        if currentStepIndex < steps.count - 1 {
            withAnimation {
                currentStepIndex += 1
            }
        } else {
            completeTour()
        }
    }

    private func completeTour() {
        withAnimation(.easeOut(duration: 0.3)) {
            isShowing = false
        }
        onComplete()
    }
}

// MARK: - Preview Helper

struct TourOverlayPreview: View {
    @State private var isShowing = true

    var body: some View {
        ZStack {
            Color.gray.opacity(0.3)

            VStack {
                Spacer()
                Circle()
                    .fill(Color.green)
                    .frame(width: 70, height: 70)
                    .anchorPreference(key: TourAnchorPreferenceKey.self, value: .bounds) { anchor in
                        [.playButton: anchor]
                    }
                    .padding(.bottom, 100)
            }
        }
        .overlayPreferenceValue(TourAnchorPreferenceKey.self) { anchors in
            GeometryReader { geometry in
                if isShowing {
                    TourOverlayView(
                        isShowing: $isShowing,
                        anchors: anchors,
                        geometry: geometry,
                        steps: TourStep.trackTabSteps,
                        onComplete: {}
                    )
                }
            }
        }
    }
}

#Preview {
    TourOverlayPreview()
}
