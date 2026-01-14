//
//  BatteryMonitor.swift
//  Next-track
//
//  Battery level and state monitoring
//

import Foundation
import UIKit
import Combine

class BatteryMonitor: ObservableObject {
    static let shared = BatteryMonitor()

    @Published var batteryLevel: Int = 100
    @Published var batteryState: UIDevice.BatteryState = .unknown
    @Published var isLowPowerModeEnabled: Bool = false

    private var cancellables = Set<AnyCancellable>()

    private init() {
        // Enable battery monitoring
        UIDevice.current.isBatteryMonitoringEnabled = true

        // Initial values
        updateBatteryInfo()

        // Observe battery level changes
        NotificationCenter.default.publisher(for: UIDevice.batteryLevelDidChangeNotification)
            .sink { [weak self] _ in
                self?.updateBatteryInfo()
            }
            .store(in: &cancellables)

        // Observe battery state changes
        NotificationCenter.default.publisher(for: UIDevice.batteryStateDidChangeNotification)
            .sink { [weak self] _ in
                self?.updateBatteryInfo()
            }
            .store(in: &cancellables)

        // Observe Low Power Mode changes
        NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)
            .sink { [weak self] _ in
                self?.updatePowerState()
            }
            .store(in: &cancellables)

        updatePowerState()
    }

    private func updateBatteryInfo() {
        let level = UIDevice.current.batteryLevel
        batteryLevel = level >= 0 ? Int(level * 100) : 100
        batteryState = UIDevice.current.batteryState
    }

    private func updatePowerState() {
        isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    // MARK: - Battery State Helpers

    var isCharging: Bool {
        batteryState == .charging || batteryState == .full
    }

    var isCriticallyLow: Bool {
        batteryLevel <= 10 && !isCharging
    }

    var isLow: Bool {
        batteryLevel <= 20 && !isCharging
    }

    var batteryStateDescription: String {
        switch batteryState {
        case .unknown:
            return "Unknown"
        case .unplugged:
            return "On Battery"
        case .charging:
            return "Charging"
        case .full:
            return "Fully Charged"
        @unknown default:
            return "Unknown"
        }
    }

    // MARK: - Smart Mode Helpers

    func shouldReduceFrequency(threshold: Int) -> Bool {
        return batteryLevel <= threshold && !isCharging
    }

    func shouldPauseTracking(criticalThreshold: Int) -> Bool {
        return batteryLevel <= criticalThreshold && !isCharging
    }

    func recommendedIntervalMultiplier(settings: TrackingSettings) -> Double {
        guard settings.smartModeEnabled else { return 1.0 }

        if isCharging {
            return 1.0 // Normal interval when charging
        }

        if batteryLevel <= settings.criticalBatteryThreshold {
            return settings.pauseOnCriticalBattery ? 0 : 4.0 // 4x interval or pause
        }

        if batteryLevel <= settings.smartModeBatteryThreshold {
            return 2.0 // 2x interval when low battery
        }

        if isLowPowerModeEnabled {
            return 2.0 // 2x interval in Low Power Mode
        }

        return 1.0
    }
}
