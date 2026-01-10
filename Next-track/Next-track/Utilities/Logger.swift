//
//  Logger.swift
//  Next-track
//
//  Centralized logging utility using Apple's unified logging system (os_log)
//  Debug prints are compiled out in Release builds for performance
//

import OSLog

/// Centralized logging for Next-track app
/// Uses Apple's unified logging system with category-based filtering
struct AppLogger {

    // MARK: - Subsystem

    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.nexttrack"

    // MARK: - Category Loggers

    /// Location tracking and GPS updates
    static let location = Logger(subsystem: subsystem, category: "Location")

    /// Geofence monitoring and zone management
    static let geofence = Logger(subsystem: subsystem, category: "Geofence")

    /// PhoneTrack API communication
    static let api = Logger(subsystem: subsystem, category: "API")

    /// Tracking state and session management
    static let tracking = Logger(subsystem: subsystem, category: "Tracking")

    /// Auto-export and GPX file operations
    static let export = Logger(subsystem: subsystem, category: "Export")

    /// Place detection and POI tracking
    static let places = Logger(subsystem: subsystem, category: "Places")

    /// City tracking and detection
    static let cities = Logger(subsystem: subsystem, category: "Cities")

    /// Country tracking and GeoJSON
    static let countries = Logger(subsystem: subsystem, category: "Countries")

    /// UK cities and LAD boundaries
    static let ukCities = Logger(subsystem: subsystem, category: "UKCities")

    /// Session history and persistence
    static let history = Logger(subsystem: subsystem, category: "History")

    /// Network connectivity monitoring
    static let connection = Logger(subsystem: subsystem, category: "Connection")

    /// Motion and activity detection
    static let motion = Logger(subsystem: subsystem, category: "Motion")

    /// Background tasks and scheduling
    static let background = Logger(subsystem: subsystem, category: "Background")

    /// UI and view lifecycle
    static let ui = Logger(subsystem: subsystem, category: "UI")

    /// Settings and configuration
    static let settings = Logger(subsystem: subsystem, category: "Settings")

    /// Insights and analytics
    static let insights = Logger(subsystem: subsystem, category: "Insights")

    // MARK: - Convenience Methods

    /// Debug-only logging - compiled out in Release builds
    /// Use for verbose debugging information that shouldn't appear in production
    static func debug(_ message: String, logger: Logger = location) {
        #if DEBUG
        logger.debug("\(message, privacy: .public)")
        #endif
    }

    /// Log info level message
    static func info(_ message: String, logger: Logger = location) {
        logger.info("\(message, privacy: .public)")
    }

    /// Log notice level message (more important than info)
    static func notice(_ message: String, logger: Logger = location) {
        logger.notice("\(message, privacy: .public)")
    }

    /// Log error level message
    static func error(_ message: String, logger: Logger = location) {
        logger.error("\(message, privacy: .public)")
    }

    /// Log fault level message (critical failures)
    static func fault(_ message: String, logger: Logger = location) {
        logger.fault("\(message, privacy: .public)")
    }
}

// MARK: - Debug Print Wrapper

/// Debug-only print that is compiled out in Release builds
/// Drop-in replacement for print() statements
@inlinable
func debugPrint(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    #if DEBUG
    let output = items.map { "\($0)" }.joined(separator: separator)
    print(output, terminator: terminator)
    #endif
}
