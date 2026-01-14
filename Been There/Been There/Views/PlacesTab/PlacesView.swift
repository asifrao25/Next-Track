//
//  PlacesView.swift
//  Next-track
//
//  View for displaying detected places
//

import SwiftUI
import MapKit

struct PlacesView: View {
    @ObservedObject var placeManager = PlaceDetectionManager.shared
    @ObservedObject var historyManager = TrackingHistoryManager.shared

    @State private var selectedSort: PlaceSortOption = .recentVisit
    @State private var selectedCategory: PlaceCategory? = nil
    @State private var searchText: String = ""
    @State private var showingProcessingSheet: Bool = false

    var filteredPlaces: [DetectedPlace] {
        var places = selectedSort.sort(placeManager.detectedPlaces)

        // Filter by category
        if let category = selectedCategory {
            places = places.filter { $0.category == category }
        }

        // Filter by search
        if !searchText.isEmpty {
            places = places.filter { place in
                (place.name?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (place.streetAddress?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                place.category.rawValue.localizedCaseInsensitiveContains(searchText)
            }
        }

        return places
    }

    var body: some View {
        NavigationStack {
            Group {
                if placeManager.detectedPlaces.isEmpty && !placeManager.isProcessing {
                    PlacesEmptyStateView(onDetectPlaces: detectPlaces)
                } else {
                    PlacesListView(
                        places: filteredPlaces,
                        selectedSort: $selectedSort,
                        selectedCategory: $selectedCategory
                    )
                }
            }
            .navigationTitle("Places")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if placeManager.totalPlaces > 0 {
                        HStack(spacing: 4) {
                            Text("\(placeManager.totalPlaces)")
                                .font(.headline)
                                .foregroundColor(.orange)
                            Text("places")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if placeManager.isProcessing {
                        ProgressView()
                            .progressViewStyle(.circular)
                    } else {
                        Menu {
                            Button {
                                detectPlaces()
                            } label: {
                                Label("Detect Places", systemImage: "magnifyingglass")
                            }

                            Button(role: .destructive) {
                                placeManager.clearAllPlaces()
                            } label: {
                                Label("Clear All", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search places")
            .sheet(isPresented: $showingProcessingSheet) {
                ProcessingPlacesView(progress: placeManager.processingProgress)
                    .presentationDetents([.height(200)])
            }
            .onChange(of: placeManager.isProcessing) { _, isProcessing in
                showingProcessingSheet = isProcessing
            }
        }
    }

    private func detectPlaces() {
        Task {
            await placeManager.detectPlacesFromHistory(historyManager.sessions)
        }
    }
}

// MARK: - Empty State

struct PlacesEmptyStateView: View {
    let onDetectPlaces: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "mappin.circle")
                .font(.system(size: 60))
                .foregroundColor(.orange.opacity(0.5))

            Text("No Places Detected")
                .font(.title2)
                .fontWeight(.semibold)

            Text("We can analyze your tracking history to find places you frequently visit")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button(action: onDetectPlaces) {
                Label("Detect Places", systemImage: "magnifyingglass")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
    }
}

// MARK: - Processing Sheet

struct ProcessingPlacesView: View {
    let progress: Double

    var body: some View {
        VStack(spacing: 20) {
            Text("Detecting Places")
                .font(.headline)

            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(.orange)

            Text("\(Int(progress * 100))% complete")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text(progressMessage)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
    }

    private var progressMessage: String {
        if progress < 0.2 {
            return "Analyzing location history..."
        } else if progress < 0.4 {
            return "Clustering locations..."
        } else if progress < 0.6 {
            return "Detecting significant places..."
        } else if progress < 0.8 {
            return "Categorizing places..."
        } else {
            return "Getting place names..."
        }
    }
}

// MARK: - Places List

struct PlacesListView: View {
    let places: [DetectedPlace]
    @Binding var selectedSort: PlaceSortOption
    @Binding var selectedCategory: PlaceCategory?

    var body: some View {
        List {
            // Category filter chips
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        CategoryChip(
                            title: "All",
                            icon: "square.grid.2x2",
                            color: .orange,
                            isSelected: selectedCategory == nil,
                            action: { selectedCategory = nil }
                        )

                        ForEach(PlaceCategory.allCases.filter { $0 != .other }, id: \.self) { category in
                            CategoryChip(
                                title: category.rawValue,
                                icon: category.icon,
                                color: category.color,
                                isSelected: selectedCategory == category,
                                action: { selectedCategory = category }
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            // Sort picker
            Section {
                Picker("Sort by", selection: $selectedSort) {
                    ForEach(PlaceSortOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.menu)
            }

            // Places list
            Section {
                ForEach(places) { place in
                    PlaceRowView(place: place)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Category Chip

struct CategoryChip: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? color.opacity(0.2) : Color.gray.opacity(0.1))
            )
            .foregroundColor(isSelected ? color : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Place Row

struct PlaceRowView: View {
    let place: DetectedPlace

    var body: some View {
        HStack(spacing: 12) {
            // Category icon
            ZStack {
                Circle()
                    .fill(place.category.color.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: place.category.icon)
                    .font(.system(size: 18))
                    .foregroundColor(place.category.color)
            }

            // Place info
            VStack(alignment: .leading, spacing: 4) {
                Text(place.displayName)
                    .font(.headline)

                if let address = place.streetAddress, !address.isEmpty {
                    Text(address)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    Label("\(place.visitCount)", systemImage: "arrow.counterclockwise")
                        .font(.caption)
                        .foregroundColor(.orange)

                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(place.formattedAverageTime)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(place.formattedLastVisit)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Confidence indicator (if not confirmed)
            if !place.isConfirmed {
                VStack(spacing: 2) {
                    Image(systemName: confidenceIcon)
                        .font(.caption)
                        .foregroundColor(confidenceColor)
                    Text("\(Int(place.confidence * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var confidenceIcon: String {
        if place.confidence >= 0.8 {
            return "checkmark.circle.fill"
        } else if place.confidence >= 0.5 {
            return "questionmark.circle"
        } else {
            return "questionmark.circle"
        }
    }

    private var confidenceColor: Color {
        if place.confidence >= 0.8 {
            return .green
        } else if place.confidence >= 0.5 {
            return .orange
        } else {
            return .gray
        }
    }
}

// MARK: - Preview

#Preview {
    PlacesView()
}
