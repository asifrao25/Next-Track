//
//  BackgroundTaskManager.swift
//  Been There
//
//  Background task registration and handling
//

import Foundation
import BackgroundTasks
import UIKit

class BackgroundTaskManager {
    static let shared = BackgroundTaskManager()

    // Task identifiers
    private let refreshTaskIdentifier = "com.beenthere.refresh"
    private let processingTaskIdentifier = "com.beenthere.processing"

    private init() {}

    // MARK: - Registration

    func registerBackgroundTasks() {
        // Register background app refresh
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: refreshTaskIdentifier,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                print("[BackgroundTaskManager] Unexpected task type for app refresh")
                task.setTaskCompleted(success: false)
                return
            }
            self.handleAppRefresh(task: refreshTask)
        }

        // Register background processing
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: processingTaskIdentifier,
            using: nil
        ) { task in
            guard let processingTask = task as? BGProcessingTask else {
                print("[BackgroundTaskManager] Unexpected task type for processing")
                task.setTaskCompleted(success: false)
                return
            }
            self.handleBackgroundProcessing(task: processingTask)
        }

        // Register auto-export task
        AutoExportManager.shared.registerBackgroundTask()

        #if DEBUG
        print("[BackgroundTaskManager] Registered background tasks")
        #endif
    }

    // MARK: - Scheduling

    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes

        do {
            try BGTaskScheduler.shared.submit(request)
            #if DEBUG
            print("[BackgroundTaskManager] Scheduled app refresh")
            #endif
        } catch {
            #if DEBUG
            print("[BackgroundTaskManager] Failed to schedule app refresh: \(error)")
            #endif
        }
    }

    func scheduleBackgroundProcessing() {
        let request = BGProcessingTaskRequest(identifier: processingTaskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60) // 1 hour

        do {
            try BGTaskScheduler.shared.submit(request)
            print("[BackgroundTaskManager] Scheduled background processing")
        } catch {
            print("[BackgroundTaskManager] Failed to schedule background processing: \(error)")
        }
    }

    // MARK: - Task Handlers

    private func handleAppRefresh(task: BGAppRefreshTask) {
        print("[BackgroundTaskManager] Handling app refresh")

        // Schedule next refresh
        scheduleAppRefresh()

        // Send pending locations
        let queue = PendingLocationQueue.shared
        guard !queue.isEmpty else {
            task.setTaskCompleted(success: true)
            return
        }

        task.expirationHandler = {
            print("[BackgroundTaskManager] App refresh task expired")
            PhoneTrackAPI.shared.cancelCurrentRequest()
        }

        // Use completion handler instead of arbitrary delay
        PhoneTrackAPI.shared.sendPendingLocations {
            print("[BackgroundTaskManager] App refresh task completed")
            task.setTaskCompleted(success: true)
        }
    }

    private func handleBackgroundProcessing(task: BGProcessingTask) {
        print("[BackgroundTaskManager] Handling background processing")

        // Schedule next processing
        scheduleBackgroundProcessing()

        task.expirationHandler = {
            print("[BackgroundTaskManager] Background processing task expired")
            PhoneTrackAPI.shared.cancelCurrentRequest()
        }

        // Use completion handler instead of arbitrary delay
        PhoneTrackAPI.shared.sendPendingLocations {
            print("[BackgroundTaskManager] Background processing task completed")
            task.setTaskCompleted(success: true)
        }
    }

    // MARK: - App Lifecycle

    func applicationDidEnterBackground() {
        scheduleAppRefresh()
        scheduleBackgroundProcessing()
    }

    func applicationWillEnterForeground() {
        // Cancel scheduled tasks as we're now in foreground
        BGTaskScheduler.shared.cancelAllTaskRequests()
    }
}

// MARK: - Scene Delegate Helper

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    func sceneDidEnterBackground(_ scene: UIScene) {
        BackgroundTaskManager.shared.applicationDidEnterBackground()
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        BackgroundTaskManager.shared.applicationWillEnterForeground()
    }
}
