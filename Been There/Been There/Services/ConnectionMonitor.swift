//
//  ConnectionMonitor.swift
//  Next-track
//
//  Monitor connection to server and notify on prolonged disconnection
//

import Foundation
import Network
import UserNotifications

class ConnectionMonitor: ObservableObject {
    static let shared = ConnectionMonitor()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "ConnectionMonitor")

    @Published var isConnected: Bool = true
    @Published var connectionType: ConnectionType = .unknown
    @Published var lastSuccessfulConnection: Date?
    @Published var disconnectedSince: Date?
    @Published var hasNotifiedDisconnection: Bool = false

    // Latency tracking
    @Published var latencyHistory: [TimeInterval] = []
    @Published var averageLatency: TimeInterval?

    private var disconnectionTimer: Timer?
    private let disconnectionThreshold: TimeInterval = 5 * 60 // 5 minutes
    private let maxLatencyHistoryCount = 20

    enum ConnectionType: String {
        case wifi = "WiFi"
        case cellular = "Cellular"
        case ethernet = "Ethernet"
        case unknown = "Unknown"
    }

    private init() {
        startMonitoring()
        setupServerConnectionMonitoring()
    }

    // MARK: - Network Monitoring

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied

                if path.usesInterfaceType(.wifi) {
                    self?.connectionType = .wifi
                } else if path.usesInterfaceType(.cellular) {
                    self?.connectionType = .cellular
                } else if path.usesInterfaceType(.wiredEthernet) {
                    self?.connectionType = .ethernet
                } else {
                    self?.connectionType = .unknown
                }

                print("[ConnectionMonitor] Network: \(self?.connectionType.rawValue ?? "Unknown") - Connected: \(path.status == .satisfied)")
            }
        }
        monitor.start(queue: queue)
    }

    // MARK: - Server Connection Monitoring

    private func setupServerConnectionMonitoring() {
        // Observe PhoneTrackAPI connection status
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleConnectionStatusChange),
            name: NSNotification.Name("PhoneTrackConnectionStatusChanged"),
            object: nil
        )
    }

    func recordSuccessfulSend() {
        DispatchQueue.main.async {
            self.lastSuccessfulConnection = Date()
            self.disconnectedSince = nil
            self.hasNotifiedDisconnection = false
            self.disconnectionTimer?.invalidate()
            self.disconnectionTimer = nil
            print("[ConnectionMonitor] Successful send recorded")
        }
    }

    func recordFailedSend() {
        DispatchQueue.main.async {
            if self.disconnectedSince == nil {
                self.disconnectedSince = Date()
                self.startDisconnectionTimer()
                print("[ConnectionMonitor] Failed send - starting disconnection timer")
            }
        }
    }

    // MARK: - Latency Tracking

    func recordLatency(_ latencyMs: TimeInterval) {
        DispatchQueue.main.async {
            self.latencyHistory.append(latencyMs)

            // Keep only recent measurements
            if self.latencyHistory.count > self.maxLatencyHistoryCount {
                self.latencyHistory.removeFirst()
            }

            // Calculate rolling average
            if !self.latencyHistory.isEmpty {
                self.averageLatency = self.latencyHistory.reduce(0, +) / Double(self.latencyHistory.count)
            }

            print("[ConnectionMonitor] Latency: \(Int(latencyMs))ms, Avg: \(Int(self.averageLatency ?? 0))ms")
        }
    }

    func resetLatencyStats() {
        DispatchQueue.main.async {
            self.latencyHistory.removeAll()
            self.averageLatency = nil
        }
    }

    private func startDisconnectionTimer() {
        disconnectionTimer?.invalidate()
        disconnectionTimer = Timer.scheduledTimer(
            withTimeInterval: disconnectionThreshold,
            repeats: false
        ) { [weak self] _ in
            self?.handleProlongedDisconnection()
        }
    }

    private func handleProlongedDisconnection() {
        guard !hasNotifiedDisconnection else { return }

        hasNotifiedDisconnection = true
        sendDisconnectionNotification()
        print("[ConnectionMonitor] Prolonged disconnection detected - notification sent")
    }

    @objc private func handleConnectionStatusChange(_ notification: Notification) {
        if let isConnected = notification.userInfo?["isConnected"] as? Bool {
            if isConnected {
                recordSuccessfulSend()
            } else {
                recordFailedSend()
            }
        }
    }

    // MARK: - Notifications

    private func sendDisconnectionNotification() {
        requestNotificationPermission { granted in
            guard granted else { return }

            let content = UNMutableNotificationContent()
            content.title = "⚠️ Connection Lost"
            content.body = "Been There hasn't been able to send location data for 5 minutes. Check your internet connection."
            content.sound = .default
            content.interruptionLevel = .timeSensitive

            let request = UNNotificationRequest(
                identifier: "disconnection-warning",
                content: content,
                trigger: nil
            )

            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("[ConnectionMonitor] Failed to send notification: \(error)")
                }
            }
        }
    }

    func requestNotificationPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    // MARK: - Status

    var disconnectionDuration: TimeInterval? {
        guard let since = disconnectedSince else { return nil }
        return Date().timeIntervalSince(since)
    }

    var statusDescription: String {
        if let since = disconnectedSince {
            let duration = Date().timeIntervalSince(since)
            let minutes = Int(duration / 60)
            if minutes < 1 {
                return "Disconnected < 1 min"
            } else {
                return "Disconnected \(minutes) min"
            }
        }
        return "Connected"
    }
}
