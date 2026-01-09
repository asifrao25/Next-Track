//
//  AddCountrySheet.swift
//  Next-track
//
//  Sheet for manually adding a visited country
//

import SwiftUI

struct AddCountrySheet: View {
    @ObservedObject var countriesManager = CountriesManager.shared
    @Environment(\.dismiss) var dismiss

    @State private var searchText = ""
    @State private var selectedCountry: CountryData?
    @State private var tripName = ""
    @State private var notes = ""
    @State private var useExactDate = true
    @State private var visitDate = Date()
    @State private var visitYear = Calendar.current.component(.year, from: Date())

    var filteredCountries: [CountryData] {
        let unvisited = countriesManager.getUnvisitedCountries()
        if searchText.isEmpty {
            return unvisited
        }
        return unvisited.filter { country in
            country.name.localizedCaseInsensitiveContains(searchText) ||
            country.isoCode.localizedCaseInsensitiveContains(searchText) ||
            country.continent.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if selectedCountry == nil {
                    // Country selection
                    countrySelectionView
                } else {
                    // Trip details form
                    tripDetailsForm
                }
            }
            .navigationTitle(selectedCountry == nil ? "Add Country" : "Trip Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if selectedCountry != nil {
                        Button {
                            selectedCountry = nil
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

                if selectedCountry != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Save") {
                            saveCountry()
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
        }
    }

    // MARK: - Country Selection View

    private var countrySelectionView: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search countries", text: $searchText)
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
                Text("\(countriesManager.getUnvisitedCountries().count) countries remaining")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal)

            // Country list
            List(filteredCountries, id: \.isoCode) { country in
                Button {
                    selectedCountry = country
                    HapticManager.shared.selectionChanged()
                } label: {
                    HStack {
                        Text(country.flagEmoji)
                            .font(.title2)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(country.name)
                                .font(.body)
                                .foregroundColor(.primary)
                            Text(country.continent)
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
            .listStyle(.plain)
        }
    }

    // MARK: - Trip Details Form

    private var tripDetailsForm: some View {
        Form {
            // Selected country header
            Section {
                HStack(spacing: 12) {
                    Text(selectedCountry?.flagEmoji ?? "🌍")
                        .font(.system(size: 44))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedCountry?.name ?? "Unknown")
                            .font(.headline)
                        Text(selectedCountry?.continent ?? "")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            // Trip details
            Section {
                TextField("Trip name (e.g., Summer 2023)", text: $tripName)

                Toggle("I know the exact date", isOn: $useExactDate)

                if useExactDate {
                    DatePicker("Visit date", selection: $visitDate, displayedComponents: .date)
                } else {
                    Picker("Year", selection: $visitYear) {
                        ForEach((1950...Calendar.current.component(.year, from: Date())).reversed(), id: \.self) { year in
                            Text(String(year)).tag(year)
                        }
                    }
                }

                TextField("Notes (optional)", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
            } header: {
                Text("Trip Details")
            } footer: {
                Text("All fields except the date are optional. You can add more trips later.")
            }
        }
    }

    // MARK: - Save

    private func saveCountry() {
        guard let country = selectedCountry else { return }

        let trip = CountryTrip(
            visitDate: useExactDate ? visitDate : nil,
            visitYear: useExactDate ? nil : visitYear,
            tripName: tripName.isEmpty ? nil : tripName,
            notes: notes.isEmpty ? nil : notes
        )

        countriesManager.addManualCountry(
            name: country.name,
            isoCode: country.isoCode,
            trip: trip
        )

        dismiss()
    }
}

// MARK: - Preview

#Preview {
    AddCountrySheet()
}
