//
//  UKCityDetailSheet.swift
//  Next-track
//
//  Detail sheet showing city visit statistics
//

import SwiftUI

struct UKCityDetailSheet: View {
    let city: VisitedUKCity
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerView

                // Stats card
                statsCard

                // Places visited
                if !city.places.isEmpty {
                    placesSection
                }

                Spacer(minLength: 40)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(city.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 8) {
            // City icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.teal.opacity(0.2), .cyan.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: "building.2.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.teal, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            // City name
            Text(city.name)
                .font(.title)
                .fontWeight(.bold)

            // Region
            Text(city.region)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.top, 8)
    }

    // MARK: - Stats Card

    private var statsCard: some View {
        VStack(spacing: 16) {
            // Visit count
            HStack {
                Label("Total Visits", systemImage: "figure.walk")
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(city.visitCount)")
                    .font(.headline)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.teal, .cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }

            Divider()

            // First visit
            HStack {
                Label("First Visit", systemImage: "calendar.badge.plus")
                    .foregroundColor(.secondary)
                Spacer()
                Text(city.formattedFirstVisit)
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }

            Divider()

            // Last visit
            HStack {
                Label("Last Visit", systemImage: "calendar")
                    .foregroundColor(.secondary)
                Spacer()
                Text(city.formattedLastVisit)
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Places Section

    private var placesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "mappin.circle.fill")
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.teal, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text("Places Visited")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(city.places, id: \.self) { place in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.teal.opacity(0.3))
                            .frame(width: 8, height: 8)

                        Text(place)
                            .font(.subheadline)
                            .foregroundColor(.primary)

                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        UKCityDetailSheet(
            city: VisitedUKCity(
                name: "Nottingham",
                region: "East Midlands",
                latitude: 52.9548,
                longitude: -1.1581,
                radius: 8000,
                visitCount: 47,
                firstVisitDate: Date().addingTimeInterval(-86400 * 30),
                lastVisitDate: Date(),
                places: [
                    "Queen's Medical Centre",
                    "Castle Boulevard",
                    "Beeston",
                    "Attenborough Nature Reserve"
                ]
            )
        )
    }
}
