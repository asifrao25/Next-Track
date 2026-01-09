//
//  AddUKCitySheet.swift
//  Next-track
//
//  Sheet for manually adding a visited UK city
//

import SwiftUI

struct AddUKCitySheet: View {
    @ObservedObject var citiesManager = UKCitiesManager.shared
    @Environment(\.dismiss) var dismiss

    @State private var searchText = ""
    @State private var selectedCity: (name: String, region: String, lat: Double, lon: Double, radius: Double)?
    @State private var useExactDate = true
    @State private var visitDate = Date()
    @State private var visitYear = Calendar.current.component(.year, from: Date())
    @State private var placesText = ""

    var filteredCities: [(name: String, region: String, lat: Double, lon: Double, radius: Double)] {
        // Use getUnvisitedAreas() to include ALL UK LADs + UKCityData cities
        let unvisited = citiesManager.getUnvisitedAreas()
        if searchText.isEmpty {
            return unvisited
        }
        return unvisited.filter { city in
            city.name.localizedCaseInsensitiveContains(searchText) ||
            city.region.localizedCaseInsensitiveContains(searchText)
        }
    }

    // Group cities by region for better organization
    var citiesByRegion: [String: [(name: String, region: String, lat: Double, lon: Double, radius: Double)]] {
        Dictionary(grouping: filteredCities) { $0.region }
    }

    var sortedRegions: [String] {
        citiesByRegion.keys.sorted()
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if selectedCity == nil {
                    // City selection
                    citySelectionView
                } else {
                    // Visit details form
                    visitDetailsForm
                }
            }
            .navigationTitle(selectedCity == nil ? "Add City" : "Visit Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if selectedCity != nil {
                        Button {
                            selectedCity = nil
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                        }
                    } else {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }

                if selectedCity != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Save") {
                            saveCity()
                        }
                        .fontWeight(.semibold)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.teal, .cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    }
                }
            }
        }
    }

    // MARK: - City Selection View

    private var citySelectionView: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search cities", text: $searchText)
                    .textFieldStyle(.plain)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(10)
            .padding()

            // Stats
            HStack {
                Image(systemName: "building.2")
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.teal, .cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                Text("\(citiesManager.getUnvisitedAreas().count) areas available")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal)

            // City list grouped by region
            List {
                ForEach(sortedRegions, id: \.self) { region in
                    Section(header: Text(region)) {
                        ForEach(citiesByRegion[region] ?? [], id: \.name) { city in
                            Button {
                                selectedCity = city
                                HapticManager.shared.selectionChanged()
                            } label: {
                                HStack {
                                    // Region icon
                                    regionIcon(for: city.region)
                                        .font(.title2)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(city.name)
                                            .font(.body)
                                            .foregroundColor(.primary)
                                        Text(city.region)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    // MARK: - Visit Details Form

    private var visitDetailsForm: some View {
        Form {
            // Selected city header
            Section {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.teal.opacity(0.2), .cyan.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 60, height: 60)

                        regionIcon(for: selectedCity?.region ?? "")
                            .font(.system(size: 28))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedCity?.name ?? "Unknown")
                            .font(.headline)
                        Text(selectedCity?.region ?? "")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            // Visit date
            Section {
                Toggle("I know the exact date", isOn: $useExactDate)
                    .tint(.teal)

                if useExactDate {
                    DatePicker("Visit date", selection: $visitDate, displayedComponents: .date)
                        .tint(.teal)
                } else {
                    Picker("Year", selection: $visitYear) {
                        ForEach((1950...Calendar.current.component(.year, from: Date())).reversed(), id: \.self) { year in
                            Text(String(year)).tag(year)
                        }
                    }
                }
            } header: {
                Text("When did you visit?")
            }

            // Places visited
            Section {
                TextField("e.g., Castle, Cathedral, Shopping Centre", text: $placesText, axis: .vertical)
                    .lineLimit(3...6)
            } header: {
                Text("Places visited (optional)")
            } footer: {
                Text("Enter place names separated by commas")
            }
        }
    }

    // MARK: - Helpers

    private func regionIcon(for region: String) -> some View {
        let iconName: String
        let colors: [Color]

        switch region.lowercased() {
        case let r where r.contains("scotland"):
            iconName = "flag.fill"
            colors = [.blue, .white]
        case let r where r.contains("wales"):
            iconName = "leaf.fill"
            colors = [.red, .green]
        case let r where r.contains("northern ireland"):
            iconName = "shamrock.fill"
            colors = [.green, .orange]
        case let r where r.contains("london"):
            iconName = "building.2.fill"
            colors = [.red, .gray]
        case let r where r.contains("jersey") || r.contains("guernsey"):
            iconName = "sun.max.fill"
            colors = [.yellow, .red]
        case let r where r.contains("isle of man"):
            iconName = "wind"
            colors = [.red, .yellow]
        default:
            iconName = "mappin.circle.fill"
            colors = [.teal, .cyan]
        }

        return Image(systemName: iconName)
            .foregroundStyle(
                LinearGradient(
                    colors: colors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    // MARK: - Save

    private func saveCity() {
        guard let city = selectedCity else { return }

        // Parse places from comma-separated text
        let places = placesText
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // Determine the visit date
        let effectiveDate: Date
        if useExactDate {
            effectiveDate = visitDate
        } else {
            var components = DateComponents()
            components.year = visitYear
            components.month = 6
            components.day = 15
            components.hour = 12
            effectiveDate = Calendar.current.date(from: components) ?? Date()
        }

        // Add the area directly (works for both UKCityData cities and LAD-only areas)
        citiesManager.addAreaDirectly(
            name: city.name,
            region: city.region,
            latitude: city.lat,
            longitude: city.lon,
            radius: city.radius,
            visitDate: effectiveDate,
            places: places
        )

        dismiss()
    }
}

// MARK: - Preview

#Preview {
    AddUKCitySheet()
}
