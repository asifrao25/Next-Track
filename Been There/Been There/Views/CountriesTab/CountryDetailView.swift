//
//  CountryDetailView.swift
//  Next-track
//
//  Detail view for a visited country showing trips and stats
//

import SwiftUI
import MapKit

struct CountryDetailView: View {
    @ObservedObject var countriesManager = CountriesManager.shared
    @ObservedObject var cityTracker = CityTracker.shared
    let country: VisitedCountry

    @State private var showAddTripSheet = false
    @State private var editingTrip: CountryTrip?
    @Environment(\.dismiss) private var dismiss

    // Get the latest country data
    private var currentCountry: VisitedCountry {
        countriesManager.country(for: country.isoCode) ?? country
    }

    // Get cities for this country
    private var citiesInCountry: [VisitedCity] {
        cityTracker.visitedCities
            .filter { $0.countryCode?.uppercased() == country.isoCode.uppercased() }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header card
                headerCard

                // Stats card
                statsCard

                // Visit sessions (if any)
                if !currentCountry.visitSessions.isEmpty {
                    visitSessionsCard
                }

                // Cities list (if any)
                if !citiesInCountry.isEmpty {
                    citiesCard
                }

                // Manual trips
                tripsCard

                // Actions
                actionsCard
            }
            .padding()
        }
        .navigationTitle(currentCountry.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddTripSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddTripSheet) {
            AddTripSheet(countryId: currentCountry.id, countryName: currentCountry.name)
        }
        .sheet(item: $editingTrip) { trip in
            EditTripSheet(countryId: currentCountry.id, trip: trip)
        }
    }

    // MARK: - Header Card

    private var headerCard: some View {
        VStack(spacing: 16) {
            Text(currentCountry.flagEmoji)
                .font(.system(size: 80))

            Text(currentCountry.name)
                .font(.title)
                .fontWeight(.bold)

            Text(currentCountry.continent ?? "Unknown Continent")
                .font(.subheadline)
                .foregroundColor(.secondary)

            // Source badges
            HStack(spacing: 8) {
                if currentCountry.isAutoDetected {
                    Badge(text: "Auto-detected", color: .green)
                }
                if currentCountry.isManuallyAdded {
                    Badge(text: "Manually added", color: .blue)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Stats Card

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Visit Statistics")
                .font(.headline)

            // Time spent section (if tracking available)
            if currentCountry.hasTimeTracking {
                timeSpentCard
            }

            // Stats grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                PremiumStatItem(
                    title: "First Visit",
                    value: currentCountry.formattedFirstVisit,
                    icon: "calendar",
                    color: .teal
                )
                PremiumStatItem(
                    title: "Total Visits",
                    value: "\(currentCountry.totalVisitCount)",
                    icon: "airplane",
                    color: .blue
                )
                PremiumStatItem(
                    title: "Cities",
                    value: "\(currentCountry.autoDetectedCityCount)",
                    icon: "building.2",
                    color: .purple
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Time Spent Card

    private var timeSpentCard: some View {
        HStack(spacing: 16) {
            // Time icon with glow
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.orange.opacity(0.3), Color.clear],
                            center: .center,
                            startRadius: 10,
                            endRadius: 28
                        )
                    )
                    .frame(width: 56, height: 56)

                Image(systemName: "clock.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .yellow],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Time Spent")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text(currentCountry.formattedTimeSpent)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .yellow],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                if currentCountry.activeSession != nil {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("Currently visiting")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }

            Spacer()

            // Visit sessions count
            if !currentCountry.visitSessions.isEmpty {
                VStack(spacing: 2) {
                    Text("\(currentCountry.visitSessions.count)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.orange)
                    Text("sessions")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - Visit Sessions Card

    private var visitSessionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Visit Sessions", systemImage: "clock.arrow.circlepath")
                    .font(.headline)
                Spacer()
                Text("\(currentCountry.visitSessions.count)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            if currentCountry.visitSessions.isEmpty {
                Text("No visit sessions recorded yet.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(currentCountry.visitSessions.sorted(by: { $0.entryDate > $1.entryDate })) { session in
                    VisitSessionRowView(session: session)
                    if session.id != currentCountry.visitSessions.last?.id {
                        Divider()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Cities Card

    private var citiesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Cities Visited", systemImage: "building.2.fill")
                    .font(.headline)
                Spacer()
                Text("\(citiesInCountry.count)")
                    .font(.subheadline)
                    .foregroundColor(.purple)
                    .fontWeight(.semibold)
            }

            // Cities list with delete buttons
            ForEach(citiesInCountry) { city in
                HStack {
                    CountryCityRowView(city: city)

                    Button {
                        deleteCity(city)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundColor(.red.opacity(0.7))
                            .padding(8)
                            .background(Circle().fill(Color.red.opacity(0.1)))
                    }
                    .buttonStyle(.plain)
                }
                if city.id != citiesInCountry.last?.id {
                    Divider()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
    }

    private func deleteCity(_ city: VisitedCity) {
        HapticManager.shared.warning()
        cityTracker.deleteCity(city.id)
    }

    // MARK: - Trips Card

    private var tripsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Trips", systemImage: "airplane")
                    .font(.headline)
                Spacer()
                Button {
                    showAddTripSheet = true
                } label: {
                    Image(systemName: "plus.circle")
                        .foregroundColor(.teal)
                }
            }

            if currentCountry.trips.isEmpty {
                Text("No trips added yet. Add trips to record your travel history.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(currentCountry.trips) { trip in
                    TripRowView(trip: trip) {
                        editingTrip = trip
                    } onDelete: {
                        countriesManager.deleteTrip(trip.id, from: currentCountry.id)
                    }
                    if trip.id != currentCountry.trips.last?.id {
                        Divider()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Actions Card

    private var actionsCard: some View {
        VStack(spacing: 12) {
            Button(role: .destructive) {
                countriesManager.deleteCountry(currentCountry.id)
                dismiss()
            } label: {
                Label("Remove Country", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}

// MARK: - Supporting Views

struct CountryCityRowView: View {
    let city: VisitedCity

    var body: some View {
        HStack(spacing: 12) {
            // City icon
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: city.isManuallyAdded ? "hand.point.up.fill" : "location.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.purple)
            }

            // City info
            VStack(alignment: .leading, spacing: 2) {
                Text(city.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if let state = city.state {
                    Text(state)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Visit stats
            VStack(alignment: .trailing, spacing: 2) {
                if city.visitCount > 1 {
                    HStack(spacing: 2) {
                        Text("\(city.visitCount)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.purple)
                        Text("visits")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Text(city.formattedFirstVisit)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct Badge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .clipShape(Capsule())
    }
}

struct StatItem: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(.teal)
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct PremiumStatItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
            }

            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct VisitSessionRowView: View {
    let session: VisitSession

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }

    var body: some View {
        HStack(spacing: 12) {
            // Timeline indicator
            VStack(spacing: 4) {
                Circle()
                    .fill(session.isActive ? Color.green : Color.teal)
                    .frame(width: 10, height: 10)

                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 2)
            }
            .frame(width: 10)

            VStack(alignment: .leading, spacing: 6) {
                // Entry date
                HStack {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 14))
                    Text("Entered: \(dateFormatter.string(from: session.entryDate))")
                        .font(.subheadline)
                }

                // Exit date or "Currently visiting"
                if let exitDate = session.exitDate {
                    HStack {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 14))
                        Text("Left: \(dateFormatter.string(from: exitDate))")
                            .font(.subheadline)
                    }
                } else {
                    HStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("Currently visiting")
                            .font(.subheadline)
                            .foregroundColor(.green)
                    }
                }

                // Duration
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.orange)
                        .font(.system(size: 14))
                    Text("Duration: \(session.formattedDuration)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }
}

struct TripRowView: View {
    let trip: CountryTrip
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                if let name = trip.tripName, !name.isEmpty {
                    Text(name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                HStack(spacing: 12) {
                    // Date
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption)
                            .foregroundColor(.teal)
                        Text(trip.displayDate)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // Duration (if available)
                    if let duration = trip.formattedDuration {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption)
                                .foregroundColor(.orange)
                            Text(duration)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                if let notes = trip.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            Menu {
                Button {
                    onEdit()
                } label: {
                    Label("Edit", systemImage: "pencil")
                }

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Trip Sheet

struct AddTripSheet: View {
    let countryId: UUID
    let countryName: String

    @ObservedObject var countriesManager = CountriesManager.shared
    @Environment(\.dismiss) var dismiss

    @State private var tripName = ""
    @State private var notes = ""
    @State private var useExactDate = true
    @State private var visitDate = Date()
    @State private var visitYear = Calendar.current.component(.year, from: Date())
    @State private var addDuration = false
    @State private var durationDays: Int = 0
    @State private var durationHours: Int = 0

    var body: some View {
        NavigationStack {
            Form {
                Section("Trip Details") {
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
                }

                Section("Duration") {
                    Toggle("Add trip duration", isOn: $addDuration)

                    if addDuration {
                        HStack {
                            Picker("Days", selection: $durationDays) {
                                ForEach(0...365, id: \.self) { day in
                                    Text("\(day) days").tag(day)
                                }
                            }
                            .pickerStyle(.menu)

                            Picker("Hours", selection: $durationHours) {
                                ForEach(0...23, id: \.self) { hour in
                                    Text("\(hour) hrs").tag(hour)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }
                }
            }
            .navigationTitle("Add Trip to \(countryName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveTrip()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func saveTrip() {
        var duration: TimeInterval? = nil
        if addDuration && (durationDays > 0 || durationHours > 0) {
            duration = TimeInterval(durationDays * 86400 + durationHours * 3600)
        }

        let trip = CountryTrip(
            visitDate: useExactDate ? visitDate : nil,
            visitYear: useExactDate ? nil : visitYear,
            tripName: tripName.isEmpty ? nil : tripName,
            notes: notes.isEmpty ? nil : notes,
            duration: duration
        )

        countriesManager.addTrip(trip, to: countryId)
        dismiss()
    }
}

// MARK: - Edit Trip Sheet

struct EditTripSheet: View {
    let countryId: UUID
    let trip: CountryTrip

    @ObservedObject var countriesManager = CountriesManager.shared
    @Environment(\.dismiss) var dismiss

    @State private var tripName: String = ""
    @State private var notes: String = ""
    @State private var useExactDate: Bool = true
    @State private var visitDate: Date = Date()
    @State private var visitYear: Int = Calendar.current.component(.year, from: Date())
    @State private var addDuration = false
    @State private var durationDays: Int = 0
    @State private var durationHours: Int = 0

    var body: some View {
        NavigationStack {
            Form {
                Section("Trip Details") {
                    TextField("Trip name", text: $tripName)

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
                }

                Section("Duration") {
                    Toggle("Add trip duration", isOn: $addDuration)

                    if addDuration {
                        HStack {
                            Picker("Days", selection: $durationDays) {
                                ForEach(0...365, id: \.self) { day in
                                    Text("\(day) days").tag(day)
                                }
                            }
                            .pickerStyle(.menu)

                            Picker("Hours", selection: $durationHours) {
                                ForEach(0...23, id: \.self) { hour in
                                    Text("\(hour) hrs").tag(hour)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }
                }
            }
            .navigationTitle("Edit Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveTrip()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                tripName = trip.tripName ?? ""
                notes = trip.notes ?? ""
                if let date = trip.visitDate {
                    useExactDate = true
                    visitDate = date
                } else if let year = trip.visitYear {
                    useExactDate = false
                    visitYear = year
                }
                // Load existing duration
                if let duration = trip.duration {
                    addDuration = true
                    durationDays = Int(duration) / 86400
                    durationHours = (Int(duration) % 86400) / 3600
                }
            }
        }
    }

    private func saveTrip() {
        var duration: TimeInterval? = nil
        if addDuration && (durationDays > 0 || durationHours > 0) {
            duration = TimeInterval(durationDays * 86400 + durationHours * 3600)
        }

        let updatedTrip = CountryTrip(
            id: trip.id,
            visitDate: useExactDate ? visitDate : nil,
            visitYear: useExactDate ? nil : visitYear,
            tripName: tripName.isEmpty ? nil : tripName,
            notes: notes.isEmpty ? nil : notes,
            duration: duration
        )

        countriesManager.updateTrip(updatedTrip, for: countryId)
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        CountryDetailView(
            country: VisitedCountry(
                name: "France",
                isoCode: "FR",
                continent: "Europe",
                isAutoDetected: true,
                isManuallyAdded: true,
                firstVisitDate: Date(),
                trips: [
                    CountryTrip(visitDate: Date(), tripName: "Summer 2023", notes: "Amazing trip!")
                ],
                autoDetectedCityCount: 3
            )
        )
    }
}
