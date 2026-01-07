//
//  HapticManager.swift
//  Next-track
//
//  Haptic feedback for all app interactions
//

import UIKit

class HapticManager {
    static let shared = HapticManager()

    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let softImpact = UIImpactFeedbackGenerator(style: .soft)
    private let rigidImpact = UIImpactFeedbackGenerator(style: .rigid)
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let notificationFeedback = UINotificationFeedbackGenerator()

    private init() {
        // Prepare generators for immediate feedback
        prepareAll()
    }

    func prepareAll() {
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        selectionFeedback.prepare()
        notificationFeedback.prepare()
    }

    // MARK: - Button Taps

    /// Light tap for regular buttons
    func buttonTap() {
        lightImpact.impactOccurred()
    }

    /// Medium tap for important buttons
    func importantButtonTap() {
        mediumImpact.impactOccurred()
    }

    /// Heavy tap for critical actions
    func criticalButtonTap() {
        heavyImpact.impactOccurred()
    }

    // MARK: - Tracking Actions

    /// Start tracking - success feel
    func trackingStarted() {
        notificationFeedback.notificationOccurred(.success)
    }

    /// Stop tracking - warning feel
    func trackingStopped() {
        notificationFeedback.notificationOccurred(.warning)
    }

    /// Location sent successfully
    func locationSent() {
        softImpact.impactOccurred(intensity: 0.5)
    }

    /// Failed to send location
    func locationFailed() {
        notificationFeedback.notificationOccurred(.error)
    }

    // MARK: - Navigation & Selection

    /// Tab selection or picker change
    func selectionChanged() {
        selectionFeedback.selectionChanged()
    }

    /// Menu opened
    func menuOpened() {
        lightImpact.impactOccurred(intensity: 0.6)
    }

    /// Toggle switched
    func toggleChanged() {
        rigidImpact.impactOccurred(intensity: 0.6)
    }

    /// Slider value changed
    func sliderChanged() {
        selectionFeedback.selectionChanged()
    }

    // MARK: - Alerts & Notifications

    /// Success notification
    func success() {
        notificationFeedback.notificationOccurred(.success)
    }

    /// Warning notification
    func warning() {
        notificationFeedback.notificationOccurred(.warning)
    }

    /// Error notification
    func error() {
        notificationFeedback.notificationOccurred(.error)
    }

    // MARK: - Gestures

    /// Pull to refresh triggered
    func refresh() {
        mediumImpact.impactOccurred()
    }

    /// Swipe action
    func swipe() {
        lightImpact.impactOccurred(intensity: 0.7)
    }

    /// Long press triggered
    func longPress() {
        heavyImpact.impactOccurred()
    }

    // MARK: - Map Interactions

    /// Dropped pin on map
    func mapPinDropped() {
        rigidImpact.impactOccurred()
    }

    /// Map centered on location
    func mapCentered() {
        lightImpact.impactOccurred()
    }

    // MARK: - QR Code

    /// QR code successfully scanned
    func qrCodeScanned() {
        notificationFeedback.notificationOccurred(.success)
    }

    // MARK: - Connection Status

    /// Connection restored
    func connectionRestored() {
        notificationFeedback.notificationOccurred(.success)
    }

    /// Connection lost
    func connectionLost() {
        notificationFeedback.notificationOccurred(.warning)
    }
}

// MARK: - SwiftUI View Extension

import SwiftUI

extension View {
    func hapticOnTap(_ style: HapticStyle = .light) -> some View {
        self.simultaneousGesture(TapGesture().onEnded { _ in
            switch style {
            case .light:
                HapticManager.shared.buttonTap()
            case .medium:
                HapticManager.shared.importantButtonTap()
            case .heavy:
                HapticManager.shared.criticalButtonTap()
            case .success:
                HapticManager.shared.success()
            case .warning:
                HapticManager.shared.warning()
            case .error:
                HapticManager.shared.error()
            case .selection:
                HapticManager.shared.selectionChanged()
            }
        })
    }
}

enum HapticStyle {
    case light
    case medium
    case heavy
    case success
    case warning
    case error
    case selection
}
