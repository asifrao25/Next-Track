//
//  DetectedPlace.swift
//  Next-track
//
//  Model for automatically detected places (stores, cafes, etc.)
//

import Foundation
import CoreLocation
import SwiftUI

// MARK: - Place Category

enum PlaceCategory: String, Codable, CaseIterable {
    case home = "Home"
    case work = "Work"
    case cafe = "Cafe"
    case restaurant = "Restaurant"
    case shopping = "Shopping"
    case gym = "Gym"
    case gasStation = "Gas Station"
    case grocery = "Grocery"
    case medical = "Medical"
    case entertainment = "Entertainment"
    case transit = "Transit"
    case park = "Park"
    case other = "Other"

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .work: return "building.2.fill"
        case .cafe: return "cup.and.saucer.fill"
        case .restaurant: return "fork.knife"
        case .shopping: return "bag.fill"
        case .gym: return "dumbbell.fill"
        case .gasStation: return "fuelpump.fill"
        case .grocery: return "cart.fill"
        case .medical: return "cross.case.fill"
        case .entertainment: return "film.fill"
        case .transit: return "tram.fill"
        case .park: return "leaf.fill"
        case .other: return "mappin.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .home: return .blue
        case .work: return .purple
        case .cafe: return .brown
        case .restaurant: return .red
        case .shopping: return .pink
        case .gym: return .orange
        case .gasStation: return .yellow
        case .grocery: return .green
        case .medical: return .red
        case .entertainment: return .indigo
        case .transit: return .gray
        case .park: return .green
        case .other: return .secondary
        }
    }

    /// Keywords used to detect this category from geocoded place names
    var keywords: [String] {
        switch self {
        case .home: return []  // Detected by time patterns
        case .work: return ["office", "corporate", "headquarters"]
        case .cafe: return ["coffee", "starbucks", "cafe", "peet's", "dunkin", "espresso", "latte"]
        case .restaurant: return ["restaurant", "grill", "kitchen", "diner", "bistro", "eatery", "tavern", "pizzeria", "burger", "taco", "sushi", "thai", "chinese", "mexican", "indian"]
        case .shopping: return ["target", "walmart", "costco", "mall", "store", "shop", "outlet", "best buy", "home depot", "lowes", "ikea", "ross", "tjmaxx", "marshalls", "nordstrom", "macy"]
        case .gym: return ["gym", "fitness", "yoga", "pilates", "crossfit", "planet fitness", "24 hour", "equinox", "orangetheory", "la fitness"]
        case .gasStation: return ["shell", "chevron", "gas", "76", "arco", "mobil", "exxon", "bp", "texaco", "valero", "costco gas", "fuel"]
        case .grocery: return ["grocery", "safeway", "whole foods", "trader joe", "kroger", "publix", "albertsons", "vons", "ralphs", "sprouts", "aldi", "food", "market"]
        case .medical: return ["hospital", "clinic", "medical", "doctor", "urgent care", "pharmacy", "cvs", "walgreens", "health", "dental", "veterinar"]
        case .entertainment: return ["theater", "theatre", "cinema", "movie", "amc", "regal", "museum", "gallery", "concert", "stadium", "arena", "bowling", "arcade"]
        case .transit: return ["station", "airport", "terminal", "bus stop", "metro", "bart", "subway", "train", "amtrak"]
        case .park: return ["park", "beach", "trail", "nature", "garden", "reserve", "forest", "lake", "recreation"]
        case .other: return []
        }
    }
}

// MARK: - Place Details (from geocoding)

struct PlaceDetails: Codable {
    var name: String?
    var streetAddress: String?
    var city: String?
    var state: String?
    var country: String?
    var postalCode: String?

