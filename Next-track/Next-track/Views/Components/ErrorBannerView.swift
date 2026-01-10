//
//  ErrorBannerView.swift
//  Next-track
//
//  A dismissible error banner that displays at the top of the screen
//  Shows error messages with appropriate icons and optional actions
//

import SwiftUI

/// A banner view for displaying errors to the user
/// Can be placed at the top of a view and will animate in/out
struct ErrorBannerView: View {

    let error: AppError
    let onDismiss: () -> Void
    var onAction: (() -> Void)? = nil

    @State private var isVisible = false

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: iconName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(iconColor)
                .accessibilityHidden(true)

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(error.errorDescription ?? "Error")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)

                if let reason = error.failureReason {
                    Text(reason)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            // Action button or dismiss
            if error.shouldShowOpenSettings {
                Button(action: {
                    ErrorStateManager.shared.openAppSettings()
                }) {
                    Text("Settings")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(accentColor)
                        .cornerRadius(14)
                }
                .accessibilityLabel("Open Settings")
                .accessibilityHint("Opens app settings to fix this issue")
            } else if let action = onAction {
                Button(action: action) {
                    Text("Retry")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(accentColor)
                        .cornerRadius(14)
                }
                .accessibilityLabel("Retry")
            }

            // Dismiss button
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 28, height: 28)
                    .background(Color(.systemGray5))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Dismiss error")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(backgroundColor)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 16)
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : -20)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                isVisible = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(error.errorDescription ?? "Error"): \(error.failureReason ?? "")")
        .accessibilityAddTraits(.isStaticText)
    }

    // MARK: - Styling

    private var iconName: String {
        switch error.severity {
        case .info:
            return "info.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .error, .critical:
            return "xmark.circle.fill"
        }
    }

    private var iconColor: Color {
        switch error.severity {
        case .info:
            return .blue
        case .warning:
            return .orange
        case .error, .critical:
            return .red
        }
    }

    private var accentColor: Color {
        switch error.severity {
        case .info:
            return .blue
        case .warning:
            return .orange
        case .error, .critical:
            return .red
        }
    }

    private var backgroundColor: Color {
        switch error.severity {
        case .info:
            return Color(.systemBackground)
        case .warning:
            return Color(.systemBackground)
        case .error, .critical:
            return Color(.systemBackground)
        }
    }
}

// MARK: - Container View

/// A container that displays error banners from ErrorStateManager
struct ErrorBannerContainer: View {

    @ObservedObject var errorManager = ErrorStateManager.shared

    var body: some View {
        VStack(spacing: 8) {
            ForEach(errorManager.currentErrors.prefix(3)) { error in
                ErrorBannerView(
                    error: error,
                    onDismiss: {
                        withAnimation(.easeOut(duration: 0.2)) {
                            errorManager.dismiss(error)
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: errorManager.currentErrors.count)
    }
}

// MARK: - View Modifier

/// A view modifier that adds error banners to a view
struct ErrorBannerModifier: ViewModifier {

    @ObservedObject var errorManager = ErrorStateManager.shared

    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content

            if !errorManager.currentErrors.isEmpty {
                ErrorBannerContainer()
                    .padding(.top, 8)
            }
        }
        .alert(
            errorManager.alertError?.errorDescription ?? "Error",
            isPresented: $errorManager.showErrorAlert,
            presenting: errorManager.alertError
        ) { error in
            if error.shouldShowOpenSettings {
                Button("Open Settings") {
                    errorManager.openAppSettings()
                    errorManager.dismissAlert()
                }
                Button("Dismiss", role: .cancel) {
                    errorManager.dismissAlert()
                }
            } else {
                Button("OK", role: .cancel) {
                    errorManager.dismissAlert()
                }
            }
        } message: { error in
            if let reason = error.failureReason {
                Text(reason)
            }
            if let suggestion = error.recoverySuggestion {
                Text(suggestion)
            }
        }
    }
}

extension View {
    /// Adds error banner overlay and alert handling
    func withErrorBanner() -> some View {
        modifier(ErrorBannerModifier())
    }
}

// MARK: - Preview

#if DEBUG
struct ErrorBannerView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            ErrorBannerView(
                error: .locationPermissionDenied,
                onDismiss: {}
            )

            ErrorBannerView(
                error: .serverConnectionFailed("Connection timed out"),
                onDismiss: {}
            )

            ErrorBannerView(
                error: .geocodingRateLimited,
                onDismiss: {}
            )
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
}
#endif
