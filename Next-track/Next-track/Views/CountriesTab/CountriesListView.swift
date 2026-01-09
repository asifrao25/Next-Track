//
//  CountriesListView.swift
//  Next-track
//
//  List view of visited countries with sort and search
//

import SwiftUI

struct CountriesListView: View {
    let countries: [VisitedCountry]
    @Binding var selectedSort: CountrySortOption

    var body: some View {
        List {
            // Sort picker section
            Section {
                Picker("Sort by", selection: $selectedSort) {
                    ForEach(CountrySortOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.menu)
            }

            // Statistics summary
            Section("Summary") {
                CountryStatsSummaryView()
            }

            // Countries list
            if selectedSort == .continent {
                // Grouped by continent
                ForEach(groupedCountries, id: \.continent) { group in
                    Section(header: Text("\(group.continent) (\(group.countries.count))")) {
                        ForEach(group.countries) { country in
                            NavigationLink(destination: CountryDetailView(country: country)) {
                                CountryRowView(country: country)
                            }
                        }
                    }
                }
            } else {
                // Flat list
                Section("Countries (\(countries.count))") {
                    ForEach(countries) { country in
                        NavigationLink(destination: CountryDetailView(country: country)) {
                            CountryRowView(country: country)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var groupedCountries: [(continent: String, countries: [VisitedCountry])] {
        Dictionary(grouping: countries) { $0.continent ?? "Unknown" }
            .map { (continent: $0.key, countries: $0.value) }
            .sorted { $0.continent < $1.continent }
    }
}

// MARK: - Country Row View

struct CountryRowView: View {
    let country: VisitedCountry

    var body: some View {
        HStack(spacing: 12) {
            // Flag
            Text(country.flagEmoji)
                .font(.system(size: 32))
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(Color.teal.opacity(0.1))
                )

            // Country info
            VStack(alignment: .leading, spacing: 4) {
                Text(country.name)
                    .font(.headline)

                HStack(spacing: 4) {
                    Text(country.continent ?? "Unknown")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("•")
                        .foregroundColor(.secondary)

                    Text(country.displaySource)
                        .font(.caption)
                        .foregroundColor(country.isAutoDetected ? .green : .blue)
                }

                if country.autoDetectedCityCount > 0 {
                    Label("\(country.autoDetectedCityCount) cities", systemImage: "building.2")
                        .font(.caption)
                        .foregroundColor(.purple)
                }
            }

            Spacer()

            // First visit date
            VStack(alignment: .trailing, spacing: 2) {
                Text("First visit")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(country.formattedFirstVisit)
                    .font(.caption)
                    .foregroundColor(.teal)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Statistics Summary View

struct CountryStatsSummaryView: View {
    @ObservedObject var countriesManager = CountriesManager.shared

    var body: some View {
        VStack(spacing: 12) {
            // Main stats
            HStack(spacing: 24) {
                StatBox(
                    value: "\(countriesManager.totalCountries)",
                    label: "Countries",
                    icon: "globe.americas.fill",
                    color: .teal
                )

                StatBox(
                    value: String(format: "%.1f%%", countriesManager.percentageOfWorld),
                    label: "of World",
                    icon: "chart.pie.fill",
                    color: .cyan
                )

                StatBox(
                    value: "\(countriesManager.countByContinent().count)",
                    label: "Continents",
                    icon: "map.fill",
                    color: .purple
                )
            }

            // Continent breakdown
            if !countriesManager.countByContinent().isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text("By Continent")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    ForEach(countriesManager.countByContinent(), id: \.continent) { item in
                        HStack {
                            Text(continentEmoji(for: item.continent))
                            Text(item.continent)
                                .font(.subheadline)
                            Spacer()
                            Text("\(item.count)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.teal)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func continentEmoji(for continent: String) -> String {
        switch continent {
        case "Africa": return "🌍"
        case "Antarctica": return "🧊"
        case "Asia": return "🌏"
        case "Europe": return "🌍"
        case "North America": return "🌎"
        case "Oceania": return "🌏"
        case "South America": return "🌎"
        default: return "🌐"
        }
    }
}

struct StatBox: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)

            Text(value)
                .font(.headline)
                .fontWeight(.bold)

            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        CountriesListView(
            countries: [
                VisitedCountry(name: "United States", isoCode: "US", continent: "North America", isAutoDetected: true),
                VisitedCountry(name: "Canada", isoCode: "CA", continent: "North America", isAutoDetected: true),
                VisitedCountry(name: "France", isoCode: "FR", continent: "Europe", isManuallyAdded: true)
            ],
            selectedSort: .constant(.alphabetical)
        )
    }
}
