//
//  SecuritySettings.swift
//  Next-track
//
//  Security settings for app lock (passcode/biometrics)
//

import Foundation
import CryptoKit

// MARK: - Lock Method

enum LockMethod: String, Codable, CaseIterable {
    case biometric = "biometric"
    case passcode = "passcode"

    var displayName: String {
        switch self {
        case .biometric:
            return "Face ID / Touch ID"
        case .passcode:
            return "Passcode"
        }
    }

    var icon: String {
        switch self {
        case .biometric:
            return "faceid"
        case .passcode:
            return "lock.fill"
        }
    }
}

// MARK: - Lock Delay

enum LockDelay: Int, Codable, CaseIterable {
    case immediately = 0
    case after1Minute = 60
    case after5Minutes = 300
    case after15Minutes = 900

    var displayName: String {
        switch self {
        case .immediately:
            return "Immediately"
        case .after1Minute:
            return "After 1 minute"
        case .after5Minutes:
            return "After 5 minutes"
        case .after15Minutes:
            return "After 15 minutes"
        }
    }
}

// MARK: - Security Settings

struct SecuritySettings: Codable {
    var isEnabled: Bool = false
    var lockMethod: LockMethod = .biometric
    var passcodeHash: String? = nil
    var lockDelay: LockDelay = .immediately

    // MARK: - Default

    static let `default` = SecuritySettings()

    // MARK: - Passcode Helpers

    /// Hash a passcode using SHA256
    static func hashPasscode(_ passcode: String) -> String {
        let data = Data(passcode.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// Verify a passcode against the stored hash
    func verifyPasscode(_ passcode: String) -> Bool {
        guard let storedHash = passcodeHash else { return false }
        return SecuritySettings.hashPasscode(passcode) == storedHash
    }

    /// Set a new passcode (stores the hash)
    mutating func setPasscode(_ passcode: String) {
        passcodeHash = SecuritySettings.hashPasscode(passcode)
    }

    /// Clear the passcode
    mutating func clearPasscode() {
        passcodeHash = nil
    }

    /// Check if passcode is set
    var hasPasscode: Bool {
        return passcodeHash != nil
    }
}

// MARK: - Persistence

extension SecuritySettings {
    private static let storageKey = "securitySettings"

    static func load() -> SecuritySettings {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let settings = try? JSONDecoder().decode(SecuritySettings.self, from: data) else {
            return .default
        }
        return settings
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: SecuritySettings.storageKey)
        }
    }
}
