//
//  GeoJSONModels.swift
//  Next-track
//
//  GeoJSON parsing for world country boundaries
//

import Foundation
import CoreLocation

// MARK: - GeoJSON Root Structure

struct CountryGeoJSON: Codable {
    let type: String
    let features: [CountryFeature]
}

// MARK: - Country Feature

struct CountryFeature: Codable, Identifiable {
    let type: String
    let properties: CountryProperties
    let geometry: CountryGeometry

    var id: String { properties.isoA2 ?? properties.name }
}

// MARK: - Country Properties

struct CountryProperties: Codable {
    let name: String
    let nameLong: String?
    let isoA2: String?        // Two-letter ISO code (US, GB, etc.)
    let isoA3: String?        // Three-letter ISO code
    let continent: String?
    let popEst: Double?       // Population estimate

    enum CodingKeys: String, CodingKey {
        case name = "NAME"
        case nameLong = "NAME_LONG"
        case isoA2 = "ISO_A2"
        case isoA3 = "ISO_A3"
        case continent = "CONTINENT"
        case popEst = "POP_EST"
    }
}

// MARK: - Country Geometry

struct CountryGeometry: Codable {
    let type: String          // "Polygon" or "MultiPolygon"
    let coordinates: JSONAny  // Nested arrays of coordinates
}

// MARK: - JSON Any (for nested coordinate arrays)

struct JSONAny: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let intVal = try? container.decode(Int.self) {
            value = intVal
        } else if let doubleVal = try? container.decode(Double.self) {
            value = doubleVal
        } else if let boolVal = try? container.decode(Bool.self) {
            value = boolVal
        } else if let stringVal = try? container.decode(String.self) {
            value = stringVal
        } else if let arrayVal = try? container.decode([JSONAny].self) {
            value = arrayVal.map { $0.value }
        } else if let dictVal = try? container.decode([String: JSONAny].self) {
            value = dictVal.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let intVal as Int:
            try container.encode(intVal)
        case let doubleVal as Double:
            try container.encode(doubleVal)
        case let boolVal as Bool:
            try container.encode(boolVal)
        case let stringVal as String:
            try container.encode(stringVal)
        case let arrayVal as [Any]:
            try container.encode(arrayVal.map { JSONAny($0) })
        case let dictVal as [String: Any]:
            try container.encode(dictVal.mapValues { JSONAny($0) })
        default:
            try container.encodeNil()
        }
    }
}

// MARK: - GeoJSON Parser

struct GeoJSONParser {

    /// Parse polygon coordinates from geometry
    static func parsePolygons(from geometry: CountryGeometry) -> [[CLLocationCoordinate2D]] {
        var result: [[CLLocationCoordinate2D]] = []

        guard let coordsAny = geometry.coordinates.value as? [Any] else {
            return result
        }

        if geometry.type == "Polygon" {
            // Polygon: [[[lon, lat], [lon, lat], ...]]
            if let rings = coordsAny as? [[[Double]]] {
                for ring in rings {
                    let coords = ring.compactMap { pair -> CLLocationCoordinate2D? in
                        guard pair.count >= 2 else { return nil }
                        return CLLocationCoordinate2D(latitude: pair[1], longitude: pair[0])
                    }
                    if !coords.isEmpty {
                        result.append(coords)
                    }
                }
            }
        } else if geometry.type == "MultiPolygon" {
            // MultiPolygon: [[[[lon, lat], [lon, lat], ...]], ...]
            if let polygons = coordsAny as? [[[[Double]]]] {
                for polygon in polygons {
                    for ring in polygon {
                        let coords = ring.compactMap { pair -> CLLocationCoordinate2D? in
                            guard pair.count >= 2 else { return nil }
                            return CLLocationCoordinate2D(latitude: pair[1], longitude: pair[0])
                        }
                        if !coords.isEmpty {
                            result.append(coords)
                        }
                    }
                }
            }
        }

        return result
    }

    /// Calculate the centroid of a geometry
    static func calculateCentroid(from geometry: CountryGeometry) -> CLLocationCoordinate2D? {
        let polygons = parsePolygons(from: geometry)
        guard !polygons.isEmpty else { return nil }

        var totalLat: Double = 0
        var totalLon: Double = 0
        var count: Double = 0

        for polygon in polygons {
            for coord in polygon {
                totalLat += coord.latitude
                totalLon += coord.longitude
                count += 1
            }
        }

        guard count > 0 else { return nil }
        return CLLocationCoordinate2D(
            latitude: totalLat / count,
            longitude: totalLon / count
        )
    }
}

// MARK: - Country Polygon (for map rendering)

struct CountryPolygon: Identifiable {
    let id: String
    let isoCode: String
    let name: String
    let coordinates: [CLLocationCoordinate2D]
    var isVisited: Bool

    init(isoCode: String, name: String, coordinates: [CLLocationCoordinate2D], isVisited: Bool = false) {
        self.id = "\(isoCode)-\(UUID().uuidString)"
        self.isoCode = isoCode
        self.name = name
        self.coordinates = coordinates
        self.isVisited = isVisited
    }
}

// MARK: - UK LAD GeoJSON Structures

/// GeoJSON root structure for UK Local Authority Districts
struct UKLADGeoJSON: Codable {
    let type: String
    let features: [UKLADFeature]
}

