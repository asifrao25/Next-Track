//
//  UKCitiesView.swift
//  Next-track
//
//  Main container view for UK Cities tab
//

import SwiftUI

struct UKCitiesView: View {
    @StateObject var citiesManager = UKCitiesManager.shared

    @State private var selectedCity: VisitedUKCity?
    @State private var hasAutoImported: Bool = false
    @State private var showAddCitySheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                if citiesManager.visitedCities.isEmpty {
                    emptyStateView
                } else {
                    UKCitiesMapView(
                        visitedCities: citiesManager.visitedCities,
                        onCityTapped: { city in
                            selectedCity = city
                        }
                    )
                    .ignoresSafeArea(edges: .bottom)
                }
            }
            .navigationTitle("UK Cities")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showAddCitySheet = true
                        HapticManager.shared.buttonTap()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.teal, .cyan],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            let count = citiesManager.importHistoricalUKCities()
                            print("Imported \(count) cities")
                        } label: {
                            Label("Import Historical", systemImage: "clock.arrow.circlepath")
                        }

                        Button(role: .destructive) {
                            citiesManager.clearAllCities()
                        } label: {
                            Label("Clear All Cities", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.teal, .cyan],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
            }
            .sheet(item: $selectedCity) { city in
                NavigationStack {
                    UKCityDetailSheet(city: city)
                }
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showAddCitySheet) {
                AddUKCitySheet()
            }
            .onAppear {
                // Auto-import historical cities on first launch
                if !hasAutoImported {
                    hasAutoImported = true
                    let count = citiesManager.importHistoricalUKCities()
                    print("[UKCitiesView] Auto-imported \(count) UK cities")
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "building.2.fill")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.teal, .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 8) {
                Text("No UK Cities Yet")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Import your historical visits to see\nUK cities you've explored.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                let count = citiesManager.importHistoricalUKCities()
                print("Imported \(count) cities")
            } label: {
                Label("Import Historical Cities", systemImage: "clock.arrow.circlepath")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [.teal, .cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
        }
        .padding()
    }
}

// MARK: - Preview

#Preview {
    UKCitiesView()
}
