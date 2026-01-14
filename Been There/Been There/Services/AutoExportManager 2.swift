//
//  AutoExportManager.swift
//  Been There
//
//  Automatic daily backup of all app data at midnight
//

import Foundation
import BackgroundTasks
import UIKit
import UserNotifications

class AutoExportManager: ObservableObject {
    static let shared = AutoExportManager()

    // MARK: - Published Properties

    @Published var isEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Keys.isEnabled)
            if isEnabled && isTaskRegistered {
                scheduleNextExport()
            } else if !isEnabled {
                cancelScheduledExport()
            }
        }
    }

    @Published var exportFolderURL: URL? {
        didSet {
            saveExportFolderBookmark()
        }
    }

    @Published var lastExportDate: Date? {
        didSet {
            if let date = lastExportDate {
                UserDefaults.standard.set(date, forKey: Keys.lastExportDate)
            }
        }
    }

    @Published var lastExportStatus: String = ""

    // MARK: - Constants

    private enum Keys {
        static let isEnabled = "autoExportEnabled"
        static let exportFolderBookmark = "exportFolderBookmark"
        static let lastExportDate = "lastExportDate"
    }

    static let taskIdentifier = "com.beenthere.dailyexport"
    private var isTaskRegistered = false  // Track if task is registered

    // MARK: - Initialization

    private init() {
        loadSettingsWithoutScheduling()
    }

    // MARK: - Settings Persistence

    /// Load settings but don't schedule (task not registered yet)
    private func loadSettingsWithoutScheduling() {
        // Load values directly without triggering didSet
        let savedEnabled = UserDefaults.standard.bool(forKey: Keys.isEnabled)
        lastExportDate = UserDefaults.standard.object(forKey: Keys.lastExportDate) as? Date
        loadExportFolderBookmark()

        // Set isEnabled without triggering scheduling
        _isEnabled = Published(initialValue: savedEnabled)
    }

    /// Called after task registration to schedule if needed
    func onTaskRegistered() {
        isTaskRegistered = true
        if isEnabled {
            scheduleNextExport()
        }
    }

    // MARK: - Folder Selection

    private func saveExportFolderBookmark() {
        guard let url = exportFolderURL else {
            UserDefaults.standard.removeObject(forKey: Keys.exportFolderBookmark)
            return
        }

        do {
            // Create security-scoped bookmark for persistent access
            let bookmarkData = try url.bookmarkData(
                options: .minimalBookmark,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(bookmarkData, forKey: Keys.exportFolderBookmark)
            print("[AutoBackup] Saved folder bookmark: \(url.path)")
        } catch {
            print("[AutoBackup] Failed to create bookmark: \(error)")
        }
    }

    private func loadExportFolderBookmark() {
        guard let bookmarkData = UserDefaults.standard.data(forKey: Keys.exportFolderBookmark) else {
            return
        }

        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if isStale {
                // Bookmark is stale, need user to re-select folder
                print("[AutoBackup] Bookmark is stale, need re-selection")
                exportFolderURL = nil
            } else {
                exportFolderURL = url
                print("[AutoBackup] Loaded folder: \(url.path)")
            }
        } catch {
            print("[AutoBackup] Failed to resolve bookmark: \(error)")
        }
    }

    /// Set export folder from document picker result
    func setExportFolder(_ url: URL) {
        // Start accessing security-scoped resource
        guard url.startAccessingSecurityScopedResource() else {
            print("[AutoBackup] Failed to access security-scoped resource")
            return
        }

        exportFolderURL = url
        url.stopAccessingSecurityScopedResource()
    }

    // MARK: - Background Task Scheduling

    func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.taskIdentifier,
            using: nil
        ) { [weak self] task in
            guard let self = self, let processingTask = task as? BGProcessingTask else {
                print("[AutoBackup] Unexpected task type or self is nil")
                task.setTaskCompleted(success: false)
                return
            }
            self.handleBackgroundTask(processingTask)
        }
        print("[AutoBackup] Registered background task")

        // Now safe to schedule if enabled
        onTaskRegistered()
    }

    func scheduleNextExport() {
        let request = BGProcessingTaskRequest(identifier: Self.taskIdentifier)

        // Schedule for next midnight (00:00)
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let nextMidnight = calendar.startOfDay(for: tomorrow)

        request.earliestBeginDate = nextMidnight
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false

        do {
            try BGTaskScheduler.shared.submit(request)
            print("[AutoBackup] Scheduled backup for: \(nextMidnight)")
        } catch {
            print("[AutoBackup] Failed to schedule: \(error)")
        }
    }

    private func cancelScheduledExport() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.taskIdentifier)
        print("[AutoBackup] Cancelled scheduled backup")
    }

    private func handleBackgroundTask(_ task: BGProcessingTask) {
        // Schedule next export first
        scheduleNextExport()

        task.expirationHandler = {
            print("[AutoBackup] Background task expired")
        }

        // Perform full backup
        performDailyBackup { success in
            task.setTaskCompleted(success: success)
        }
    }

    // MARK: - Missed Export Recovery

    /// Check if any exports were missed and perform them when app becomes active
    /// This handles cases where iOS didn't run the scheduled background task
    func checkAndPerformMissedExport() {
        guard isEnabled else {
            print("[AutoBackup] Auto-backup is disabled, skipping missed backup check")
            return
        }

        guard exportFolderURL != nil else {
            print("[AutoBackup] No backup folder selected, skipping missed backup check")
            return
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Check if we already backed up today
        if let lastExport = lastExportDate {
            let lastExportDay = calendar.startOfDay(for: lastExport)

            // If last backup was today, we're up to date
            if lastExportDay >= today {
                print("[AutoBackup] Backup is up to date (last backup: \(lastExportDay))")
                return
            }

            // Calculate how many days were missed
            let daysMissed = calendar.dateComponents([.day], from: lastExportDay, to: today).day ?? 0
            print("[AutoBackup] Detected \(daysMissed) day(s) since last backup, performing recovery backup")
        } else {
            print("[AutoBackup] No previous backup date, performing initial backup")
        }

        // Perform a full backup now to recover
        performDailyBackup(isRecovery: true) { success in
            if success {
                self.sendRecoveryNotification()
            }
        }
    }

    /// Send notification about recovered/missed backup
    private func sendRecoveryNotification() {
        let content = UNMutableNotificationContent()
        content.title = "📦 Missed Backup Recovered"
        content.body = "Been There has completed a full backup of all your data"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "recoveredBackup-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil  // Deliver immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[AutoBackup] Failed to send recovery notification: \(error)")
            }
        }
    }

    // MARK: - Backup Logic

    /// Perform the daily full backup
    /// - Parameter isRecovery: If true, this is a recovery backup (missed scheduled backup)
    func performDailyBackup(isRecovery: Bool = false, completion: ((Bool) -> Void)? = nil) {
        guard let folderURL = exportFolderURL else {
            lastExportStatus = "No backup folder selected"
            print("[AutoBackup] No folder selected")
            completion?(false)
            return
        }

        // Start accessing security-scoped resource
        guard folderURL.startAccessingSecurityScopedResource() else {
            lastExportStatus = "Cannot access backup folder"
            print("[AutoBackup] Cannot access folder")
            completion?(false)
            return
        }
        defer { folderURL.stopAccessingSecurityScopedResource() }

        // Create full backup using FullBackupManager
        guard let backupData = FullBackupManager.shared.createFullBackup() else {
            lastExportStatus = "Failed to create backup data"
            print("[AutoBackup] Failed to create backup")
            completion?(false)
            return
        }

        // Generate filename with current date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())
        let filename = "BeenThere-DailyBackup-\(dateString).json"
        let fileURL = folderURL.appendingPathComponent(filename)

        do {
            try backupData.write(to: fileURL)
            print("[AutoBackup] Saved backup: \(filename) (\(backupData.count) bytes)")

            // Update status
            lastExportDate = Date()

            // Get summary for status message
            let summary = FullBackupManager.shared.getCurrentDataSummary()
            lastExportStatus = "Backed up \(summary.totalSessions) sessions, \(summary.totalCountries) countries, \(summary.totalCities) cities"

            // Send notification (only for scheduled backups, not recovery - recovery has its own)
            if !isRecovery {
                sendBackupNotification(summary: summary, date: dateString)
            }

            completion?(true)
        } catch {
            print("[AutoBackup] Failed to save backup: \(error)")
            lastExportStatus = "Backup failed: \(error.localizedDescription)"
            completion?(false)
        }
    }

    // MARK: - Notifications

    private func sendBackupNotification(summary: BackupSummary, date: String) {
        let content = UNMutableNotificationContent()
        content.title = "📦 Daily Backup Complete"
        content.body = "Backed up \(summary.totalSessions) sessions, \(summary.totalCountries) countries, \(summary.totalCities) cities, \(summary.totalPlaces) places"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "dailyBackup-\(date)",
            content: content,
            trigger: nil  // Deliver immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[AutoBackup] Failed to send notification: \(error)")
            }
        }
    }

    // MARK: - Manual Backup

    /// Manual backup of all data to specified folder
    func manualBackup(to folderURL: URL) -> Bool {
        guard folderURL.startAccessingSecurityScopedResource() else {
            return false
        }
        defer { folderURL.stopAccessingSecurityScopedResource() }

        guard let backupData = FullBackupManager.shared.createFullBackup() else {
            return false
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let filename = "BeenThere-ManualBackup-\(dateFormatter.string(from: Date())).json"
        let fileURL = folderURL.appendingPathComponent(filename)

        do {
            try backupData.write(to: fileURL)
            print("[AutoBackup] Manual backup saved: \(filename)")
            return true
        } catch {
            print("[AutoBackup] Failed manual backup: \(error)")
            return false
        }
    }
}
