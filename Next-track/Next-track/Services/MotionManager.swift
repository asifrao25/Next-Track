//
//  MotionManager.swift
//  Next-track
//
//  Core Motion for activity detection (motion-aware tracking)
//

import Foundation
import CoreMotion
import Combine

class MotionManager: ObservableObject {
    static let shared = MotionManager()

    private let motionActivityManager = CMMotionActivityManager()
    private let pedometer = CMPedometer()

    @Published var currentActivity: ActivityType = .unknown
    @Published var isStationary: Bool = false
    @Published var stationarySince: Date?

    private var stationaryTimer: Timer?
    private var stationaryDelayMinutes: Int = 5

    enum ActivityType: String {
        case stationary = "Stationary"
        case walking = "Walking"
        case running = "Running"
        case cycling = "Cycling"
        case automotive = "Driving"
        case unknown = "Unknown"

        var icon: String {
            switch self {
            case .stationary: return "figure.stand"
            case .walking: return "figure.walk"
            case .running: return "figure.run"
            case .cycling: return "bicycle"
            case .automotive: return "car.fill"
            case .unknown: return "questionmark"
            }
        }
    }

    private init() {}

    // MARK: - Activity Tracking

    func startActivityTracking(stationaryDelayMinutes: Int = 5) {
        guard CMMotionActivityManager.isActivityAvailable() else {
            print("[MotionManager] Motion activity not available on this device")
            return
        }

        self.stationaryDelayMinutes = stationaryDelayMinutes

        motionActivityManager.startActivityUpdates(to: .main) { [weak self] activity in
            guard let activity = activity else { return }
            self?.processActivity(activity)
        }

        print("[MotionManager] Started activity tracking")
    }

    func stopActivityTracking() {
        motionActivityManager.stopActivityUpdates()
        stationaryTimer?.invalidate()
        stationaryTimer = nil
        print("[MotionManager] Stopped activity tracking")
    }

    private func processActivity(_ activity: CMMotionActivity) {
        let newActivity: ActivityType

        if activity.automotive {
            newActivity = .automotive
        } else if activity.cycling {
            newActivity = .cycling
        } else if activity.running {
            newActivity = .running
        } else if activity.walking {
            newActivity = .walking
        } else if activity.stationary {
            newActivity = .stationary
        } else {
            newActivity = .unknown
        }

        if newActivity != currentActivity {
            currentActivity = newActivity
            handleActivityChange(newActivity)
        }
    }

    private func handleActivityChange(_ activity: ActivityType) {
        if activity == .stationary {
            // Start stationary timer
            stationarySince = Date()
            stationaryTimer?.invalidate()
            stationaryTimer = Timer.scheduledTimer(
                withTimeInterval: TimeInterval(stationaryDelayMinutes * 60),
                repeats: false
            ) { [weak self] _ in
                self?.isStationary = true
                print("[MotionManager] Device has been stationary for \(self?.stationaryDelayMinutes ?? 5) minutes")
            }
        } else {
            // Cancel stationary timer and reset
            stationaryTimer?.invalidate()
            stationaryTimer = nil
            stationarySince = nil
            isStationary = false
        }

        print("[MotionManager] Activity changed to: \(activity.rawValue)")
    }

    // MARK: - Interval Multiplier

    func recommendedIntervalMultiplier(settings: TrackingSettings) -> Double {
        guard settings.motionAwareEnabled else { return 1.0 }

        switch currentActivity {
        case .stationary:
            // If stationary for a while, reduce updates significantly
            return isStationary ? 4.0 : 2.0
        case .walking:
            return 1.0 // Normal frequency
        case .running:
            return 0.5 // More frequent for running
        case .cycling:
            return 0.75 // Slightly more frequent
        case .automotive:
            return 0.5 // More frequent when driving (fast movement)
        case .unknown:
            return 1.0
        }
    }

    // MARK: - Step Counting (optional feature)

    func getStepCount(completion: @escaping (Int?) -> Void) {
        guard CMPedometer.isStepCountingAvailable() else {
            completion(nil)
            return
        }

        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)

        pedometer.queryPedometerData(from: startOfDay, to: now) { data, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("[MotionManager] Pedometer error: \(error.localizedDescription)")
                    completion(nil)
                    return
                }
                completion(data?.numberOfSteps.intValue)
            }
        }
    }
}
