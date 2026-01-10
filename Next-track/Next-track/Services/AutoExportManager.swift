//
//  AutoExportManager.swift
//  Next-track
//
//  Automatic daily export of tracking data to GPX files
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

    static let taskIdentifier = "com.nexttrack.dailyexport"
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
            print("[AutoExport] Saved folder bookmark: \(url.path)")
        } catch {
            print("[AutoExport] Failed to create bookmark: \(error)")
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
                print("[AutoExport] Bookmark is stale, need re-selection")
                exportFolderURL = nil
            } else {
                exportFolderURL = url
                print("[AutoExport] Loaded folder: \(url.path)")
            }
        } catch {
            print("[AutoExport] Failed to resolve bookmark: \(error)")
        }
    }

    /// Set export folder from document picker result
    func setExportFolder(_ url: URL) {
        // Start accessing security-scoped resource
        guard url.startAccessingSecurityScopedResource() else {
            print("[AutoExport] Failed to access security-scoped resource")
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
                print("[AutoExport] Unexpected task type or self is nil")
                task.setTaskCompleted(success: false)
                return
            }
            self.handleBackgroundTask(processingTask)
        }
        print("[AutoExport] Registered background task")

        // Now safe to schedule if enabled
        onTaskRegistered()
    }

    func scheduleNextExport() {
        let request = BGProcessingTaskRequest(identifier: Self.taskIdentifier)

        // Schedule for next midnight - use date arithmetic instead of component mutation
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let startOfTomorrow = calendar.startOfDay(for: tomorrow)

        // Add 5 minutes past midnight to avoid exact midnight edge cases
        guard let nextMidnight = calendar.date(byAdding: .minute, value: 5, to: startOfTomorrow) else {
            print("[AutoExport] Failed to calculate next export time")
            return
        }

        request.earliestBeginDate = nextMidnight
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false

        do {
            try BGTaskScheduler.shared.submit(request)
            print("[AutoExport] Scheduled export for: \(nextMidnight)")
        } catch {
            print("[AutoExport] Failed to schedule: \(error)")
        }
    }

    private func cancelScheduledExport() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.taskIdentifier)
        print("[AutoExport] Cancelled scheduled export")
    }

    private func handleBackgroundTask(_ task: BGProcessingTask) {
        // Schedule next export first
        scheduleNextExport()

        task.expirationHandler = {
            print("[AutoExport] Background task expired")
        }

        // Perform export
        performDailyExport { success in
            task.setTaskCompleted(success: success)
        }
    }

    // MARK: - Missed Export Recovery

    /// Check if any exports were missed and perform them when app becomes active
    /// This handles cases where iOS didn't run the scheduled background task
    func checkAndPerformMissedExport() {
        guard isEnabled else {
            print("[AutoExport] Auto-export is disabled, skipping missed export check")
            return
        }

        guard exportFolderURL != nil else {
            print("[AutoExport] No export folder selected, skipping missed export check")
            return
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Determine the last date that should have been exported
        // Yesterday's data should have been exported at midnight
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else {
            return
        }

        // Check if we already exported yesterday's data
        if let lastExport = lastExportDate {
            let lastExportDay = calendar.startOfDay(for: lastExport)

            // If last export was today or yesterday, we're up to date
            if lastExportDay >= yesterday {
                print("[AutoExport] Exports are up to date (last export: \(lastExportDay))")
                return
            }

            // Calculate how many days were missed
            let daysMissed = calendar.dateComponents([.day], from: lastExportDay, to: yesterday).day ?? 0
            print("[AutoExport] Detected \(daysMissed) missed export day(s)")

            // Export each missed day
            var exportedDays: [String] = []
            for dayOffset in 1...daysMissed {
                if let missedDate = calendar.date(byAdding: .day, value: dayOffset, to: lastExportDay) {
                    if exportDayData(for: missedDate) {
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "MMM d"
                        exportedDays.append(dateFormatter.string(from: missedDate))
                    }
                }
            }

            // Send notification about recovered exports
            if !exportedDays.isEmpty {
                sendRecoveryNotification(days: exportedDays)
            }
        } else {
            // No previous export date recorded - export yesterday if there's data
            print("[AutoExport] No previous export date, attempting to export yesterday's data")
            if exportDayData(for: yesterday) {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "MMM d"
                sendRecoveryNotification(days: [dateFormatter.string(from: yesterday)])
            }
        }
    }

    /// Export data for a specific date
    /// - Parameter date: The date to export sessions for
    /// - Returns: True if sessions were exported, false otherwise
    private func exportDayData(for date: Date) -> Bool {
        guard let folderURL = exportFolderURL else { return false }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return false }

        let historyManager = TrackingHistoryManager.shared
        let sessionsToExport = historyManager.sessions.filter { session in
            session.startTime >= startOfDay && session.startTime < endOfDay
        }

        guard !sessionsToExport.isEmpty else {
            print("[AutoExport] No sessions for \(startOfDay), skipping")
            return false
        }

        // Start accessing security-scoped resource
        guard folderURL.startAccessingSecurityScopedResource() else {
            print("[AutoExport] Cannot access folder for recovery export")
            return false
        }
        defer { folderURL.stopAccessingSecurityScopedResource() }

        // Generate GPX file
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)

        let gpxContent = exportSessionsToSingleGPX(sessionsToExport, date: dateString)
        let filename = "NextTrack-\(dateString).gpx"
        let fileURL = folderURL.appendingPathComponent(filename)

        do {
            try gpxContent.write(to: fileURL, atomically: true, encoding: .utf8)
            print("[AutoExport] Recovered export: \(filename) with \(sessionsToExport.count) session(s)")
            lastExportDate = Date()
            lastExportStatus = "Recovered \(sessionsToExport.count) session(s) to \(filename)"
            return true
        } catch {
            print("[AutoExport] Failed to export recovered data: \(error)")
            return false
        }
    }

    /// Send notification about recovered/missed exports
    private func sendRecoveryNotification(days: [String]) {
        let content = UNMutableNotificationContent()
        content.title = "📁 Missed Export Recovered"

        if days.count == 1 {
            content.body = "Exported tracking data from \(days[0]) that was missed"
        } else {
            content.body = "Exported tracking data from \(days.joined(separator: ", ")) that was missed"
        }
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "recoveredExport-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil  // Deliver immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[AutoExport] Failed to send recovery notification: \(error)")
            }
        }
    }

    // MARK: - Export Logic

    /// Perform the daily export (can be called manually or from background task)
    /// - Parameter forToday: If true, exports today's sessions (manual). If false, exports yesterday's (scheduled).
    func performDailyExport(forToday: Bool = false, completion: ((Bool) -> Void)? = nil) {
        guard let folderURL = exportFolderURL else {
            lastExportStatus = "No export folder selected"
            print("[AutoExport] No folder selected")
            completion?(false)
            return
        }

        // Get target day's sessions
        let calendar = Calendar.current
        let targetDate: Date
        let startOfDay: Date
        let endOfDay: Date

        if forToday {
            targetDate = Date()
            startOfDay = calendar.startOfDay(for: targetDate)
            endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        } else {
            // Yesterday (for scheduled midnight export)
            targetDate = calendar.date(byAdding: .day, value: -1, to: Date())!
            startOfDay = calendar.startOfDay(for: targetDate)
            endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        }

        let historyManager = TrackingHistoryManager.shared
        let sessionsToExport = historyManager.sessions.filter { session in
            session.startTime >= startOfDay && session.startTime < endOfDay
        }

        guard !sessionsToExport.isEmpty else {
            lastExportStatus = forToday ? "No sessions today" : "No sessions to export"
            lastExportDate = Date()
            print("[AutoExport] No sessions for \(forToday ? "today" : "yesterday")")
            completion?(true)
            return
        }

        // Start accessing security-scoped resource
        guard folderURL.startAccessingSecurityScopedResource() else {
            lastExportStatus = "Cannot access export folder"
            print("[AutoExport] Cannot access folder")
            completion?(false)
            return
        }
        defer { folderURL.stopAccessingSecurityScopedResource() }

        // Combine all sessions into a single GPX file for the day
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: targetDate)

        let gpxContent = exportSessionsToSingleGPX(sessionsToExport, date: dateString)
        let filename = "NextTrack-\(dateString).gpx"
        let fileURL = folderURL.appendingPathComponent(filename)

        do {
            try gpxContent.write(to: fileURL, atomically: true, encoding: .utf8)
            print("[AutoExport] Exported: \(filename) with \(sessionsToExport.count) session(s)")

            lastExportDate = Date()
            lastExportStatus = "Exported \(sessionsToExport.count) session(s) to \(filename)"
        } catch {
            print("[AutoExport] Failed to export \(filename): \(error)")
            lastExportStatus = "Export failed: \(error.localizedDescription)"
            completion?(false)
            return
        }

        let exportedCount = sessionsToExport.count

        // Send notification about export
        if exportedCount > 0 {
            sendExportNotification(count: exportedCount, date: dateString)
        }

        completion?(exportedCount > 0)
    }

    // MARK: - Notifications

    private func sendExportNotification(count: Int, date: String) {
        let content = UNMutableNotificationContent()
        content.title = "📁 Daily Export Complete"
        content.body = "Exported \(count) tracking session\(count == 1 ? "" : "s") from \(date)"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "dailyExport-\(date)",
            content: content,
            trigger: nil  // Deliver immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[AutoExport] Failed to send notification: \(error)")
            }
        }
    }

    /// Combine multiple sessions into a single GPX file
    private func exportSessionsToSingleGPX(_ sessions: [TrackingSession], date: String) -> String {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="Next Track iOS App"
             xmlns="http://www.topografix.com/GPX/1/1"
             xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
             xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">
          <metadata>
            <name>Next Track - \(date)</name>
            <desc>\(sessions.count) tracking session(s)</desc>
            <time>\(dateFormatter.string(from: Date()))</time>
          </metadata>

        """

        for session in sessions {
            gpx += "  <trk>\n"
            gpx += "    <name>\(session.name)</name>\n"
            gpx += "    <trkseg>\n"

            for location in session.locations {
                gpx += "      <trkpt lat=\"\(location.latitude)\" lon=\"\(location.longitude)\">\n"
                if let altitude = location.altitude {
                    gpx += "        <ele>\(altitude)</ele>\n"
                }
                gpx += "        <time>\(dateFormatter.string(from: location.timestamp))</time>\n"
                if let speed = location.speed {
                    gpx += "        <speed>\(speed)</speed>\n"
                }
                gpx += "      </trkpt>\n"
            }

            gpx += "    </trkseg>\n"
            gpx += "  </trk>\n"
        }

        gpx += "</gpx>"

        return gpx
    }

    /// Manual export of all data
    func exportAllData(to folderURL: URL) -> Bool {
        guard folderURL.startAccessingSecurityScopedResource() else {
            return false
        }
        defer { folderURL.stopAccessingSecurityScopedResource() }

        let historyManager = TrackingHistoryManager.shared
        let gpxContent = historyManager.exportAllSessionsToGPX()

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let filename = "NextTrack-AllData-\(dateFormatter.string(from: Date())).gpx"
        let fileURL = folderURL.appendingPathComponent(filename)

        do {
            try gpxContent.write(to: fileURL, atomically: true, encoding: .utf8)
            print("[AutoExport] Exported all data to: \(filename)")
            return true
        } catch {
            print("[AutoExport] Failed to export all data: \(error)")
            return false
        }
    }
}
