//
//  VisitedCity.swift
//  Next-track
//
//  Model for tracking visited cities
//

import Foundation
import CoreLocation

struct VisitedCity: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String                    // "San Francisco"
    var state: String?                  // "California" or "CA"
    var country: String                 // "United States"
    var countryCode: String?            // "US"

    // Visit stats
    var firstVisitDate: Date
    var lastVisitDate: Date
    var visitCount: Int                 // Number of separate visits (sessions)
    var totalPointsRecorded: Int        // Total location points in this city

    // Representative coordinate (city center or first visit location)
    var latitude: Double
    var longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    // Display helpers
    var displayName: String {
        if let state = state {
            return "\(name), \(state)"
        }
        return "\(name), \(country)"
    }

    var shortDisplayName: String {
        if let state = state {
            // Abbreviate state if possible
            let stateAbbrev = stateAbbreviation(for: state) ?? state
            return "\(name), \(stateAbbrev)"
        }
        return "\(name), \(countryCode ?? country)"
    }

    /// Get country flag emoji from country code
    var flagEmoji: String {
        guard let countryCode = countryCode else { return "🌍" }
        let base: UInt32 = 127397
        var emoji = ""
        for scalar in countryCode.uppercased().unicodeScalars {
            if let flag = UnicodeScalar(base + scalar.value) {
                emoji.append(String(flag))
            }
        }
        return emoji.isEmpty ? "🌍" : emoji
    }

    /// Formatted first visit date
    var formattedFirstVisit: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: firstVisitDate)
    }

    /// Formatted last visit date
    var formattedLastVisit: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: lastVisitDate, relativeTo: Date())
    }

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        name: String,
        state: String?,
        country: String,
        countryCode: String?,
        firstVisitDate: Date = Date(),
        lastVisitDate: Date = Date(),
        visitCount: Int = 1,
        totalPointsRecorded: Int = 1,
        latitude: Double,
        longitude: Double
    ) {
        self.id = id
        self.name = name
        self.state = state
        self.country = country
        self.countryCode = countryCode
        self.firstVisitDate = firstVisitDate
        self.lastVisitDate = lastVisitDate
        self.visitCount = visitCount
        self.totalPointsRecorded = totalPointsRecorded
        self.latitude = latitude
        self.longitude = longitude
    }

    // MARK: - Equatable

    static func == (lhs: VisitedCity, rhs: VisitedCity) -> Bool {
        lhs.id == rhs.id
    }

    // MARK: - Helpers

    private func stateAbbreviation(for state: String) -> String? {
        let stateAbbreviations: [String: String] = [
            "Alabama": "AL", "Alaska": "AK", "Arizona": "AZ", "Arkansas": "AR",
            "California": "CA", "Colorado": "CO", "Connecticut": "CT", "Delaware": "DE",
            "Florida": "FL", "Georgia": "GA", "Hawaii": "HI", "Idaho": "ID",
            "Illinois": "IL", "Indiana": "IN", "Iowa": "IA", "Kansas": "KS",
            "Kentucky": "KY", "Louisiana": "LA", "Maine": "ME", "Maryland": "MD",
            "Massachusetts": "MA", "Michigan": "MI", "Minnesota": "MN", "Mississippi": "MS",
            "Missouri": "MO", "Montana": "MT", "Nebraska": "NE", "Nevada": "NV",
            "New Hampshire": "NH", "New Jersey": "NJ", "New Mexico": "NM", "New York": "NY",
            "North Carolina": "NC", "North Dakota": "ND", "Ohio": "OH", "Oklahoma": "OK",
            "Oregon": "OR", "Pennsylvania": "PA", "Rhode Island": "RI", "South Carolina": "SC",
            "South Dakota": "SD", "Tennessee": "TN", "Texas": "TX", "Utah": "UT",
            "Vermont": "VT", "Virginia": "VA", "Washington": "WA", "West Virginia": "WV",
            "Wisconsin": "WI", "Wyoming": "WY", "District of Columbia": "DC"
        ]
        return stateAbbreviations[state]
    }
}

// MARK: - Sort Options

enum CitySortOption: String, CaseIterable {
    case recentVisit = "Most Recent"
    case mostVisits = "Most Visits"
    case firstDiscovered = "First Discovered"
    case alphabetical = "A-Z"

    func sort(_ cities: [VisitedCity]) -> [VisitedCity] {
        switch self {
        case .recentVisit:
            return cities.sorted { $0.lastVisitDate > $1.lastVisitDate }
        case .mostVisits:
            return cities.sorted { $0.visitCount > $1.visitCount }
        case .firstDiscovered:
            return cities.sorted { $0.firstVisitDate < $1.firstVisitDate }
        case .alphabetical:
            return cities.sorted { $0.name < $1.name }
        }
    }
}
