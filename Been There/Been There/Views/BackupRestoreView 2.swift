//
//  BackupRestoreView.swift
//  Next-track
//
//  Dedicated view for backup and restore functionality
//

import SwiftUI
import UniformTypeIdentifiers

struct BackupRestoreView: View {
    @Environment(\.dismiss) private var dismiss

    @StateObject private var backupManager = FullBackupManager.shared
    @StateObject private var autoBackupManager = AutoExportManager.shared

    @State private var backupFileURL: IdentifiableURL?
    @State private var showRestorePicker = false
    @State private var showRestoreConfirmation = false
    @State private var pendingRestoreURL: URL?
    @State private var restoreResult: RestoreResult?
    @State private var showRestoreResult = false
    @State private var showFolderPicker = false

    var body: some View {
        List {
            // Auto Backup Section
            Section {
                Toggle(isOn: $autoBackupManager.isEnabled) {
                    Label("Daily Auto Backup", systemImage: "clock.badge.checkmark")
                }
                .onChange(of: autoBackupManager.isEnabled) { _, _ in
                    HapticManager.shared.light()
                }

                if autoBackupManager.isEnabled {
                    Button {
                        showFolderPicker = true
                        HapticManager.shared.light()
                    } label: {
                        HStack {
                            Text("Backup Folder")
                            Spacer()
                            if let folderURL = autoBackupManager.exportFolderURL {
                                Text(folderURL.lastPathComponent)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            } else {
                                Text("Not Set")
                                    .foregroundColor(.orange)
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)

                    if let lastBackup = autoBackupManager.lastExportDate {
                        HStack {
                            Label("Last Backup", systemImage: "clock")
                            Spacer()
                            Text(lastBackup, format: .dateTime.month().day().year().hour().minute())
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    if autoBackupManager.exportFolderURL != nil {
                        Button {
                            HapticManager.shared.medium()
                            autoBackupManager.performDailyBackup { success in
                                if success { HapticManager.shared.success() }
                            }
                        } label: {
                            Label("Backup Now", systemImage: "arrow.clockwise")
                        }
                    }
                }
            } header: {
                Label("Automatic Backup", systemImage: "clock.badge.checkmark")
            } footer: {
                Text("Daily backup saves a full copy at midnight to your chosen folder.")
            }

            // Data Summary Section
            Section {
                let summary = backupManager.getCurrentDataSummary()
                VStack(alignment: .leading, spacing: 12) {
                    Text("Current Data")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    HStack(spacing: 12) {
                        DataSummaryItem(value: "\(summary.totalSessions)", label: "Sessions")
                        DataSummaryItem(value: "\(summary.totalCountries)", label: "Countries")
                        DataSummaryItem(value: "\(summary.totalCities)", label: "Cities")
                    }

                    HStack(spacing: 12) {
                        DataSummaryItem(value: "\(summary.totalPlaces)", label: "Places")
                        DataSummaryItem(value: "\(summary.totalUKCities)", label: "UK Areas")
                        DataSummaryItem(value: "\(summary.totalGeofences)", label: "Geofences")
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Label("Data Summary", systemImage: "chart.bar.fill")
            }

            // Export Section
            Section {
                Button {
                    HapticManager.shared.medium()
                    if let url = backupManager.saveBackupFile() {
                        backupFileURL = IdentifiableURL(url: url)
                        HapticManager.shared.success()
                    }
                } label: {
                    HStack {
                        Label("Export Full Backup", systemImage: "square.and.arrow.up")
                        Spacer()
                        if backupManager.isExporting {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Image(systemName: "doc.zipper")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .disabled(backupManager.isExporting)
            } header: {
                Label("Export", systemImage: "square.and.arrow.up")
            } footer: {
                Text("Export creates a shareable backup file you can restore on any device.")
            }

            // Restore Section
            Section {
                Button {
                    showRestorePicker = true
                    HapticManager.shared.medium()
                } label: {
                    HStack {
                        Spacer()
                        if backupManager.isImporting {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                            Text("Restoring...")
                        } else {
                            Image(systemName: "arrow.down.doc.fill")
                            Text("Restore from Backup")
                        }
                        Spacer()
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .disabled(backupManager.isImporting)
                .opacity(backupManager.isImporting ? 0.6 : 1)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            } header: {
                Label("Restore", systemImage: "arrow.down.doc.fill")
            } footer: {
                Text("Restore will merge or replace your data from a backup file.")
            }

            // Bottom spacer for tab bar
            Section {
                Color.clear
                    .frame(height: 60)
                    .listRowBackground(Color.clear)
            }
            .listRowInsets(EdgeInsets())
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Backup & Restore")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $backupFileURL) { item in
            ShareSheet(activityItems: [item.url])
        }
        .sheet(isPresented: $showRestorePicker) {
            RestoreFilePickerView { result in
                handleRestoreFileSelection(result)
                showRestorePicker = false
            }
        }
        .fileImporter(
            isPresented: $showFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    autoBackupManager.setExportFolder(url)
                }
            case .failure(let error):
                print("[BackupRestore] Failed to select folder: \(error)")
            }
        }
        .alert("Restore Backup?", isPresented: $showRestoreConfirmation) {
            Button("Cancel", role: .cancel) {
                pendingRestoreURL = nil
            }
            Button("Merge") {
                performRestore(mode: .merge)
            }
            Button("Replace All", role: .destructive) {
                performRestore(mode: .replace)
            }
        } message: {
            Text("Choose how to restore:\n\n• Merge: Add new items, keep existing data\n• Replace: Overwrite all data with backup")
        }
        .alert("Restore Complete", isPresented: $showRestoreResult) {
            Button("OK", role: .cancel) { }
        } message: {
            if let result = restoreResult {
                Text("Restored \(result.totalItemsRestored) items:\n• \(result.sessionsRestored) sessions\n• \(result.countriesRestored) countries\n• \(result.citiesRestored) cities\n• \(result.placesRestored) places\n• \(result.ukCitiesRestored) UK areas\n• \(result.geofencesRestored) geofences")
            } else {
                Text("Restore completed")
            }
        }
    }

    // MARK: - Helpers

    private func handleRestoreFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let hasAccess = url.startAccessingSecurityScopedResource()
            if !hasAccess {
                print("[BackupRestore] Attempting without security scope")
            }
            pendingRestoreURL = url
            showRestoreConfirmation = true
        case .failure(let error):
            print("[BackupRestore] File selection failed: \(error)")
            backupManager.error = error.localizedDescription
        }
    }

    private func performRestore(mode: MergeMode) {
        guard let url = pendingRestoreURL else { return }

        defer {
            url.stopAccessingSecurityScopedResource()
            pendingRestoreURL = nil
        }

        do {
            let data = try Data(contentsOf: url)
            restoreResult = backupManager.restoreFromBackup(data, mergeMode: mode)
            showRestoreResult = true
            HapticManager.shared.success()
        } catch {
            backupManager.error = "Failed to read backup file: \(error.localizedDescription)"
        }
    }
}

#Preview {
    NavigationStack {
        BackupRestoreView()
    }
}
