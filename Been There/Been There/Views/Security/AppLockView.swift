//
//  AppLockView.swift
//  Next-track
//
//  Custom themed lock screen for app security
//

import SwiftUI
import LocalAuthentication

struct AppLockView: View {
    @Binding var isUnlocked: Bool
    let securitySettings: SecuritySettings

    @State private var enteredPasscode: String = ""
    @State private var showError = false
    @State private var shakeOffset: CGFloat = 0
    @State private var biometricType: String = "Face ID"
    @State private var canUseBiometrics: Bool = false
    @State private var hasTriggeredBiometric: Bool = false  // Prevent multiple auto-triggers

    private let passcodeLength = 4

    var body: some View {
        ZStack {
            // Dark gradient background matching app theme
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.15, blue: 0.22),
                    Color(red: 0.12, green: 0.08, blue: 0.20)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 80)

                // App branding
                VStack(spacing: 12) {
                    Text("Been There")
                        .font(.custom("Snell Roundhand", size: 44))
                        .foregroundColor(.white)

                    Image(systemName: "lock.fill")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.teal, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                Spacer()
                    .frame(height: 50)

                // Passcode dots
                if securitySettings.lockMethod == .passcode || !canUseBiometrics {
                    VStack(spacing: 30) {
                        Text("Enter Passcode")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))

                        // Passcode dots indicator
                        HStack(spacing: 20) {
                            ForEach(0..<passcodeLength, id: \.self) { index in
                                Circle()
                                    .fill(index < enteredPasscode.count ? Color.teal : Color.white.opacity(0.3))
                                    .frame(width: 16, height: 16)
                                    .animation(.easeInOut(duration: 0.15), value: enteredPasscode.count)
                            }
                        }
                        .offset(x: shakeOffset)

                        if showError {
                            Text("Incorrect passcode")
                                .font(.caption)
                                .foregroundColor(.red)
                                .transition(.opacity)
                        }
                    }

                    Spacer()
                        .frame(height: 40)

                    // Number pad
                    numberPad
                } else {
                    // Biometric prompt
                    VStack(spacing: 30) {
                        Text("Unlock with \(biometricType)")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))

                        Button {
                            authenticateWithBiometrics()
                        } label: {
                            VStack(spacing: 12) {
                                Image(systemName: biometricType == "Face ID" ? "faceid" : "touchid")
                                    .font(.system(size: 60))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.teal, .cyan],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )

                                Text("Tap to unlock")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer()

                // Use passcode / Use Face ID toggle
                if securitySettings.lockMethod == .biometric && securitySettings.hasPasscode {
                    Button {
                        // Toggle to passcode entry
                    } label: {
                        Text("Use Passcode Instead")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.teal)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 40)
                } else if securitySettings.lockMethod == .passcode && canUseBiometrics {
                    Button {
                        authenticateWithBiometrics()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: biometricType == "Face ID" ? "faceid" : "touchid")
                                .font(.system(size: 16))
                            Text("Use \(biometricType)")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.teal)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            checkBiometricAvailability()
            // Auto-trigger biometric on appear, but only once
            if securitySettings.lockMethod == .biometric && canUseBiometrics && !hasTriggeredBiometric {
                hasTriggeredBiometric = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    authenticateWithBiometrics()
                }
            }
        }
    }

    // MARK: - Number Pad

    private var numberPad: some View {
        VStack(spacing: 16) {
            ForEach(0..<3) { row in
                HStack(spacing: 24) {
                    ForEach(1...3, id: \.self) { col in
                        let number = row * 3 + col
                        numberButton(String(number))
                    }
                }
            }

            // Bottom row: empty, 0, delete
            HStack(spacing: 24) {
                // Empty space or Face ID button
                if canUseBiometrics && securitySettings.lockMethod == .passcode {
                    Button {
                        authenticateWithBiometrics()
                    } label: {
                        Image(systemName: biometricType == "Face ID" ? "faceid" : "touchid")
                            .font(.system(size: 24))
                            .foregroundColor(.teal)
                            .frame(width: 70, height: 70)
                    }
                    .buttonStyle(.plain)
                } else {
                    Color.clear
                        .frame(width: 70, height: 70)
                }

                numberButton("0")

                // Delete button
                Button {
                    deleteDigit()
                } label: {
                    Image(systemName: "delete.left.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 70, height: 70)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func numberButton(_ number: String) -> some View {
        Button {
            addDigit(number)
        } label: {
            Text(number)
                .font(.system(size: 32, weight: .light))
                .foregroundColor(.white)
                .frame(width: 70, height: 70)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.1))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Passcode Logic

    private func addDigit(_ digit: String) {
        guard enteredPasscode.count < passcodeLength else { return }

        HapticManager.shared.selectionChanged()
        enteredPasscode += digit

        if enteredPasscode.count == passcodeLength {
            verifyPasscode()
        }
    }

    private func deleteDigit() {
        guard !enteredPasscode.isEmpty else { return }
        HapticManager.shared.selectionChanged()
        enteredPasscode.removeLast()
        showError = false
    }

    private func verifyPasscode() {
        if securitySettings.verifyPasscode(enteredPasscode) {
            HapticManager.shared.success()
            withAnimation(.easeOut(duration: 0.2)) {
                isUnlocked = true
            }
        } else {
            HapticManager.shared.error()
            showError = true
            shakeAnimation()
            enteredPasscode = ""
        }
    }

    private func shakeAnimation() {
        withAnimation(.default) {
            shakeOffset = 10
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.default) {
                shakeOffset = -10
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.default) {
                shakeOffset = 5
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.default) {
                shakeOffset = 0
            }
        }
    }

    // MARK: - Biometric Authentication

    private func checkBiometricAvailability() {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            canUseBiometrics = true
            switch context.biometryType {
            case .faceID:
                biometricType = "Face ID"
            case .touchID:
                biometricType = "Touch ID"
            default:
                biometricType = "Biometrics"
            }
        } else {
            canUseBiometrics = false
        }
    }

    private func authenticateWithBiometrics() {
        let context = LAContext()
        let reason = "Unlock Been There to access your travel data"

        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
            DispatchQueue.main.async {
                if success {
                    HapticManager.shared.success()
                    withAnimation(.easeOut(duration: 0.2)) {
                        isUnlocked = true
                    }
                } else {
                    // Biometric failed - user can try passcode if available
                    if securitySettings.hasPasscode {
                        // They can use the number pad
                    }
                }
            }
        }
    }
}

#Preview {
    AppLockView(
        isUnlocked: .constant(false),
        securitySettings: SecuritySettings()
    )
}
