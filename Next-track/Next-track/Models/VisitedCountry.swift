//
//  VisitedCountry.swift
//  Next-track
//
//  Data models for visited countries and trips
//

import Foundation
import CoreLocation

// MARK: - Visited Country Model

struct VisitedCountry: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String                    // "United States"
    var isoCode: String                 // "US" (ISO 3166-1 alpha-2)
    var continent: String?              // "North America"

    // Source tracking
    var isAutoDetected: Bool            // From city tracking
    var isManuallyAdded: Bool           // User added manually

    // Visit details
    var firstVisitDate: Date?
    var lastVisitDate: Date?
    var trips: [CountryTrip]            // Manual trip entries

    // Auto-detected cities in this country
    var autoDetectedCityCount: Int

    // Time tracking
    var totalTimeSpent: TimeInterval    // Total seconds spent in country
    var visitSessions: [VisitSession]   // Individual visit periods

    // Timestamps
    var createdAt: Date
    var updatedAt: Date

    // MARK: - Codable (with defaults for new properties)

    enum CodingKeys: String, CodingKey {
        case id, name, isoCode, continent
        case isAutoDetected, isManuallyAdded
        case firstVisitDate, lastVisitDate, trips
        case autoDetectedCityCount
        case totalTimeSpent, visitSessions
        case createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        isoCode = try container.decode(String.self, forKey: .isoCode)
        continent = try container.decodeIfPresent(String.self, forKey: .continent)

        isAutoDetected = try container.decodeIfPresent(Bool.self, forKey: .isAutoDetected) ?? false
        isManuallyAdded = try container.decodeIfPresent(Bool.self, forKey: .isManuallyAdded) ?? false

        firstVisitDate = try container.decodeIfPresent(Date.self, forKey: .firstVisitDate)
        lastVisitDate = try container.decodeIfPresent(Date.self, forKey: .lastVisitDate)
        trips = try container.decodeIfPresent([CountryTrip].self, forKey: .trips) ?? []

        autoDetectedCityCount = try container.decodeIfPresent(Int.self, forKey: .autoDetectedCityCount) ?? 0

        // New properties with defaults
        totalTimeSpent = try container.decodeIfPresent(TimeInterval.self, forKey: .totalTimeSpent) ?? 0
        visitSessions = try container.decodeIfPresent([VisitSession].self, forKey: .visitSessions) ?? []

        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }

    // MARK: - Computed Properties

    var flagEmoji: String {
        let base: UInt32 = 127397
        var emoji = ""
        for scalar in isoCode.uppercased().unicodeScalars {
            if let flag = UnicodeScalar(base + scalar.value) {
                emoji.append(String(flag))
            }
        }
        return emoji.isEmpty ? "🌍" : emoji
    }

    var displaySource: String {
        if isAutoDetected && isManuallyAdded {
            return "Auto + Manual"
        } else if isAutoDetected {
            return "Auto-detected"
        } else {
            return "Manually added"
        }
    }

    var totalTrips: Int {
        trips.count + (isAutoDetected ? 1 : 0)
    }

    var formattedFirstVisit: String {
        guard let date = firstVisitDate else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    var formattedLastVisit: String {
        guard let date = lastVisitDate else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    var formattedTimeSpent: String {
        let totalSeconds = Int(totalTimeSpent)
        let days = totalSeconds / 86400
        let hours = (totalSeconds % 86400) / 3600
        let minutes = (totalSeconds % 3600) / 60

        if days > 0 {
            let remainingHours = hours
            if remainingHours > 0 {
                return "\(days)d \(remainingHours)h"
            }
            return "\(days) days"
        } else if hours > 0 {
            if minutes > 0 {
                return "\(hours)h \(minutes)m"
            }
            return "\(hours) hours"
        } else if minutes > 0 {
            return "\(minutes) min"
        } else {
            return "< 1 min"
        }
    }

    var hasTimeTracking: Bool {
        totalTimeSpent > 0 || !visitSessions.isEmpty
    }

    var activeSession: VisitSession? {
        visitSessions.first { $0.isActive }
    }

    var totalVisitCount: Int {
        visitSessions.count + trips.count
    }

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        name: String,
        isoCode: String,
        continent: String? = nil,
        isAutoDetected: Bool = false,
        isManuallyAdded: Bool = false,
        firstVisitDate: Date? = nil,
        lastVisitDate: Date? = nil,
        trips: [CountryTrip] = [],
        autoDetectedCityCount: Int = 0,
        totalTimeSpent: TimeInterval = 0,
        visitSessions: [VisitSession] = []
    ) {
        self.id = id
        self.name = name
        self.isoCode = isoCode
        self.continent = continent
        self.isAutoDetected = isAutoDetected
        self.isManuallyAdded = isManuallyAdded
        self.firstVisitDate = firstVisitDate
        self.lastVisitDate = lastVisitDate
        self.trips = trips
        self.autoDetectedCityCount = autoDetectedCityCount
        self.totalTimeSpent = totalTimeSpent
        self.visitSessions = visitSessions
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    static func == (lhs: VisitedCountry, rhs: VisitedCountry) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Visit Session Model (for time tracking)

struct VisitSession: Codable, Identifiable, Equatable {
    let id: UUID
    var entryDate: Date
    var exitDate: Date?  // nil if still in country
    var createdAt: Date

    var duration: TimeInterval {
        let end = exitDate ?? Date()
        return end.timeIntervalSince(entryDate)
    }

    var formattedDuration: String {
        let totalSeconds = Int(duration)
        let days = totalSeconds / 86400
        let hours = (totalSeconds % 86400) / 3600
        let minutes = (totalSeconds % 3600) / 60

        if days > 0 {
            return "\(days)d \(hours)h"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    var isActive: Bool {
        exitDate == nil
    }

    init(
        id: UUID = UUID(),
        entryDate: Date,
        exitDate: Date? = nil
    ) {
        self.id = id
        self.entryDate = entryDate
        self.exitDate = exitDate
        self.createdAt = Date()
    }
}

// MARK: - Country Trip Model

struct CountryTrip: Codable, Identifiable, Equatable {
    let id: UUID
    var visitDate: Date?                // Specific date if known
    var visitYear: Int?                 // Year only if exact date unknown
    var tripName: String?               // "Summer Vacation 2023"
    var notes: String?                  // Optional trip notes
    var createdAt: Date
    var duration: TimeInterval?         // Optional duration in seconds

    // Custom decoder for backwards compatibility
    enum CodingKeys: String, CodingKey {
        case id, visitDate, visitYear, tripName, notes, createdAt, duration
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        visitDate = try container.decodeIfPresent(Date.self, forKey: .visitDate)
        visitYear = try container.decodeIfPresent(Int.self, forKey: .visitYear)
        tripName = try container.decodeIfPresent(String.self, forKey: .tripName)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        duration = try container.decodeIfPresent(TimeInterval.self, forKey: .duration)
    }

    var displayDate: String {
        if let date = visitDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        } else if let year = visitYear {
            return String(year)
        }
        return "Date unknown"
    }

    var effectiveDate: Date? {
        if let date = visitDate {
            return date
        } else if let year = visitYear {
            return Calendar.current.date(from: DateComponents(year: year))
        }
        return nil
    }

    var formattedDuration: String? {
        guard let duration = duration else { return nil }
        let totalSeconds = Int(duration)
        let days = totalSeconds / 86400
        let hours = (totalSeconds % 86400) / 3600

        if days > 0 {
            return "\(days)d \(hours)h"
        } else if hours > 0 {
            return "\(hours) hours"
        } else {
            let minutes = totalSeconds / 60
            return "\(minutes) min"
        }
    }

    init(
        id: UUID = UUID(),
        visitDate: Date? = nil,
        visitYear: Int? = nil,
        tripName: String? = nil,
        notes: String? = nil,
        duration: TimeInterval? = nil
    ) {
        self.id = id
        self.visitDate = visitDate
        self.visitYear = visitYear
        self.tripName = tripName
        self.notes = notes
        self.duration = duration
        self.createdAt = Date()
    }
}

// MARK: - Sort Options

enum CountrySortOption: String, CaseIterable {
    case recentVisit = "Most Recent"
    case firstVisited = "First Visited"
    case alphabetical = "A-Z"
    case continent = "By Continent"

    func sort(_ countries: [VisitedCountry]) -> [VisitedCountry] {
        switch self {
        case .recentVisit:
            return countries.sorted { ($0.lastVisitDate ?? .distantPast) > ($1.lastVisitDate ?? .distantPast) }
        case .firstVisited:
            return countries.sorted { ($0.firstVisitDate ?? .distantFuture) < ($1.firstVisitDate ?? .distantFuture) }
        case .alphabetical:
            return countries.sorted { $0.name < $1.name }
        case .continent:
            return countries.sorted {
                if $0.continent == $1.continent {
                    return $0.name < $1.name
                }
                return ($0.continent ?? "ZZZ") < ($1.continent ?? "ZZZ")
            }
        }
    }
}

// MARK: - Continent

enum Continent: String, CaseIterable {
    case africa = "Africa"
    case antarctica = "Antarctica"
    case asia = "Asia"
    case europe = "Europe"
    case northAmerica = "North America"
    case oceania = "Oceania"
    case southAmerica = "South America"

    var emoji: String {
        switch self {
        case .africa: return "🌍"
        case .antarctica: return "🧊"
        case .asia: return "🌏"
        case .europe: return "🌍"
        case .northAmerica: return "🌎"
        case .oceania: return "🌏"
        case .southAmerica: return "🌎"
        }
    }
}

// MARK: - Static Country Data (Fallback when GeoJSON not loaded)

struct CountryData {
    let name: String
    let isoCode: String
    let continent: String
    let latitude: Double
    let longitude: Double

    /// All world countries with basic info
    static let allCountries: [CountryData] = [
        // Africa
        CountryData(name: "Algeria", isoCode: "DZ", continent: "Africa", latitude: 28.0339, longitude: 1.6596),
        CountryData(name: "Angola", isoCode: "AO", continent: "Africa", latitude: -11.2027, longitude: 17.8739),
        CountryData(name: "Benin", isoCode: "BJ", continent: "Africa", latitude: 9.3077, longitude: 2.3158),
        CountryData(name: "Botswana", isoCode: "BW", continent: "Africa", latitude: -22.3285, longitude: 24.6849),
        CountryData(name: "Burkina Faso", isoCode: "BF", continent: "Africa", latitude: 12.2383, longitude: -1.5616),
        CountryData(name: "Burundi", isoCode: "BI", continent: "Africa", latitude: -3.3731, longitude: 29.9189),
        CountryData(name: "Cameroon", isoCode: "CM", continent: "Africa", latitude: 7.3697, longitude: 12.3547),
        CountryData(name: "Central African Republic", isoCode: "CF", continent: "Africa", latitude: 6.6111, longitude: 20.9394),
        CountryData(name: "Chad", isoCode: "TD", continent: "Africa", latitude: 15.4542, longitude: 18.7322),
        CountryData(name: "Comoros", isoCode: "KM", continent: "Africa", latitude: -11.6455, longitude: 43.3333),
        CountryData(name: "DR Congo", isoCode: "CD", continent: "Africa", latitude: -4.0383, longitude: 21.7587),
        CountryData(name: "Djibouti", isoCode: "DJ", continent: "Africa", latitude: 11.8251, longitude: 42.5903),
        CountryData(name: "Egypt", isoCode: "EG", continent: "Africa", latitude: 26.8206, longitude: 30.8025),
        CountryData(name: "Equatorial Guinea", isoCode: "GQ", continent: "Africa", latitude: 1.6508, longitude: 10.2679),
        CountryData(name: "Eritrea", isoCode: "ER", continent: "Africa", latitude: 15.1794, longitude: 39.7823),
        CountryData(name: "Eswatini", isoCode: "SZ", continent: "Africa", latitude: -26.5225, longitude: 31.4659),
        CountryData(name: "Ethiopia", isoCode: "ET", continent: "Africa", latitude: 9.145, longitude: 40.4897),
        CountryData(name: "Gabon", isoCode: "GA", continent: "Africa", latitude: -0.8037, longitude: 11.6094),
        CountryData(name: "Gambia", isoCode: "GM", continent: "Africa", latitude: 13.4432, longitude: -15.3101),
        CountryData(name: "Ghana", isoCode: "GH", continent: "Africa", latitude: 7.9465, longitude: -1.0232),
        CountryData(name: "Guinea", isoCode: "GN", continent: "Africa", latitude: 9.9456, longitude: -9.6966),
        CountryData(name: "Guinea-Bissau", isoCode: "GW", continent: "Africa", latitude: 11.8037, longitude: -15.1804),
        CountryData(name: "Ivory Coast", isoCode: "CI", continent: "Africa", latitude: 7.54, longitude: -5.5471),
        CountryData(name: "Kenya", isoCode: "KE", continent: "Africa", latitude: -0.0236, longitude: 37.9062),
        CountryData(name: "Lesotho", isoCode: "LS", continent: "Africa", latitude: -29.61, longitude: 28.2336),
        CountryData(name: "Liberia", isoCode: "LR", continent: "Africa", latitude: 6.4281, longitude: -9.4295),
        CountryData(name: "Libya", isoCode: "LY", continent: "Africa", latitude: 26.3351, longitude: 17.2283),
        CountryData(name: "Madagascar", isoCode: "MG", continent: "Africa", latitude: -18.7669, longitude: 46.8691),
        CountryData(name: "Malawi", isoCode: "MW", continent: "Africa", latitude: -13.2543, longitude: 34.3015),
        CountryData(name: "Mali", isoCode: "ML", continent: "Africa", latitude: 17.5707, longitude: -3.9962),
        CountryData(name: "Mauritania", isoCode: "MR", continent: "Africa", latitude: 21.0079, longitude: -10.9408),
        CountryData(name: "Mauritius", isoCode: "MU", continent: "Africa", latitude: -20.3484, longitude: 57.5522),
        CountryData(name: "Morocco", isoCode: "MA", continent: "Africa", latitude: 31.7917, longitude: -7.0926),
        CountryData(name: "Mozambique", isoCode: "MZ", continent: "Africa", latitude: -18.6657, longitude: 35.5296),
        CountryData(name: "Namibia", isoCode: "NA", continent: "Africa", latitude: -22.9576, longitude: 18.4904),
        CountryData(name: "Niger", isoCode: "NE", continent: "Africa", latitude: 17.6078, longitude: 8.0817),
        CountryData(name: "Nigeria", isoCode: "NG", continent: "Africa", latitude: 9.082, longitude: 8.6753),
        CountryData(name: "Republic of the Congo", isoCode: "CG", continent: "Africa", latitude: -0.228, longitude: 15.8277),
        CountryData(name: "Rwanda", isoCode: "RW", continent: "Africa", latitude: -1.9403, longitude: 29.8739),
        CountryData(name: "Senegal", isoCode: "SN", continent: "Africa", latitude: 14.4974, longitude: -14.4524),
        CountryData(name: "Sierra Leone", isoCode: "SL", continent: "Africa", latitude: 8.4606, longitude: -11.7799),
        CountryData(name: "Somalia", isoCode: "SO", continent: "Africa", latitude: 5.1521, longitude: 46.1996),
        CountryData(name: "South Africa", isoCode: "ZA", continent: "Africa", latitude: -30.5595, longitude: 22.9375),
        CountryData(name: "South Sudan", isoCode: "SS", continent: "Africa", latitude: 6.877, longitude: 31.307),
        CountryData(name: "Sudan", isoCode: "SD", continent: "Africa", latitude: 12.8628, longitude: 30.2176),
        CountryData(name: "Tanzania", isoCode: "TZ", continent: "Africa", latitude: -6.369, longitude: 34.8888),
        CountryData(name: "Togo", isoCode: "TG", continent: "Africa", latitude: 8.6195, longitude: 0.8248),
        CountryData(name: "Tunisia", isoCode: "TN", continent: "Africa", latitude: 33.8869, longitude: 9.5375),
        CountryData(name: "Uganda", isoCode: "UG", continent: "Africa", latitude: 1.3733, longitude: 32.2903),
        CountryData(name: "Zambia", isoCode: "ZM", continent: "Africa", latitude: -13.1339, longitude: 27.8493),
        CountryData(name: "Zimbabwe", isoCode: "ZW", continent: "Africa", latitude: -19.0154, longitude: 29.1549),

        // Asia
        CountryData(name: "Afghanistan", isoCode: "AF", continent: "Asia", latitude: 33.9391, longitude: 67.71),
        CountryData(name: "Armenia", isoCode: "AM", continent: "Asia", latitude: 40.0691, longitude: 45.0382),
        CountryData(name: "Azerbaijan", isoCode: "AZ", continent: "Asia", latitude: 40.1431, longitude: 47.5769),
        CountryData(name: "Bahrain", isoCode: "BH", continent: "Asia", latitude: 26.0667, longitude: 50.5577),
        CountryData(name: "Bangladesh", isoCode: "BD", continent: "Asia", latitude: 23.685, longitude: 90.3563),
        CountryData(name: "Bhutan", isoCode: "BT", continent: "Asia", latitude: 27.5142, longitude: 90.4336),
        CountryData(name: "Brunei", isoCode: "BN", continent: "Asia", latitude: 4.5353, longitude: 114.7277),
        CountryData(name: "Cambodia", isoCode: "KH", continent: "Asia", latitude: 12.5657, longitude: 104.991),
        CountryData(name: "China", isoCode: "CN", continent: "Asia", latitude: 35.8617, longitude: 104.1954),
        CountryData(name: "Georgia", isoCode: "GE", continent: "Asia", latitude: 42.3154, longitude: 43.3569),
        CountryData(name: "India", isoCode: "IN", continent: "Asia", latitude: 20.5937, longitude: 78.9629),
        CountryData(name: "Indonesia", isoCode: "ID", continent: "Asia", latitude: -0.7893, longitude: 113.9213),
        CountryData(name: "Iran", isoCode: "IR", continent: "Asia", latitude: 32.4279, longitude: 53.688),
        CountryData(name: "Iraq", isoCode: "IQ", continent: "Asia", latitude: 33.2232, longitude: 43.6793),
        CountryData(name: "Israel", isoCode: "IL", continent: "Asia", latitude: 31.0461, longitude: 34.8516),
        CountryData(name: "Japan", isoCode: "JP", continent: "Asia", latitude: 36.2048, longitude: 138.2529),
        CountryData(name: "Jordan", isoCode: "JO", continent: "Asia", latitude: 30.5852, longitude: 36.2384),
        CountryData(name: "Kazakhstan", isoCode: "KZ", continent: "Asia", latitude: 48.0196, longitude: 66.9237),
        CountryData(name: "Kuwait", isoCode: "KW", continent: "Asia", latitude: 29.3117, longitude: 47.4818),
        CountryData(name: "Kyrgyzstan", isoCode: "KG", continent: "Asia", latitude: 41.2044, longitude: 74.7661),
        CountryData(name: "Laos", isoCode: "LA", continent: "Asia", latitude: 19.8563, longitude: 102.4955),
        CountryData(name: "Lebanon", isoCode: "LB", continent: "Asia", latitude: 33.8547, longitude: 35.8623),
        CountryData(name: "Malaysia", isoCode: "MY", continent: "Asia", latitude: 4.2105, longitude: 101.9758),
        CountryData(name: "Maldives", isoCode: "MV", continent: "Asia", latitude: 3.2028, longitude: 73.2207),
        CountryData(name: "Mongolia", isoCode: "MN", continent: "Asia", latitude: 46.8625, longitude: 103.8467),
        CountryData(name: "Myanmar", isoCode: "MM", continent: "Asia", latitude: 21.9162, longitude: 95.956),
        CountryData(name: "Nepal", isoCode: "NP", continent: "Asia", latitude: 28.3949, longitude: 84.124),
        CountryData(name: "North Korea", isoCode: "KP", continent: "Asia", latitude: 40.3399, longitude: 127.5101),
        CountryData(name: "Oman", isoCode: "OM", continent: "Asia", latitude: 21.4735, longitude: 55.9754),
        CountryData(name: "Pakistan", isoCode: "PK", continent: "Asia", latitude: 30.3753, longitude: 69.3451),
        CountryData(name: "Palestine", isoCode: "PS", continent: "Asia", latitude: 31.9522, longitude: 35.2332),
        CountryData(name: "Philippines", isoCode: "PH", continent: "Asia", latitude: 12.8797, longitude: 121.774),
        CountryData(name: "Qatar", isoCode: "QA", continent: "Asia", latitude: 25.3548, longitude: 51.1839),
        CountryData(name: "Saudi Arabia", isoCode: "SA", continent: "Asia", latitude: 23.8859, longitude: 45.0792),
        CountryData(name: "Singapore", isoCode: "SG", continent: "Asia", latitude: 1.3521, longitude: 103.8198),
        CountryData(name: "South Korea", isoCode: "KR", continent: "Asia", latitude: 35.9078, longitude: 127.7669),
        CountryData(name: "Sri Lanka", isoCode: "LK", continent: "Asia", latitude: 7.8731, longitude: 80.7718),
        CountryData(name: "Syria", isoCode: "SY", continent: "Asia", latitude: 34.8021, longitude: 38.9968),
        CountryData(name: "Taiwan", isoCode: "TW", continent: "Asia", latitude: 23.6978, longitude: 120.9605),
        CountryData(name: "Tajikistan", isoCode: "TJ", continent: "Asia", latitude: 38.861, longitude: 71.2761),
        CountryData(name: "Thailand", isoCode: "TH", continent: "Asia", latitude: 15.87, longitude: 100.9925),
        CountryData(name: "Timor-Leste", isoCode: "TL", continent: "Asia", latitude: -8.8742, longitude: 125.7275),
        CountryData(name: "Turkey", isoCode: "TR", continent: "Asia", latitude: 38.9637, longitude: 35.2433),
        CountryData(name: "Turkmenistan", isoCode: "TM", continent: "Asia", latitude: 38.9697, longitude: 59.5563),
        CountryData(name: "United Arab Emirates", isoCode: "AE", continent: "Asia", latitude: 23.4241, longitude: 53.8478),
        CountryData(name: "Uzbekistan", isoCode: "UZ", continent: "Asia", latitude: 41.3775, longitude: 64.5853),
        CountryData(name: "Vietnam", isoCode: "VN", continent: "Asia", latitude: 14.0583, longitude: 108.2772),
        CountryData(name: "Yemen", isoCode: "YE", continent: "Asia", latitude: 15.5527, longitude: 48.5164),

        // Europe
        CountryData(name: "Albania", isoCode: "AL", continent: "Europe", latitude: 41.1533, longitude: 20.1683),
        CountryData(name: "Andorra", isoCode: "AD", continent: "Europe", latitude: 42.5063, longitude: 1.5218),
        CountryData(name: "Austria", isoCode: "AT", continent: "Europe", latitude: 47.5162, longitude: 14.5501),
        CountryData(name: "Belarus", isoCode: "BY", continent: "Europe", latitude: 53.7098, longitude: 27.9534),
        CountryData(name: "Belgium", isoCode: "BE", continent: "Europe", latitude: 50.5039, longitude: 4.4699),
        CountryData(name: "Bosnia and Herzegovina", isoCode: "BA", continent: "Europe", latitude: 43.9159, longitude: 17.6791),
        CountryData(name: "Bulgaria", isoCode: "BG", continent: "Europe", latitude: 42.7339, longitude: 25.4858),
        CountryData(name: "Croatia", isoCode: "HR", continent: "Europe", latitude: 45.1, longitude: 15.2),
        CountryData(name: "Cyprus", isoCode: "CY", continent: "Europe", latitude: 35.1264, longitude: 33.4299),
        CountryData(name: "Czech Republic", isoCode: "CZ", continent: "Europe", latitude: 49.8175, longitude: 15.473),
        CountryData(name: "Denmark", isoCode: "DK", continent: "Europe", latitude: 56.2639, longitude: 9.5018),
        CountryData(name: "Estonia", isoCode: "EE", continent: "Europe", latitude: 58.5953, longitude: 25.0136),
        CountryData(name: "Finland", isoCode: "FI", continent: "Europe", latitude: 61.9241, longitude: 25.7482),
        CountryData(name: "France", isoCode: "FR", continent: "Europe", latitude: 46.2276, longitude: 2.2137),
        CountryData(name: "Germany", isoCode: "DE", continent: "Europe", latitude: 51.1657, longitude: 10.4515),
        CountryData(name: "Greece", isoCode: "GR", continent: "Europe", latitude: 39.0742, longitude: 21.8243),
        CountryData(name: "Hungary", isoCode: "HU", continent: "Europe", latitude: 47.1625, longitude: 19.5033),
        CountryData(name: "Iceland", isoCode: "IS", continent: "Europe", latitude: 64.9631, longitude: -19.0208),
        CountryData(name: "Ireland", isoCode: "IE", continent: "Europe", latitude: 53.1424, longitude: -7.6921),
        CountryData(name: "Italy", isoCode: "IT", continent: "Europe", latitude: 41.8719, longitude: 12.5674),
        CountryData(name: "Kosovo", isoCode: "XK", continent: "Europe", latitude: 42.6026, longitude: 20.903),
        CountryData(name: "Latvia", isoCode: "LV", continent: "Europe", latitude: 56.8796, longitude: 24.6032),
        CountryData(name: "Liechtenstein", isoCode: "LI", continent: "Europe", latitude: 47.166, longitude: 9.5554),
        CountryData(name: "Lithuania", isoCode: "LT", continent: "Europe", latitude: 55.1694, longitude: 23.8813),
        CountryData(name: "Luxembourg", isoCode: "LU", continent: "Europe", latitude: 49.8153, longitude: 6.1296),
        CountryData(name: "Malta", isoCode: "MT", continent: "Europe", latitude: 35.9375, longitude: 14.3754),
        CountryData(name: "Moldova", isoCode: "MD", continent: "Europe", latitude: 47.4116, longitude: 28.3699),
        CountryData(name: "Monaco", isoCode: "MC", continent: "Europe", latitude: 43.7384, longitude: 7.4246),
        CountryData(name: "Montenegro", isoCode: "ME", continent: "Europe", latitude: 42.7087, longitude: 19.3744),
        CountryData(name: "Netherlands", isoCode: "NL", continent: "Europe", latitude: 52.1326, longitude: 5.2913),
        CountryData(name: "North Macedonia", isoCode: "MK", continent: "Europe", latitude: 41.5124, longitude: 21.7453),
        CountryData(name: "Norway", isoCode: "NO", continent: "Europe", latitude: 60.472, longitude: 8.4689),
        CountryData(name: "Poland", isoCode: "PL", continent: "Europe", latitude: 51.9194, longitude: 19.1451),
        CountryData(name: "Portugal", isoCode: "PT", continent: "Europe", latitude: 39.3999, longitude: -8.2245),
        CountryData(name: "Romania", isoCode: "RO", continent: "Europe", latitude: 45.9432, longitude: 24.9668),
        CountryData(name: "Russia", isoCode: "RU", continent: "Europe", latitude: 61.524, longitude: 105.3188),
        CountryData(name: "San Marino", isoCode: "SM", continent: "Europe", latitude: 43.9424, longitude: 12.4578),
        CountryData(name: "Serbia", isoCode: "RS", continent: "Europe", latitude: 44.0165, longitude: 21.0059),
        CountryData(name: "Slovakia", isoCode: "SK", continent: "Europe", latitude: 48.669, longitude: 19.699),
        CountryData(name: "Slovenia", isoCode: "SI", continent: "Europe", latitude: 46.1512, longitude: 14.9955),
        CountryData(name: "Spain", isoCode: "ES", continent: "Europe", latitude: 40.4637, longitude: -3.7492),
        CountryData(name: "Sweden", isoCode: "SE", continent: "Europe", latitude: 60.1282, longitude: 18.6435),
        CountryData(name: "Switzerland", isoCode: "CH", continent: "Europe", latitude: 46.8182, longitude: 8.2275),
        CountryData(name: "Ukraine", isoCode: "UA", continent: "Europe", latitude: 48.3794, longitude: 31.1656),
        CountryData(name: "United Kingdom", isoCode: "GB", continent: "Europe", latitude: 55.3781, longitude: -3.436),
        CountryData(name: "Vatican City", isoCode: "VA", continent: "Europe", latitude: 41.9029, longitude: 12.4534),

        // North America
        CountryData(name: "Antigua and Barbuda", isoCode: "AG", continent: "North America", latitude: 17.0608, longitude: -61.7964),
        CountryData(name: "Bahamas", isoCode: "BS", continent: "North America", latitude: 25.0343, longitude: -77.3963),
        CountryData(name: "Barbados", isoCode: "BB", continent: "North America", latitude: 13.1939, longitude: -59.5432),
        CountryData(name: "Belize", isoCode: "BZ", continent: "North America", latitude: 17.1899, longitude: -88.4976),
        CountryData(name: "Canada", isoCode: "CA", continent: "North America", latitude: 56.1304, longitude: -106.3468),
        CountryData(name: "Costa Rica", isoCode: "CR", continent: "North America", latitude: 9.7489, longitude: -83.7534),
        CountryData(name: "Cuba", isoCode: "CU", continent: "North America", latitude: 21.5218, longitude: -77.7812),
        CountryData(name: "Dominica", isoCode: "DM", continent: "North America", latitude: 15.415, longitude: -61.371),
        CountryData(name: "Dominican Republic", isoCode: "DO", continent: "North America", latitude: 18.7357, longitude: -70.1627),
        CountryData(name: "El Salvador", isoCode: "SV", continent: "North America", latitude: 13.7942, longitude: -88.8965),
        CountryData(name: "Grenada", isoCode: "GD", continent: "North America", latitude: 12.1165, longitude: -61.679),
        CountryData(name: "Guatemala", isoCode: "GT", continent: "North America", latitude: 15.7835, longitude: -90.2308),
        CountryData(name: "Haiti", isoCode: "HT", continent: "North America", latitude: 18.9712, longitude: -72.2852),
        CountryData(name: "Honduras", isoCode: "HN", continent: "North America", latitude: 15.2, longitude: -86.2419),
        CountryData(name: "Jamaica", isoCode: "JM", continent: "North America", latitude: 18.1096, longitude: -77.2975),
        CountryData(name: "Mexico", isoCode: "MX", continent: "North America", latitude: 23.6345, longitude: -102.5528),
        CountryData(name: "Nicaragua", isoCode: "NI", continent: "North America", latitude: 12.8654, longitude: -85.2072),
        CountryData(name: "Panama", isoCode: "PA", continent: "North America", latitude: 8.538, longitude: -80.7821),
        CountryData(name: "Saint Kitts and Nevis", isoCode: "KN", continent: "North America", latitude: 17.3578, longitude: -62.783),
        CountryData(name: "Saint Lucia", isoCode: "LC", continent: "North America", latitude: 13.9094, longitude: -60.9789),
        CountryData(name: "Saint Vincent and the Grenadines", isoCode: "VC", continent: "North America", latitude: 12.9843, longitude: -61.2872),
        CountryData(name: "Trinidad and Tobago", isoCode: "TT", continent: "North America", latitude: 10.6918, longitude: -61.2225),
        CountryData(name: "United States", isoCode: "US", continent: "North America", latitude: 37.0902, longitude: -95.7129),

        // South America
        CountryData(name: "Argentina", isoCode: "AR", continent: "South America", latitude: -38.4161, longitude: -63.6167),
        CountryData(name: "Bolivia", isoCode: "BO", continent: "South America", latitude: -16.2902, longitude: -63.5887),
        CountryData(name: "Brazil", isoCode: "BR", continent: "South America", latitude: -14.235, longitude: -51.9253),
        CountryData(name: "Chile", isoCode: "CL", continent: "South America", latitude: -35.6751, longitude: -71.543),
        CountryData(name: "Colombia", isoCode: "CO", continent: "South America", latitude: 4.5709, longitude: -74.2973),
        CountryData(name: "Ecuador", isoCode: "EC", continent: "South America", latitude: -1.8312, longitude: -78.1834),
        CountryData(name: "Guyana", isoCode: "GY", continent: "South America", latitude: 4.8604, longitude: -58.9302),
        CountryData(name: "Paraguay", isoCode: "PY", continent: "South America", latitude: -23.4425, longitude: -58.4438),
        CountryData(name: "Peru", isoCode: "PE", continent: "South America", latitude: -9.19, longitude: -75.0152),
        CountryData(name: "Suriname", isoCode: "SR", continent: "South America", latitude: 3.9193, longitude: -56.0278),
        CountryData(name: "Uruguay", isoCode: "UY", continent: "South America", latitude: -32.5228, longitude: -55.7658),
        CountryData(name: "Venezuela", isoCode: "VE", continent: "South America", latitude: 6.4238, longitude: -66.5897),

        // Oceania
        CountryData(name: "Australia", isoCode: "AU", continent: "Oceania", latitude: -25.2744, longitude: 133.7751),
        CountryData(name: "Fiji", isoCode: "FJ", continent: "Oceania", latitude: -17.7134, longitude: 178.065),
        CountryData(name: "Kiribati", isoCode: "KI", continent: "Oceania", latitude: -3.3704, longitude: -168.734),
        CountryData(name: "Marshall Islands", isoCode: "MH", continent: "Oceania", latitude: 7.1315, longitude: 171.1845),
        CountryData(name: "Micronesia", isoCode: "FM", continent: "Oceania", latitude: 7.4256, longitude: 150.5508),
        CountryData(name: "Nauru", isoCode: "NR", continent: "Oceania", latitude: -0.5228, longitude: 166.9315),
        CountryData(name: "New Zealand", isoCode: "NZ", continent: "Oceania", latitude: -40.9006, longitude: 174.886),
        CountryData(name: "Palau", isoCode: "PW", continent: "Oceania", latitude: 7.515, longitude: 134.5825),
        CountryData(name: "Papua New Guinea", isoCode: "PG", continent: "Oceania", latitude: -6.315, longitude: 143.9555),
        CountryData(name: "Samoa", isoCode: "WS", continent: "Oceania", latitude: -13.759, longitude: -172.1046),
        CountryData(name: "Solomon Islands", isoCode: "SB", continent: "Oceania", latitude: -9.6457, longitude: 160.1562),
        CountryData(name: "Tonga", isoCode: "TO", continent: "Oceania", latitude: -21.179, longitude: -175.1982),
        CountryData(name: "Tuvalu", isoCode: "TV", continent: "Oceania", latitude: -7.1095, longitude: 179.194),
        CountryData(name: "Vanuatu", isoCode: "VU", continent: "Oceania", latitude: -15.3767, longitude: 166.9592),

        // Antarctica (no permanent countries, but including for completeness)
    ]

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var flagEmoji: String {
        let base: UInt32 = 127397
        var emoji = ""
        for scalar in isoCode.uppercased().unicodeScalars {
            if let flag = UnicodeScalar(base + scalar.value) {
                emoji.append(String(flag))
            }
        }
        return emoji.isEmpty ? "🌍" : emoji
    }
}
