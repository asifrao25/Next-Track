//
//  ServerConfig.swift
//  Next-track
//
//  Server configuration model for Nextcloud PhoneTrack
//

import Foundation
import UIKit

struct ServerConfig: Codable, Equatable {
    var serverURL: String
    var token: String
    var deviceName: String

    // Computed property for full logging URL
    var loggingURL: String {
        let baseURL = serverURL.hasSuffix("/") ? String(serverURL.dropLast()) : serverURL
        return "\(baseURL)/index.php/apps/phonetrack/logGet/\(token)/\(deviceName)"
    }

    // Default configuration
    static var `default`: ServerConfig {
        ServerConfig(
            serverURL: "",
            token: "",
            deviceName: UIDevice.current.name
        )
    }

    // Check if configuration is valid
    var isValid: Bool {
        !serverURL.isEmpty && !token.isEmpty && !deviceName.isEmpty
    }

    // Parse from PhoneTrack logging URL
    static func parse(from url: String) -> ServerConfig? {
        // Expected format: https://server/index.php/apps/phonetrack/logGet/TOKEN/DEVICE
        // Or: https://server/nextcloud/index.php/apps/phonetrack/logGet/TOKEN/DEVICE

        guard let urlComponents = URLComponents(string: url) else { return nil }

        let pathComponents = urlComponents.path.components(separatedBy: "/")

        // Find the index of "logGet" in the path
        guard let logGetIndex = pathComponents.firstIndex(of: "logGet"),
              pathComponents.count > logGetIndex + 1 else {
            return nil
        }

        let token = pathComponents[logGetIndex + 1]
        let deviceName = pathComponents.count > logGetIndex + 2 ? pathComponents[logGetIndex + 2] : UIDevice.current.name

        // Reconstruct server URL (everything before /index.php/apps/phonetrack)
        if let phonetrackIndex = pathComponents.firstIndex(of: "phonetrack"),
           phonetrackIndex >= 3 {
            let serverPathComponents = pathComponents[0..<(phonetrackIndex - 2)]
            var serverURL = "\(urlComponents.scheme ?? "https")://\(urlComponents.host ?? "")"
            if !serverPathComponents.isEmpty {
                serverURL += serverPathComponents.joined(separator: "/")
            }

            return ServerConfig(
                serverURL: serverURL,
                token: token,
                deviceName: deviceName.isEmpty ? UIDevice.current.name : deviceName
            )
        }

        return nil
    }
}

// MARK: - UserDefaults Storage
extension ServerConfig {
    private static let storageKey = "serverConfig"

    static func load() -> ServerConfig {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let config = try? JSONDecoder().decode(ServerConfig.self, from: data) else {
            return .default
        }
        return config
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: ServerConfig.storageKey)
        }
    }
}
