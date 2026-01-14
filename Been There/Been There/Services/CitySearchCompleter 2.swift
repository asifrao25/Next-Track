//
//  CitySearchCompleter.swift
//  Next-track
//
//  MapKit-based city search with global autocomplete
//

import Foundation
import MapKit
import Combine
import CoreLocation

@MainActor
class CitySearchCompleter: NSObject, ObservableObject {
    @Published var results: [MKLocalSearchCompletion] = []
    @Published var isSearching = false

    private let completer = MKLocalSearchCompleter()
    private var searchTask: Task<Void, Never>?

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
        completer.pointOfInterestFilter = .excludingAll
    }

    func search(query: String) {
        guard !query.isEmpty else {
            results = []
            isSearching = false
            return
        }

        isSearching = true
        completer.queryFragment = query
    }

    func clearResults() {
        results = []
        isSearching = false
    }

    /// Get full location details for a search completion result
    func getLocationDetails(for completion: MKLocalSearchCompletion) async -> CitySearchResult? {
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)

        do {
            let response = try await search.start()
            guard let mapItem = response.mapItems.first else { return nil }

            let placemark = mapItem.placemark

            return CitySearchResult(
                name: placemark.locality ?? completion.title,
                state: placemark.administrativeArea,
                country: placemark.country ?? "",
                countryCode: placemark.isoCountryCode ?? "",
                latitude: placemark.coordinate.latitude,
                longitude: placemark.coordinate.longitude
            )
        } catch {
            print("CitySearchCompleter: Error getting location details: \(error)")
            return nil
        }
    }

    /// Reverse geocode a coordinate to get city info
    func reverseGeocode(coordinate: CLLocationCoordinate2D) async -> CitySearchResult? {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            guard let placemark = placemarks.first else { return nil }

            // Try to get the most specific locality name
            let cityName = placemark.locality ?? placemark.subAdministrativeArea ?? placemark.administrativeArea ?? "Unknown"

            return CitySearchResult(
                name: cityName,
                state: placemark.administrativeArea,
                country: placemark.country ?? "",
                countryCode: placemark.isoCountryCode ?? "",
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
        } catch {
            print("CitySearchCompleter: Reverse geocode error: \(error)")
            return nil
        }
    }
}

// MARK: - MKLocalSearchCompleterDelegate

extension CitySearchCompleter: MKLocalSearchCompleterDelegate {
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        Task { @MainActor in
            // Filter results to likely be cities/places (exclude street addresses with numbers)
            let filteredResults = completer.results.filter { result in
                // Exclude results that look like street addresses (contain numbers at start)
                let hasLeadingNumber = result.title.first?.isNumber ?? false
                // Exclude results that are just postal codes
                let isPostalCode = result.title.count < 10 && result.title.allSatisfy { $0.isNumber || $0.isWhitespace }

                return !hasLeadingNumber && !isPostalCode
            }

            self.results = filteredResults
            self.isSearching = false
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            print("CitySearchCompleter: Search failed: \(error)")
            self.isSearching = false
        }
    }
}

// MARK: - City Search Result

struct CitySearchResult {
    let name: String
    let state: String?
    let country: String
    let countryCode: String
    let latitude: Double
    let longitude: Double

    var displayName: String {
        if let state = state, !state.isEmpty {
            return "\(name), \(state), \(country)"
        }
        return "\(name), \(country)"
    }

    var shortDisplayName: String {
        if let state = state, !state.isEmpty {
            return "\(name), \(state)"
        }
        return "\(name), \(country)"
    }
}
