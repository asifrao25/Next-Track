//
//  ErrorStateManager.swift
//  Next-track
//
//  Centralized error state management
//  Collects errors from services and surfaces them to the UI
//

import Foundation
import Combine
import UIKit

/// Centralized manager for app-wide error state
/// Collects errors from various services and provides them to the UI
class ErrorStateManager: ObservableObject {

    // MARK: - Singleton

    static let shared = ErrorStateManager()

    // MARK: - Published Properties

    /// Current active errors (most recent first)
    @Published private(set) var currentErrors: [AppError] = []

    /// The most recent error
    @Published private(set) var lastError: AppError?

    /// Whether to show an error alert
    @Published var showErrorAlert: Bool = false

    /// Whether to show the error banner
    @Published var showErrorBanner: Bool = false

    /// The error to display in the alert
    @Published var alertError: AppError?

    // MARK: - Configuration

    /// Maximum number of errors to keep in history
    private let maxErrorCount = 10

    /// How long before auto-dismissing info-level errors (seconds)
    private let autoDismissDelay: TimeInterval = 5.0

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private var autoDismissTimers: [String: Timer] = [:]

    // MARK: - Initialization

    private init() {
        setupBindings()
    }

    private func setupBindings() {
        // Show banner when there are errors
        $currentErrors
            .map { !$0.isEmpty }
            .assign(to: &$showErrorBanner)
    }

    // MARK: - Error Reporting

    /// Report an error to be displayed to the user
    /// - Parameters:
    ///   - error: The error to report
    ///   - showAlert: Whether to show as a blocking alert (default: false for banner)
    func report(_ error: AppError, showAlert: Bool = false) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Remove duplicate if exists
            self.currentErrors.removeAll { $0.id == error.id }

            // Add to front of list
            self.currentErrors.insert(error, at: 0)

            // Trim to max count
            if self.currentErrors.count > self.maxErrorCount {
                self.currentErrors = Array(self.currentErrors.prefix(self.maxErrorCount))
            }

            // Update last error
            self.lastError = error

            // Show alert if requested or if critical
            if showAlert || error.severity == .critical {
                self.alertError = error
                self.showErrorAlert = true
            }

            // Auto-dismiss info-level errors
            if error.severity == .info {
                self.scheduleAutoDismiss(for: error)
            }

            #if DEBUG
            print("[ErrorStateManager] Reported: \(error.errorDescription ?? "Unknown error")")
            #endif
        }
    }

    /// Report an error from a Swift Error type
    func reportError(_ error: Error, context: String? = nil) {
        let appError: AppError

        if let ae = error as? AppError {
            appError = ae
        } else {
            let message = context != nil
                ? "\(context!): \(error.localizedDescription)"
                : error.localizedDescription
            appError = .unknown(message)
        }

        report(appError, showAlert: false)
    }

    // MARK: - Error Dismissal

    /// Dismiss a specific error
    func dismiss(_ error: AppError) {
        DispatchQueue.main.async { [weak self] in
            self?.currentErrors.removeAll { $0.id == error.id }
            self?.autoDismissTimers[error.id]?.invalidate()
            self?.autoDismissTimers.removeValue(forKey: error.id)

            if self?.alertError?.id == error.id {
                self?.showErrorAlert = false
                self?.alertError = nil
            }
        }
    }

    /// Dismiss the alert
    func dismissAlert() {
        showErrorAlert = false
        if let error = alertError {
            // Also remove from banner for critical errors
            if error.severity == .critical {
                dismiss(error)
            }
        }
        alertError = nil
    }

    /// Clear all errors
    func clearAll() {
        DispatchQueue.main.async { [weak self] in
            self?.currentErrors.removeAll()
            self?.lastError = nil
            self?.showErrorAlert = false
            self?.alertError = nil

            // Cancel all timers
            self?.autoDismissTimers.values.forEach { $0.invalidate() }
            self?.autoDismissTimers.removeAll()
        }
    }

    /// Clear errors of a specific type
    func clear(matching predicate: @escaping (AppError) -> Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.currentErrors.removeAll(where: predicate)
        }
    }

    // MARK: - Auto-dismiss

    private func scheduleAutoDismiss(for error: AppError) {
        // Cancel existing timer for this error
        autoDismissTimers[error.id]?.invalidate()

        // Schedule new timer
        let timer = Timer.scheduledTimer(withTimeInterval: autoDismissDelay, repeats: false) { [weak self] _ in
            self?.dismiss(error)
        }
        autoDismissTimers[error.id] = timer
    }

    // MARK: - Convenience Methods

    /// Check if there are any critical errors
    var hasCriticalErrors: Bool {
        currentErrors.contains { $0.severity == .critical }
    }

    /// Get the most critical current error
    var mostCriticalError: AppError? {
        currentErrors.first { $0.severity == .critical }
            ?? currentErrors.first { $0.severity == .error }
            ?? currentErrors.first
    }

    /// Check if a specific error type is currently active
    func hasError(matching predicate: (AppError) -> Bool) -> Bool {
        currentErrors.contains(where: predicate)
    }

    // MARK: - Actions

    /// Open the app's settings in the Settings app
    func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Convenience Extensions

extension ErrorStateManager {

    /// Report a location permission error
    func reportLocationPermissionDenied() {
        report(.locationPermissionDenied, showAlert: true)
    }

    /// Report a server connection error
    func reportServerError(_ error: Error) {
        report(.serverConnectionFailed(error.localizedDescription))
    }

    /// Report a data save error
    func reportSaveError(_ error: Error, dataType: String) {
        report(.dataSaveFailed(dataType, error.localizedDescription))
    }

    /// Report a data load error
    func reportLoadError(_ error: Error, dataType: String) {
        report(.dataLoadFailed(dataType, error.localizedDescription))
    }
}