/// UK LAD Feature
struct UKLADFeature: Codable, Identifiable {
    let type: String
    let properties: UKLADProperties
    let geometry: UKLADGeometry

    var id: String { properties.name }
}

/// UK LAD Properties
struct UKLADProperties: Codable {
    let name: String        // LAD name (e.g., "Nottingham", "Bristol, City of")
    let code: String        // LAD code (e.g., "E06000018")
    let region: String      // Region code (ENG, WAL, SCO, NI)
}

/// UK LAD Geometry
struct UKLADGeometry: Codable {
    let type: String          // "Polygon" or "MultiPolygon"
    let coordinates: JSONAny  // Nested arrays of coordinates
}

// MARK: - UK LAD Parser Extension

extension GeoJSONParser {

    /// Parse polygon coordinates from UK LAD geometry
    static func parsePolygons(from geometry: UKLADGeometry) -> [[CLLocationCoordinate2D]] {
        var result: [[CLLocationCoordinate2D]] = []

        guard let coordsAny = geometry.coordinates.value as? [Any] else {
            return result
        }

        if geometry.type == "Polygon" {
            // Polygon: [[[lon, lat], [lon, lat], ...]]
            if let rings = coordsAny as? [[[Double]]] {
                for ring in rings {
                    let coords = ring.compactMap { pair -> CLLocationCoordinate2D? in
                        guard pair.count >= 2 else { return nil }
                        return CLLocationCoordinate2D(latitude: pair[1], longitude: pair[0])
                    }
                    if !coords.isEmpty {
                        result.append(coords)
                    }
                }
            }
        } else if geometry.type == "MultiPolygon" {
            // MultiPolygon: [[[[lon, lat], [lon, lat], ...]], ...]
            if let polygons = coordsAny as? [[[[Double]]]] {
                for polygon in polygons {
                    for ring in polygon {
                        let coords = ring.compactMap { pair -> CLLocationCoordinate2D? in
                            guard pair.count >= 2 else { return nil }
                            return CLLocationCoordinate2D(latitude: pair[1], longitude: pair[0])
                        }
                        if !coords.isEmpty {
                            result.append(coords)
                        }
                    }
                }
            }
        }

        return result
    }

    /// Calculate the centroid of a UK LAD geometry
    static func calculateCentroid(from geometry: UKLADGeometry) -> CLLocationCoordinate2D? {
        let polygons = parsePolygons(from: geometry)
        guard !polygons.isEmpty else { return nil }

        var totalLat: Double = 0
        var totalLon: Double = 0
        var count: Double = 0

        for polygon in polygons {
            for coord in polygon {
                totalLat += coord.latitude
                totalLon += coord.longitude
                count += 1
            }
        }

        guard count > 0 else { return nil }
        return CLLocationCoordinate2D(
            latitude: totalLat / count,
            longitude: totalLon / count
        )
    }

    // MARK: - Point-in-Polygon Detection

    /// Check if a coordinate is inside a polygon using ray casting algorithm
    /// This is the standard algorithm for point-in-polygon detection
    static func isPoint(_ point: CLLocationCoordinate2D, insidePolygon polygon: [CLLocationCoordinate2D]) -> Bool {
        guard polygon.count >= 3 else { return false }

        var isInside = false
        var j = polygon.count - 1

        for i in 0..<polygon.count {
            let pi = polygon[i]
            let pj = polygon[j]

            // Ray casting: count how many times a ray from point to infinity crosses polygon edges
            if ((pi.latitude > point.latitude) != (pj.latitude > point.latitude)) &&
                (point.longitude < (pj.longitude - pi.longitude) * (point.latitude - pi.latitude) / (pj.latitude - pi.latitude) + pi.longitude) {
                isInside = !isInside
            }
            j = i
        }

        return isInside
    }

    /// Check if a coordinate is inside any polygon of a UK LAD geometry
    static func isPoint(_ point: CLLocationCoordinate2D, insideLADGeometry geometry: UKLADGeometry) -> Bool {
        let polygons = parsePolygons(from: geometry)

        for polygon in polygons {
            if isPoint(point, insidePolygon: polygon) {
                return true
            }
        }

        return false
    }

    /// Calculate bounding box for a UK LAD geometry (for quick rejection testing)
    static func boundingBox(for geometry: UKLADGeometry) -> (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double)? {
        let polygons = parsePolygons(from: geometry)
        guard !polygons.isEmpty else { return nil }

        var minLat = Double.greatestFiniteMagnitude
        var maxLat = -Double.greatestFiniteMagnitude
        var minLon = Double.greatestFiniteMagnitude
        var maxLon = -Double.greatestFiniteMagnitude

        for polygon in polygons {
            for coord in polygon {
                minLat = min(minLat, coord.latitude)
                maxLat = max(maxLat, coord.latitude)
                minLon = min(minLon, coord.longitude)
                maxLon = max(maxLon, coord.longitude)
            }
        }

        return (minLat, maxLat, minLon, maxLon)
    }

    /// Check if a point is within a bounding box (quick rejection test)
    static func isPoint(_ point: CLLocationCoordinate2D, inBoundingBox box: (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double)) -> Bool {
        return point.latitude >= box.minLat &&
               point.latitude <= box.maxLat &&
               point.longitude >= box.minLon &&
               point.longitude <= box.maxLon
    }
}
