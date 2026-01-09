//
//  CountriesView.swift
//  Next-track
//
//  Main container view for visited countries with globe/list toggle
//

import SwiftUI

struct CountriesView: View {
    @ObservedObject var countriesManager = CountriesManager.shared

    @State private var showMapView: Bool = true  // Default to globe view
    @State private var searchText: String = ""
    @State private var selectedSort: CountrySortOption = .recentVisit
    @State private var showAddSheet: Bool = false

    var filteredCountries: [VisitedCountry] {
        var countries = selectedSort.sort(countriesManager.visitedCountries)
        if !searchText.isEmpty {
            countries = countries.filter { country in
                country.name.localizedCaseInsensitiveContains(searchText) ||
                country.isoCode.localizedCaseInsensitiveContains(searchText) ||
                (country.continent?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        return countries
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if countriesManager.visitedCountries.isEmpty && !countriesManager.isSyncing {
                    CountriesEmptyStateView(onAddTapped: { showAddSheet = true })
                } else if showMapView {
                    CountriesMapView(
                        visitedCountries: filteredCountries,
                        geoJSON: countriesManager.countryGeoJSON,
                        onCountryTapped: { _ in }
                    )
                    .ignoresSafeArea(edges: .bottom)
                } else {
                    CountriesListView(
                        countries: filteredCountries,
                        selectedSort: $selectedSort
                    )
                }

                // Loading overlay
                if countriesManager.isSyncing {
                    VStack {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Syncing countries...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                }
            }
            .navigationTitle("Countries")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    countryStats
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        // Add button
                        Button {
                            showAddSheet = true
                        } label: {
                            Image(systemName: "plus")
                                .foregroundColor(.teal)
                        }

                        // Toggle globe/list
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                showMapView.toggle()
                            }
                            HapticManager.shared.buttonTap()
                        } label: {
                            Image(systemName: showMapView ? "list.bullet" : "globe.americas.fill")
                                .foregroundColor(.teal)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search countries")
            .sheet(isPresented: $showAddSheet) {
                AddCountrySheet()
            }
        }
    }

    private var countryStats: some View {
        HStack(spacing: 4) {
            Text("\(countriesManager.totalCountries)")
                .font(.headline)
                .foregroundColor(.teal)
            Text("countries")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("(\(String(format: "%.0f", countriesManager.percentageOfWorld))%)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Empty State

struct CountriesEmptyStateView: View {
    let onAddTapped: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "globe.americas.fill")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.teal, .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 8) {
                Text("No Countries Yet")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Start tracking to auto-detect countries,\nor add countries you've visited manually.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            VStack(spacing: 12) {
                Button {
                    onAddTapped()
                } label: {
                    Label("Add Country", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.teal)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 40)

                Button {
                    CountriesManager.shared.forceSyncFromCities()
                } label: {
                    Label("Sync from Tracked Cities", systemImage: "arrow.triangle.2.circlepath")
                        .font(.subheadline)
                        .foregroundColor(.teal)
                }
            }
        }
        .padding()
    }
}

// MARK: - Preview

#Preview {
    CountriesView()
}
