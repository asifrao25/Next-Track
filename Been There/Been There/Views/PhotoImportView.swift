//
//  PhotoImportView.swift
//  Been There
//
//  UI for importing location data from photo library
//

import SwiftUI
import Photos

// Import type options
enum ImportType: String, CaseIterable {
    case cities = "Cities"
    case countries = "Countries"
    case both = "Both"

    var description: String {
        switch self {
        case .cities: return "Add discovered cities to your visited places"
        case .countries: return "Add discovered countries to your travel map"
        case .both: return "Import both cities and countries"
        }
    }

    var icon: String {
        switch self {
        case .cities: return "building.2.fill"
        case .countries: return "globe.americas.fill"
        case .both: return "map.fill"
        }
    }
}

struct PhotoImportView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var importManager = PhotoImportManager.shared

    @State private var showingResults = false
    @State private var showingImportSuccess = false
    @State private var importedStats: PhotoImportStats?

    // Import type selection (user must select)
    @State private var importCities = false
    @State private var importCountries = false

    // ETA tracking
    @State private var scanStartTime: Date?
    @State private var estimatedTimeRemaining: TimeInterval = 0

    // Animation states for scanning view
    @State private var pulseAnimation = false
    @State private var rotationAngle: Double = 0
    @State private var shimmerPosition: CGFloat = -60

    var body: some View {
        NavigationStack {
            Group {
                if !importManager.canAccessPhotos {
                    permissionRequestView
                } else if importManager.isScanning {
                    scanningProgressView
                } else if showingResults || !importManager.discoveredLocations.isEmpty {
                    resultsView
                } else {
                    startScanView
                }
            }
            .navigationTitle("Import from Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        if importManager.isScanning {
                            importManager.cancelScan()
                        }
                        dismiss()
                    }
                }
            }
            .alert("Import Complete", isPresented: $showingImportSuccess) {
                Button("Done") {
                    dismiss()
                }
            } message: {
                if let stats = importedStats {
                    Text("Added \(stats.newCitiesImported) new cities and updated \(stats.existingCitiesUpdated) existing ones across \(stats.uniqueCountriesFound) countries.")
                }
            }
        }
    }

    // MARK: - Permission Request View

    private var permissionRequestView: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.2), .purple.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)

                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 50))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            // Title & Description
            VStack(spacing: 12) {
                Text("Photo Library Access")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Been There can extract location data from your photos to discover places you've visited. Your photos stay on your device - only location metadata is used.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // Privacy Note
            HStack(spacing: 12) {
                Image(systemName: "lock.shield.fill")
                    .font(.title3)
                    .foregroundColor(.green)

                Text("Photos are processed locally. Nothing is uploaded or shared.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.green.opacity(0.1))
            )
            .padding(.horizontal)

            Spacer()

            // Grant Access Button
            Button {
                HapticManager.shared.medium()
                Task {
                    await importManager.requestPhotoLibraryAccess()
                }
            } label: {
                HStack {
                    Image(systemName: "photo.badge.checkmark")
                    Text("Grant Photo Access")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(14)
            }
            .padding(.horizontal)

            // Settings Link (if denied)
            if importManager.authorizationStatus == .denied {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("Open Settings to Enable")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                .padding(.bottom)
            }
        }
        .padding()
    }

    // MARK: - Start Scan View

    private var startScanView: some View {
        VStack(spacing: 20) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.orange.opacity(0.2), .pink.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: "location.magnifyingglass")
                    .font(.system(size: 44))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            // Title & Description
            VStack(spacing: 8) {
                Text("Discover Your Travels")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Scan your photo library to find geotagged photos and automatically add locations.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // Import Type Selection
            VStack(spacing: 12) {
                Text("What to import")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                // Cities toggle
                Button {
                    HapticManager.shared.light()
                    importCities.toggle()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: importCities ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                            .foregroundColor(importCities ? .orange : .gray)

                        Image(systemName: "building.2.fill")
                            .font(.title3)
                            .foregroundColor(.orange)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Cities")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            Text("Add discovered cities to your visited places")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(importCities ? Color.orange.opacity(0.1) : Color(UIColor.secondarySystemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(importCities ? Color.orange.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal)

                // Countries toggle
                Button {
                    HapticManager.shared.light()
                    importCountries.toggle()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: importCountries ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                            .foregroundColor(importCountries ? .teal : .gray)

                        Image(systemName: "globe.americas.fill")
                            .font(.title3)
                            .foregroundColor(.teal)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Countries")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            Text("Add discovered countries to your travel map")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(importCountries ? Color.teal.opacity(0.1) : Color(UIColor.secondarySystemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(importCountries ? Color.teal.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
            }

            // Limited Access Warning
            if importManager.isLimitedAccess {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title3)
                        .foregroundColor(.orange)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Limited Access")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("Only selected photos will be scanned.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.orange.opacity(0.1))
                )
                .padding(.horizontal)
                .onTapGesture {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }

            Spacer()

            // Start Scan Button
            Button {
                HapticManager.shared.medium()
                scanStartTime = Date()
                Task {
                    await importManager.scanPhotoLibrary()
                    showingResults = true
                }
            } label: {
                HStack {
                    Image(systemName: "magnifyingglass")
                    Text("Scan Photo Library")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: (importCities || importCountries) ? [.orange, .pink] : [.gray, .gray],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(14)
            }
            .disabled(!importCities && !importCountries)
            .padding(.horizontal)
            .padding(.bottom)

            // Warning if nothing selected
            if !importCities && !importCountries {
                Text("Select at least one import type")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.bottom)
            }
        }
        .padding()
    }

    // MARK: - ETA Helper

    private var formattedETA: String {
        guard let startTime = scanStartTime,
              importManager.scanProgress > 0.05 else {
            return "Calculating..."
        }

        let elapsed = Date().timeIntervalSince(startTime)
        let progress = importManager.scanProgress

        // Estimate total time based on current progress
        let estimatedTotal = elapsed / progress
        let remaining = estimatedTotal - elapsed

        if remaining < 60 {
            return "< 1 min remaining"
        } else if remaining < 3600 {
            let minutes = Int(remaining / 60)
            return "~\(minutes) min remaining"
        } else {
            let hours = Int(remaining / 3600)
            let minutes = Int((remaining.truncatingRemainder(dividingBy: 3600)) / 60)
            return "~\(hours)h \(minutes)m remaining"
        }
    }

    // MARK: - Scanning Progress View

    private var scanningProgressView: some View {
        VStack(spacing: 0) {
            Spacer()

            // Main Progress Container
            VStack(spacing: 28) {
                // Animated Photo Scanner Icon
                ZStack {
                    // Outer pulsing rings
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [.orange.opacity(0.4), .pink.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                            .frame(width: 140 + CGFloat(index * 30), height: 140 + CGFloat(index * 30))
                            .scaleEffect(pulseAnimation ? 1.1 : 0.9)
                            .opacity(pulseAnimation ? 0.3 : 0.6)
                            .animation(
                                .easeInOut(duration: 1.2)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.2),
                                value: pulseAnimation
                            )
                    }

                    // Progress circle background
                    Circle()
                        .stroke(Color.gray.opacity(0.15), lineWidth: 10)
                        .frame(width: 130, height: 130)

                    // Progress circle
                    Circle()
                        .trim(from: 0, to: importManager.scanProgress)
                        .stroke(
                            LinearGradient(
                                colors: [.orange, .pink, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .frame(width: 130, height: 130)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: importManager.scanProgress)

                    // Inner circle with brain image
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.orange.opacity(0.1), .pink.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)

                        // Brain scanning image with pulse animation
                        Image("ScanningBrain")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 70, height: 70)
                            .scaleEffect(pulseAnimation ? 1.05 : 0.95)
                            .animation(
                                .easeInOut(duration: 1.0)
                                .repeatForever(autoreverses: true),
                                value: pulseAnimation
                            )
                    }

                    // Rotating scanner line
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.orange, .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 60, height: 3)
                        .offset(x: 30)
                        .rotationEffect(.degrees(rotationAngle))
                        .animation(
                            .linear(duration: 2)
                            .repeatForever(autoreverses: false),
                            value: rotationAngle
                        )
                }
                .onAppear {
                    pulseAnimation = true
                    rotationAngle = 360
                    startShimmerAnimation()
                }

                // Percentage display
                VStack(spacing: 4) {
                    Text("\(Int(importManager.scanProgress * 100))%")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.orange, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    Text("Scanning your memories...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // Horizontal Progress Bar
                VStack(spacing: 8) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background track
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 12)

                            // Progress fill
                            RoundedRectangle(cornerRadius: 6)
                                .fill(
                                    LinearGradient(
                                        colors: [.orange, .pink, .purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * importManager.scanProgress, height: 12)
                                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: importManager.scanProgress)

                            // Shimmer effect
                            if importManager.scanProgress > 0 && importManager.scanProgress < 1 {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(
                                        LinearGradient(
                                            colors: [.clear, .white.opacity(0.4), .clear],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: 60, height: 12)
                                    .offset(x: shimmerOffset(for: geometry.size.width))
                                    .mask(
                                        RoundedRectangle(cornerRadius: 6)
                                            .frame(width: geometry.size.width * importManager.scanProgress, height: 12)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    )
                            }
                        }
                    }
                    .frame(height: 12)
                }
                .padding(.horizontal, 40)

                // Status message with animation
                VStack(spacing: 6) {
                    Text(importManager.scanStatusMessage)
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .animation(.easeInOut, value: importManager.scanStatusMessage)

                    // ETA Display
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)
                        Text(formattedETA)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.orange.opacity(0.1))
                    )
                }
                .padding(.horizontal, 32)
            }

            Spacer()

            // Live Stats Cards
            HStack(spacing: 16) {
                // Photos Scanned Card
                StatCardView(
                    icon: "photo.stack.fill",
                    value: "\(importManager.importStats.totalPhotosScanned)",
                    label: "Photos Scanned",
                    gradient: [.blue, .cyan]
                )

                // Locations Found Card
                StatCardView(
                    icon: "mappin.circle.fill",
                    value: "\(importManager.discoveredLocations.count)",
                    label: "Locations Found",
                    gradient: [.orange, .pink]
                )
            }
            .padding(.horizontal)

            Spacer()
                .frame(height: 24)

            // Cancel Button
            Button {
                HapticManager.shared.light()
                importManager.cancelScan()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                    Text("Cancel Scan")
                }
                .font(.headline)
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.red.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .padding()
    }

    // MARK: - Results View

    private var resultsView: some View {
        VStack(spacing: 0) {
            // Summary Header
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("\(importManager.discoveredLocations.count) Locations Found")
                            .font(.headline)
                        Text("From \(importManager.importStats.photosWithLocation) geotagged photos")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Select All / None
                    Menu {
                        Button("Select All") {
                            importManager.selectAll()
                        }
                        Button("Deselect All") {
                            importManager.deselectAll()
                        }
                    } label: {
                        Image(systemName: "checklist")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal)
                .padding(.top)

                // Selection Summary
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("\(importManager.selectedCount) selected")
                        .font(.subheadline)
                    Text("(\(importManager.totalPhotoCountSelected) photos)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .background(Color(UIColor.secondarySystemGroupedBackground))

            // Location List
            List {
                ForEach(groupedByCountry.keys.sorted(), id: \.self) { country in
                    Section(header: countryHeader(for: country)) {
                        ForEach(groupedByCountry[country] ?? []) { location in
                            locationRow(location)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)

            // Import Button
            VStack(spacing: 8) {
                Button {
                    HapticManager.shared.medium()
                    Task {
                        let stats = await importManager.importSelectedLocations()
                        importedStats = stats
                        showingImportSuccess = true
                    }
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("Import \(importManager.selectedCount) Locations")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: importManager.selectedCount > 0 ? [.green, .teal] : [.gray, .gray],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(14)
                }
                .disabled(importManager.selectedCount == 0)
                .padding(.horizontal)

                // Rescan option
                Button {
                    HapticManager.shared.light()
                    Task {
                        await importManager.scanPhotoLibrary()
                    }
                } label: {
                    Text("Scan Again")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                .padding(.bottom)
            }
            .padding(.top, 8)
            .background(Color(UIColor.secondarySystemGroupedBackground))
        }
    }

    // MARK: - Helpers

    private var groupedByCountry: [String: [PhotoLocationResult]] {
        Dictionary(grouping: importManager.discoveredLocations) { $0.country }
    }

    private func countryHeader(for country: String) -> some View {
        let locations = groupedByCountry[country] ?? []
        let totalPhotos = locations.reduce(0) { $0 + $1.photoCount }
        let countryCode = locations.first?.countryCode ?? "XX"
        let flag = flagEmoji(for: countryCode)

        return HStack {
            Text("\(flag) \(country)")
            Spacer()
            Text("\(locations.count) cities, \(totalPhotos) photos")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func locationRow(_ location: PhotoLocationResult) -> some View {
        HStack {
            // Selection Toggle
            Button {
                HapticManager.shared.light()
                importManager.toggleSelection(for: location.id)
            } label: {
                Image(systemName: location.isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(location.isSelected ? .green : .gray)
            }
            .buttonStyle(.plain)

            // Location Info
            VStack(alignment: .leading, spacing: 4) {
                Text(location.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 8) {
                    Label("\(location.photoCount)", systemImage: "photo")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(location.dateRangeDisplay)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            HapticManager.shared.light()
            importManager.toggleSelection(for: location.id)
        }
    }

    private func flagEmoji(for countryCode: String) -> String {
        let base: UInt32 = 127397
        var emoji = ""
        for scalar in countryCode.uppercased().unicodeScalars {
            if let flag = UnicodeScalar(base + scalar.value) {
                emoji.append(String(flag))
            }
        }
        return emoji.isEmpty ? "" : emoji
    }

    // MARK: - Shimmer Animation Helpers

    private func shimmerOffset(for width: CGFloat) -> CGFloat {
        let progressWidth = width * importManager.scanProgress
        let shimmerRange = progressWidth + 60
        let normalizedPosition = (shimmerPosition + 60) / 120 // 0 to 1
        return -60 + (normalizedPosition * shimmerRange)
    }

    private func startShimmerAnimation() {
        withAnimation(
            .linear(duration: 1.5)
            .repeatForever(autoreverses: false)
        ) {
            shimmerPosition = 60
        }
    }
}

// MARK: - Stat Card View

struct StatCardView: View {
    let icon: String
    let value: String
    let label: String
    let gradient: [Color]

    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 8) {
            // Icon with gradient
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: gradient.map { $0.opacity(0.15) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(
                        LinearGradient(
                            colors: gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                    .animation(
                        .easeInOut(duration: 0.8)
                        .repeatForever(autoreverses: true),
                        value: isAnimating
                    )
            }

            // Value
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.3), value: value)

            // Label
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: gradient.map { $0.opacity(0.3) },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Preview

#Preview {
    PhotoImportView()
}
