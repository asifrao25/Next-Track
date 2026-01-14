//
//  TourStep.swift
//  Been There
//
//  Tour step model for guided intro tours
//

import SwiftUI

// MARK: - Tour Element Identifiers

enum TourElement: String, CaseIterable {
    // Track tab elements
    case playButton
    case locationButton
    case fullScreenButton
    case frequencyPill
    case geofencePill
    case headerStats

    // Visited tab elements
    case visitedAddButton
    case visitedListButton
    case visitedMyLocationButton
    case visitedGlobeButton
    case visitedMapButton
    case visitedZoomIn
    case visitedZoomOut
    case visitedTopStats
}

// MARK: - Tour Step Model

struct TourStep: Identifiable {
    let id: Int
    let element: TourElement
    let title: String
    let description: String

    // MARK: - Track Tab Steps
    static let trackTabSteps: [TourStep] = [
        TourStep(
            id: 1,
            element: .playButton,
            title: "Start/Stop Tracking",
            description: "Start or stop tracking. Tracking is ON by default."
        ),
        TourStep(
            id: 2,
            element: .locationButton,
            title: "My Location",
            description: "Zoom in to your current location on the map."
        ),
        TourStep(
            id: 3,
            element: .fullScreenButton,
            title: "Full Screen Map",
            description: "View full-screen map showing all historical tracks recorded."
        ),
        TourStep(
            id: 4,
            element: .frequencyPill,
            title: "Tracking Frequency",
            description: "Quickly adjust how often location points are recorded. More options in Settings."
        ),
        TourStep(
            id: 5,
            element: .geofencePill,
            title: "Geofence",
            description: "Add current location as a geofence. Tracking auto-resumes when you leave. Details in Settings."
        ),
        TourStep(
            id: 6,
            element: .headerStats,
            title: "Status Bar",
            description: "Shows current tracking status and geofenced location if present.\n\n💡 You can replay this tour anytime from Settings."
        )
    ]

    // MARK: - Visited Tab Steps
    static let visitedTabSteps: [TourStep] = [
        TourStep(
            id: 1,
            element: .visitedAddButton,
            title: "Add Locations",
            description: "Add places you've visited - automatically, manually, or import from your photos."
        ),
        TourStep(
            id: 2,
            element: .visitedListButton,
            title: "List View",
            description: "See all your visited locations in a list with detailed stats and information."
        ),
        TourStep(
            id: 3,
            element: .visitedMyLocationButton,
            title: "My Location",
            description: "Zoom to your current location on the map."
        ),
        TourStep(
            id: 4,
            element: .visitedGlobeButton,
            title: "3D Globe View",
            description: "Explore your travels on a stunning interactive 3D globe."
        ),
        TourStep(
            id: 5,
            element: .visitedMapButton,
            title: "Map View",
            description: "Switch to the standard map view showing all your visited pins."
        ),
        TourStep(
            id: 6,
            element: .visitedZoomIn,
            title: "Zoom In",
            description: "Zoom in for a closer look at your visited locations."
        ),
        TourStep(
            id: 7,
            element: .visitedZoomOut,
            title: "Zoom Out",
            description: "Zoom out to see more of your travel footprint."
        ),
        TourStep(
            id: 8,
            element: .visitedTopStats,
            title: "Your Stats",
            description: "Quick overview of your total visited locations and cities count.\n\n💡 You can replay this tour anytime from Settings."
        )
    ]
}

// MARK: - Environment Key for Active Tour Element

struct ActiveTourElementKey: EnvironmentKey {
    static let defaultValue: TourElement? = nil
}

extension EnvironmentValues {
    var activeTourElement: TourElement? {
        get { self[ActiveTourElementKey.self] }
        set { self[ActiveTourElementKey.self] = newValue }
    }
}

// MARK: - Anchor Preference for Tour Frames

struct TourAnchorPreferenceKey: PreferenceKey {
    static var defaultValue: [TourElement: Anchor<CGRect>] = [:]

    static func reduce(value: inout [TourElement: Anchor<CGRect>], nextValue: () -> [TourElement: Anchor<CGRect>]) {
        value.merge(nextValue()) { _, new in new }
    }
}

// MARK: - View Extension for Tour Highlighting

extension View {
    func tourHighlight(_ element: TourElement) -> some View {
        self.anchorPreference(key: TourAnchorPreferenceKey.self, value: .bounds) { anchor in
            [element: anchor]
        }
    }
}