    var fullAddress: String {
        var parts: [String] = []
        if let street = streetAddress { parts.append(street) }
        if let city = city { parts.append(city) }
        if let state = state { parts.append(state) }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Place Visit

struct PlaceVisit: Codable, Identifiable {
    let id: UUID
    let arrivalTime: Date
    var departureTime: Date?

    var dwellTime: TimeInterval {
        guard let departure = departureTime else {
            return Date().timeIntervalSince(arrivalTime)
        }
        return departure.timeIntervalSince(arrivalTime)
    }

    var formattedDwellTime: String {
        let minutes = Int(dwellTime / 60)
        if minutes < 60 {
            return "\(minutes) min"
        }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if remainingMinutes == 0 {
            return "\(hours)h"
        }
        return "\(hours)h \(remainingMinutes)m"
    }

    init(arrivalTime: Date = Date(), departureTime: Date? = nil) {
        self.id = UUID()
        self.arrivalTime = arrivalTime
        self.departureTime = departureTime
    }
}

// MARK: - Detected Place

struct DetectedPlace: Codable, Identifiable {
    let id: UUID
    var latitude: Double
    var longitude: Double
    var radius: Double              // meters, computed from cluster spread

    var name: String?               // From geocoding or user override
    var streetAddress: String?      // From geocoding
    var category: PlaceCategory     // Auto-detected
    var confidence: Double          // 0-1, how confident we are in the category

    var visitHistory: [PlaceVisit]
    var createdAt: Date
    var lastVisitedAt: Date
    var isConfirmed: Bool           // User has confirmed/named this place

    // MARK: - Computed Properties

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var visitCount: Int {
        visitHistory.count
    }

    var totalDwellTime: TimeInterval {
        visitHistory.reduce(0) { $0 + $1.dwellTime }
    }

    var averageDwellTime: TimeInterval {
        visitCount > 0 ? totalDwellTime / Double(visitCount) : 0
    }

    var displayName: String {
        name ?? "Unknown Place"
    }

    var formattedTotalTime: String {
        let hours = Int(totalDwellTime / 3600)
        let minutes = Int((totalDwellTime.truncatingRemainder(dividingBy: 3600)) / 60)
        if hours > 0 {
            return "\(hours)h \(minutes)m total"
        }
        return "\(minutes) min total"
    }

    var formattedAverageTime: String {
        let minutes = Int(averageDwellTime / 60)
        if minutes < 60 {
            return "~\(minutes) min/visit"
        }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if remainingMinutes == 0 {
            return "~\(hours)h/visit"
        }
        return "~\(hours)h \(remainingMinutes)m/visit"
    }

    var formattedLastVisit: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: lastVisitedAt, relativeTo: Date())
    }

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        latitude: Double,
        longitude: Double,
        radius: Double = 50,
        name: String? = nil,
        streetAddress: String? = nil,
        category: PlaceCategory = .other,
        confidence: Double = 0.5,
        visitHistory: [PlaceVisit] = [],
        createdAt: Date = Date(),
        lastVisitedAt: Date = Date(),
        isConfirmed: Bool = false
    ) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
        self.name = name
        self.streetAddress = streetAddress
        self.category = category
        self.confidence = confidence
        self.visitHistory = visitHistory
        self.createdAt = createdAt
        self.lastVisitedAt = lastVisitedAt
        self.isConfirmed = isConfirmed
    }

    // MARK: - Methods

    /// Add a new visit to this place
    mutating func recordVisit(arrival: Date = Date(), departure: Date? = nil) {
        let visit = PlaceVisit(arrivalTime: arrival, departureTime: departure)
        visitHistory.append(visit)
        lastVisitedAt = arrival
    }

    /// Update the last visit's departure time
    mutating func endCurrentVisit(departure: Date = Date()) {
        guard var lastVisit = visitHistory.last else { return }
        lastVisit.departureTime = departure
        visitHistory[visitHistory.count - 1] = lastVisit
    }

    /// Check if a coordinate is within this place's radius
    func contains(coordinate: CLLocationCoordinate2D) -> Bool {
        let placeLocation = CLLocation(latitude: latitude, longitude: longitude)
        let testLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return placeLocation.distance(from: testLocation) <= radius
    }

    /// Distance from this place to a coordinate
    func distance(to coordinate: CLLocationCoordinate2D) -> Double {
        let placeLocation = CLLocation(latitude: latitude, longitude: longitude)
        let testLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return placeLocation.distance(from: testLocation)
    }
}

// MARK: - Sort Options

enum PlaceSortOption: String, CaseIterable {
    case recentVisit = "Most Recent"
    case mostVisits = "Most Visits"
    case mostTime = "Most Time"
    case alphabetical = "A-Z"
    case category = "Category"

    func sort(_ places: [DetectedPlace]) -> [DetectedPlace] {
        switch self {
        case .recentVisit:
            return places.sorted { $0.lastVisitedAt > $1.lastVisitedAt }
        case .mostVisits:
            return places.sorted { $0.visitCount > $1.visitCount }
        case .mostTime:
            return places.sorted { $0.totalDwellTime > $1.totalDwellTime }
        case .alphabetical:
            return places.sorted { ($0.name ?? "") < ($1.name ?? "") }
        case .category:
            return places.sorted { $0.category.rawValue < $1.category.rawValue }
        }
    }
}
