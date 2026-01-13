//
//  SecuritySettingsView.swift
//  Next-track
//
//  Settings view for configuring app security (passcode/biometrics)
//

import SwiftUI
import LocalAuthentication

struct SecuritySettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @Environment(\.dismiss) private var dismiss

    @State private var isEnabled: Bool = false
    @State private var lockMethod: LockMethod = .biometric
    @State private var lockDelay: LockDelay = .immediately
    @State private var hasPasscode: Bool = false

    @State private var showPasscodeSetup = false
    @State private var showChangePasscode = false
    @State private var showDisableConfirmation = false
    @State private var showMethodPicker = false

    @State private var biometricType: String = "Face ID"
    @State private var canUseBiometrics: Bool = false

    var body: some View {
        Form {
            if !isEnabled {
                // Setup options when app lock is OFF
                setupSection
            } else {
                // Management options when app lock is ON
                enabledSection
            }
        }
        .navigationTitle("Security")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadSettings()
            checkBiometricAvailability()
        }
        .sheet(isPresented: $showPasscodeSetup) {
            PasscodeSetupView(
                mode: .setup,
                onComplete: { passcode in
                    setPasscode(passcode)
                    enableAppLock(method: .passcode)
                    showPasscodeSetup = false
                },
                onCancel: {
                    showPasscodeSetup = false
                }
            )
        }
        .sheet(isPresented: $showChangePasscode) {
            PasscodeSetupView(
                mode: .change,
                onComplete: { passcode in
                    setPasscode(passcode)
                    showChangePasscode = false
                },
                onCancel: {
                    showChangePasscode = false
                }
            )
        }
        .alert("Disable App Lock?", isPresented: $showDisableConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Disable", role: .destructive) {
                disableAppLock()
            }
        } message: {
            Text("Your passcode will be removed and the app will no longer require authentication.")
        }
    }

    // MARK: - Setup Section (when disabled)

    private var setupSection: some View {
        Section {
            // Face ID / Touch ID option
            if canUseBiometrics {
                Button {
                    setupBiometric()
                } label: {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.teal, .cyan],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 50, height: 50)

                            Image(systemName: biometricType == "Face ID" ? "faceid" : "touchid")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Use \(biometricType)")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("Quick and secure authentication")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }

            // Passcode option
            Button {
                showPasscodeSetup = true
            } label: {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.purple, .pink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 50, height: 50)

                        Image(systemName: "lock.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Use Passcode")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("4-digit PIN protection")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        } header: {
            Text("Choose Lock Method")
        } footer: {
            Text("Protect your travel data by requiring authentication when opening the app.")
        }
    }

    // MARK: - Enabled Section (when enabled)

    private var enabledSection: some View {
        Group {
            // Current Status
            Section {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: lockMethod == .biometric ? [.teal, .cyan] : [.purple, .pink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 50, height: 50)

                        Image(systemName: lockMethod == .biometric ?
                              (biometricType == "Face ID" ? "faceid" : "touchid") : "lock.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("App Lock Enabled")
                            .font(.headline)
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                            Text(lockMethod == .biometric ? biometricType : "Passcode")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()
                }
                .padding(.vertical, 4)
            } header: {
                Text("Status")
            }

            // Lock Timing
            Section {
                Picker("Require Authentication", selection: $lockDelay) {
                    ForEach(LockDelay.allCases, id: \.self) { delay in
                        Text(delay.displayName).tag(delay)
                    }
                }
                .onChange(of: lockDelay) { _, _ in
                    saveSettings()
                }
            } header: {
                Text("Lock Timing")
            } footer: {
                Text("How long the app can be in the background before requiring authentication.")
            }

            // Change Method
            Section {
                if canUseBiometrics && lockMethod == .passcode {
                    Button {
                        switchToBiometric()
                    } label: {
                        Label("Switch to \(biometricType)", systemImage: biometricType == "Face ID" ? "faceid" : "touchid")
                    }
                }

                if lockMethod == .biometric {
                    Button {
                        showPasscodeSetup = true
                    } label: {
                        Label("Switch to Passcode", systemImage: "lock.fill")
                    }
                }

                if hasPasscode {
                    Button {
                        showChangePasscode = true
                    } label: {
                        Label("Change Passcode", systemImage: "key.fill")
                    }
                }
            } header: {
                Text("Options")
            }

            // Backup Passcode (for biometric)
            if lockMethod == .biometric {
                Section {
                    if hasPasscode {
                        HStack {
                            Label("Backup Passcode", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Spacer()
                            Text("Set")
                                .foregroundColor(.secondary)
                        }

                        Button(role: .destructive) {
                            clearPasscode()
                        } label: {
                            Label("Remove Backup Passcode", systemImage: "trash")
                        }
                    } else {
                        Button {
                            showPasscodeSetup = true
                        } label: {
                            Label("Set Backup Passcode", systemImage: "key.fill")
                        }
                    }
                } header: {
                    Text("Backup")
                } footer: {
                    Text("A backup passcode lets you unlock the app if \(biometricType) is unavailable.")
                }
            }

            // Disable
            Section {
                Button(role: .destructive) {
                    showDisableConfirmation = true
                } label: {
                    HStack {
                        Spacer()
                        Label("Disable App Lock", systemImage: "lock.open")
                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func loadSettings() {
        let settings = settingsManager.securitySettings
        isEnabled = settings.isEnabled
        lockMethod = settings.lockMethod
        lockDelay = settings.lockDelay
        hasPasscode = settings.hasPasscode
    }

    private func saveSettings() {
        var settings = settingsManager.securitySettings
        settings.isEnabled = isEnabled
        settings.lockMethod = lockMethod
        settings.lockDelay = lockDelay
        settingsManager.securitySettings = settings
    }

    private func setupBiometric() {
        // Test biometric authentication first
        let context = LAContext()
        let reason = "Set up \(biometricType) for Been There"

        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
            DispatchQueue.main.async {
                if success {
                    HapticManager.shared.success()
                    enableAppLock(method: .biometric)
                } else {
                    HapticManager.shared.error()
                }
            }
        }
    }

    private func enableAppLock(method: LockMethod) {
        lockMethod = method
        isEnabled = true
        saveSettings()
    }

    private func switchToBiometric() {
        let context = LAContext()
        let reason = "Switch to \(biometricType) for Been There"

        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
            DispatchQueue.main.async {
                if success {
                    HapticManager.shared.success()
                    lockMethod = .biometric
                    saveSettings()
                } else {
                    HapticManager.shared.error()
                }
            }
        }
    }

    private func setPasscode(_ passcode: String) {
        var settings = settingsManager.securitySettings
        settings.setPasscode(passcode)
        settingsManager.securitySettings = settings
        hasPasscode = true
        HapticManager.shared.success()
    }

    private func clearPasscode() {
        var settings = settingsManager.securitySettings
        settings.clearPasscode()
        settingsManager.securitySettings = settings
        hasPasscode = false
    }

    private func disableAppLock() {
        var settings = settingsManager.securitySettings
        settings.isEnabled = false
        settings.clearPasscode()
        settingsManager.securitySettings = settings
        isEnabled = false
        hasPasscode = false
    }

    // MARK: - Biometric Check

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
}

// MARK: - Passcode Setup View

struct PasscodeSetupView: View {
    enum Mode {
        case setup
        case change
    }

    let mode: Mode
    let onComplete: (String) -> Void
    let onCancel: () -> Void

    @State private var step: SetupStep = .enter
    @State private var firstPasscode: String = ""
    @State private var confirmPasscode: String = ""
    @State private var showError = false
    @State private var shakeOffset: CGFloat = 0

    private let passcodeLength = 4

    enum SetupStep {
        case enter
        case confirm
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Dark gradient background
                LinearGradient(
                    colors: [
                        Color(red: 0.08, green: 0.15, blue: 0.22),
                        Color(red: 0.12, green: 0.08, blue: 0.20)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 40) {
                    Spacer()
                        .frame(height: 40)

                    // Instructions
                    VStack(spacing: 12) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.teal)

                        Text(step == .enter ? "Enter New Passcode" : "Confirm Passcode")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)

                        if showError {
                            Text("Passcodes don't match. Try again.")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }

                    // Passcode dots
                    HStack(spacing: 20) {
                        ForEach(0..<passcodeLength, id: \.self) { index in
                            Circle()
                                .fill(index < currentPasscode.count ? Color.teal : Color.white.opacity(0.3))
                                .frame(width: 16, height: 16)
                        }
                    }
                    .offset(x: shakeOffset)

                    Spacer()

                    // Number pad
                    numberPad

                    Spacer()
                        .frame(height: 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .foregroundColor(.teal)
                }
            }
        }
    }

    private var currentPasscode: String {
        step == .enter ? firstPasscode : confirmPasscode
    }

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

            HStack(spacing: 24) {
                Color.clear.frame(width: 70, height: 70)

                numberButton("0")

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

    private func addDigit(_ digit: String) {
        HapticManager.shared.selectionChanged()

        if step == .enter {
            guard firstPasscode.count < passcodeLength else { return }
            firstPasscode += digit
            if firstPasscode.count == passcodeLength {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    step = .confirm
                }
            }
        } else {
            guard confirmPasscode.count < passcodeLength else { return }
            confirmPasscode += digit
            if confirmPasscode.count == passcodeLength {
                verifyPasscodes()
            }
        }
    }

    private func deleteDigit() {
        HapticManager.shared.selectionChanged()

        if step == .enter {
            guard !firstPasscode.isEmpty else { return }
            firstPasscode.removeLast()
        } else {
            guard !confirmPasscode.isEmpty else { return }
            confirmPasscode.removeLast()
        }
        showError = false
    }

    private func verifyPasscodes() {
        if firstPasscode == confirmPasscode {
            HapticManager.shared.success()
            onComplete(firstPasscode)
        } else {
            HapticManager.shared.error()
            showError = true
            shakeAnimation()
            confirmPasscode = ""
        }
    }

    private func shakeAnimation() {
        withAnimation(.default) { shakeOffset = 10 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.default) { shakeOffset = -10 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.default) { shakeOffset = 5 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.default) { shakeOffset = 0 }
        }
    }
}

#Preview {
    NavigationStack {
        SecuritySettingsView()
            .environmentObject(SettingsManager.shared)
    }
}
