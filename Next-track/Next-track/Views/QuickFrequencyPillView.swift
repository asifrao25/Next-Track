//
//  QuickFrequencyPillView.swift
//  Next-track
//
//  Quick frequency selector pill for the Track tab
//

import SwiftUI

struct QuickFrequencyPillView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var locationManager: LocationManager

    // Filter out the custom preset - only show the 6 fixed presets
    private var availablePresets: [IntervalPreset] {
        IntervalPreset.allCases.filter { $0 != .custom }
    }

    // Short display name for the pill (without the description in parentheses)
    private var shortDisplayName: String {
        switch settingsManager.trackingSettings.intervalPreset {
        case .realtime: return "10s"
        case .high: return "30s"
        case .normal: return "1 min"
        case .batterySaver: return "5 min"
        case .extended: return "15 min"
        case .minimal: return "30 min"
        case .custom: return "Custom"
        }
    }

    var body: some View {
        Menu {
            ForEach(availablePresets, id: \.self) { preset in
                Button {
                    selectPreset(preset)
                } label: {
                    HStack {
                        Text(preset.displayName)
                        if settingsManager.trackingSettings.intervalPreset == preset {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "timer")
                    .font(.system(size: 9, weight: .medium))

                Text(shortDisplayName)
                    .font(.system(size: 10, weight: .semibold))

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 7, weight: .bold))
            }
            .foregroundColor(.white.opacity(0.8))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
        }
    }

    private func selectPreset(_ preset: IntervalPreset) {
        HapticManager.shared.buttonTap()

        // Update the setting (save happens automatically via didSet)
        settingsManager.trackingSettings.intervalPreset = preset

        // If tracking is active, apply the new interval immediately
        if locationManager.isTracking {
            locationManager.updateSettings(
                interval: preset.seconds,
                minimumAccuracy: settingsManager.trackingSettings.minimumAccuracyMeters
            )
        }
    }
}

#Preview {
    QuickFrequencyPillView()
        .environmentObject(SettingsManager.shared)
        .environmentObject(LocationManager.shared)
}
