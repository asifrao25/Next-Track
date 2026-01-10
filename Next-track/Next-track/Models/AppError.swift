//
//  AppError.swift
//  Next-track
//
//  Unified error types for the application
//  Provides user-friendly error messages and recovery suggestions
//

import Foundation

/// Unified error types for Next-track app
/// Conforms to Error, LocalizedError for error descriptions, and Identifiable for SwiftUI
enum AppError: Error, LocalizedError, Identifiable, Equatable {

    // MARK: - Location Errors

    /// Location permission was denied by user
    case locationPermissionDenied

    /// Location permission is restricted (parental controls, MDM, etc.)
    case locationPermissionRestricted

    /// Location update failed
    case locationUpdateFailed(String)

    /// Location services are disabled system-wide
    case locationServicesDisabled

    // MARK: - Network/API Errors

    /// Server is not configured
    case serverNotConfigured

    /// Failed to connect to server
    case serverConnectionFailed(String)

    /// Server returned an error response
    case serverResponseError(Int)

    /// Network is unavailable
    case networkUnavailable

    // MARK: - Geocoding Errors

    /// Geocoding request failed
    case geocodingFailed(String)

    /// Geocoding rate limited by Apple
    case geocodingRateLimited

    // MARK: - Data Persistence Errors

    /// Failed to save data
    case dataSaveFailed(String, String)

    /// Failed to load data
    case dataLoadFailed(String, String)

    /// Data is corrupted
    case dataCorrupted(String)

    // MARK: - Geofence Errors

    /// Geofence monitoring failed
    case geofenceMonitoringFailed(String)

    /// Geofence limit reached (iOS allows max 20 regions)
    case geofenceLimitReached

    /// Geofence permission required
    case geofencePermissionRequired

    // MARK: - Export Errors

    /// Export operation failed
    case exportFailed(String)

    /// Cannot access export folder
    case exportFolderAccessDenied

    // MARK: - Background Task Errors

    /// Background task scheduling failed
    case backgroundTaskSchedulingFailed(String)

    /// Background task expired before completion
    case backgroundTaskExpired

    // MARK: - General Errors

    /// Unknown error with message
    case unknown(String)

    // MARK: - Identifiable

    var id: String {
        switch self {
        case .locationPermissionDenied: return "locationPermissionDenied"
        case .locationPermissionRestricted: return "locationPermissionRestricted"
        case .locationUpdateFailed(let msg): return "locationUpdateFailed-\(msg)"
        case .locationServicesDisabled: return "locationServicesDisabled"
        case .serverNotConfigured: return "serverNotConfigured"
        case .serverConnectionFailed(let msg): return "serverConnectionFailed-\(msg)"
        case .serverResponseError(let code): return "serverResponseError-\(code)"
        case .networkUnavailable: return "networkUnavailable"
        case .geocodingFailed(let msg): return "geocodingFailed-\(msg)"
        case .geocodingRateLimited: return "geocodingRateLimited"
        case .dataSaveFailed(let type, _): return "dataSaveFailed-\(type)"
        case .dataLoadFailed(let type, _): return "dataLoadFailed-\(type)"
        case .dataCorrupted(let type): return "dataCorrupted-\(type)"
        case .geofenceMonitoringFailed(let msg): return "geofenceMonitoringFailed-\(msg)"
        case .geofenceLimitReached: return "geofenceLimitReached"
        case .geofencePermissionRequired: return "geofencePermissionRequired"
        case .exportFailed(let msg): return "exportFailed-\(msg)"
        case .exportFolderAccessDenied: return "exportFolderAccessDenied"
        case .backgroundTaskSchedulingFailed(let msg): return "backgroundTaskSchedulingFailed-\(msg)"
        case .backgroundTaskExpired: return "backgroundTaskExpired"
        case .unknown(let msg): return "unknown-\(msg)"
        }
    }

    // MARK: - LocalizedError

    var errorDescription: String? {
        switch self {
        case .locationPermissionDenied:
            return "Location Permission Denied"
        case .locationPermissionRestricted:
            return "Location Permission Restricted"
        case .locationUpdateFailed:
            return "Location Update Failed"
        case .locationServicesDisabled:
            return "Location Services Disabled"
        case .serverNotConfigured:
            return "Server Not Configured"
        case .serverConnectionFailed:
            return "Server Connection Failed"
        case .serverResponseError(let code):
            return "Server Error (\(code))"
        case .networkUnavailable:
            return "Network Unavailable"
        case .geocodingFailed:
            return "Geocoding Failed"
        case .geocodingRateLimited:
            return "Geocoding Rate Limited"
        case .dataSaveFailed(let type, _):
            return "Failed to Save \(type)"
        case .dataLoadFailed(let type, _):
            return "Failed to Load \(type)"
        case .dataCorrupted(let type):
            return "\(type) Data Corrupted"
        case .geofenceMonitoringFailed:
            return "Geofence Monitoring Failed"
        case .geofenceLimitReached:
            return "Geofence Limit Reached"
        case .geofencePermissionRequired:
            return "Geofence Permission Required"
        case .exportFailed:
            return "Export Failed"
        case .exportFolderAccessDenied:
            return "Export Folder Access Denied"
        case .backgroundTaskSchedulingFailed:
            return "Background Task Failed"
        case .backgroundTaskExpired:
            return "Background Task Expired"
        case .unknown:
            return "An Error Occurred"
        }
    }

    var failureReason: String? {
        switch self {
        case .locationPermissionDenied:
            return "You have denied location access for this app."
        case .locationPermissionRestricted:
            return "Location access is restricted on this device."
        case .locationUpdateFailed(let msg):
            return msg
        case .locationServicesDisabled:
            return "Location Services are turned off in Settings."
        case .serverNotConfigured:
            return "No PhoneTrack server has been configured."
        case .serverConnectionFailed(let msg):
            return msg
        case .serverResponseError(let code):
            return "The server returned status code \(code)."
        case .networkUnavailable:
            return "No internet connection available."
        case .geocodingFailed(let msg):
            return msg
        case .geocodingRateLimited:
            return "Too many geocoding requests. Please wait."
        case .dataSaveFailed(_, let msg):
            return msg
        case .dataLoadFailed(_, let msg):
            return msg
        case .dataCorrupted(let type):
            return "\(type) data could not be read."
        case .geofenceMonitoringFailed(let msg):
            return msg
        case .geofenceLimitReached:
            return "iOS limits apps to 20 geofence regions."
        case .geofencePermissionRequired:
            return "Always-on location permission is required for geofences."
        case .exportFailed(let msg):
            return msg
        case .exportFolderAccessDenied:
            return "Cannot access the selected export folder."
        case .backgroundTaskSchedulingFailed(let msg):
            return msg
        case .backgroundTaskExpired:
            return "The background task ran out of time."
        case .unknown(let msg):
            return msg
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .locationPermissionDenied, .locationPermissionRestricted:
            return "Open Settings to grant location permission."
        case .locationServicesDisabled:
            return "Open Settings > Privacy > Location Services."
        case .serverNotConfigured:
            return "Go to Settings and configure your PhoneTrack server."
        case .serverConnectionFailed, .networkUnavailable:
            return "Check your internet connection and try again."
        case .serverResponseError:
            return "Check your server configuration and try again."
        case .geocodingRateLimited:
            return "Geocoding will resume automatically in a few minutes."
        case .geofenceLimitReached:
            return "Remove some existing geofences to add new ones."
        case .geofencePermissionRequired:
            return "Grant 'Always' location permission in Settings."
        case .exportFolderAccessDenied:
            return "Select a different export folder in Settings."
        default:
            return nil
        }
    }

    // MARK: - Severity

    /// Error severity for UI display
    enum Severity {
        case info       // Blue, informational
        case warning    // Orange, needs attention
        case error      // Red, action required
        case critical   // Red pulsing, blocking issue
    }

    var severity: Severity {
        switch self {
        case .geocodingRateLimited:
            return .info
        case .networkUnavailable, .serverConnectionFailed, .geocodingFailed:
            return .warning
        case .locationPermissionDenied, .locationPermissionRestricted,
             .locationServicesDisabled, .serverNotConfigured,
             .geofencePermissionRequired:
            return .critical
        default:
            return .error
        }
    }

    // MARK: - Actions

    /// Whether this error can be recovered by user action
    var isRecoverable: Bool {
        switch self {
        case .locationPermissionDenied, .locationPermissionRestricted,
             .locationServicesDisabled, .serverNotConfigured,
             .geofencePermissionRequired, .exportFolderAccessDenied,
             .geofenceLimitReached:
            return true
        default:
            return false
        }
    }

    /// Whether this error should show an "Open Settings" action
    var shouldShowOpenSettings: Bool {
        switch self {
        case .locationPermissionDenied, .locationPermissionRestricted,
             .locationServicesDisabled, .geofencePermissionRequired:
            return true
        default:
            return false
        }
    }

    // MARK: - Equatable

    static func == (lhs: AppError, rhs: AppError) -> Bool {
        lhs.id == rhs.id
    }
}
