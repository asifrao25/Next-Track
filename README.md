# Been There

A comprehensive iOS location tracking app built with SwiftUI that helps you track your journeys, discover new places, and visualize your travel history.

## Features

### Location Tracking
- **Real-time GPS tracking** with configurable update intervals
- **Background location updates** for continuous tracking
- **Battery-efficient modes** with smart accuracy adjustments
- **Geofence-based auto start/stop** - tracking starts when you leave home
- **Track sessions** with detailed history and statistics

### Countries Globe
- **Interactive 3D globe** showing visited countries
- **Country boundaries** rendered from GeoJSON data
- **Automatic country detection** when visiting new places
- **Visit statistics** including first/last visit dates

### UK Cities Map
- **391 UK Local Authority Districts (LADs)** with accurate boundaries
- **Automatic city detection** using point-in-polygon algorithm
- **Manual addition** via search or long-press on map
- **Smooth polygon rendering** with Douglas-Peucker simplification
- **Visit tracking** with daily visit counts
- **Push notifications** for new area discoveries

### Cities & Places
- **Global city tracking** via reverse geocoding
- **Place detection** for frequently visited locations
- **Visit history** with timestamps and statistics

### Insights
- **Daily records** showing tracking activity
- **Statistics dashboard** with total distance, sessions, and more
- **Visual analytics** of your movement patterns

### Data Export
- **GPX export** for tracks
- **CSV export** for location data
- **Auto-export** to iCloud or local storage

## Technical Details

### Architecture
- **SwiftUI** for modern declarative UI
- **Combine** for reactive data flow
- **CoreLocation** for GPS and geofencing
- **MapKit** for map rendering with custom overlays
- **UserDefaults** for local persistence
- **UserNotifications** for discovery alerts

### Key Components

| Component | Description |
|-----------|-------------|
| `LocationManager` | Handles GPS updates and permissions |
| `TrackingStateManager` | Coordinates tracking start/stop with debouncing |
| `UKCitiesManager` | Manages UK LAD detection and persistence |
| `CountriesManager` | Tracks visited countries from city data |
| `CityTracker` | Global city detection via geocoding |
| `GeofenceManager` | Home-based auto tracking triggers |
| `GeoJSONParser` | Parses country and LAD boundary data |

### UK Cities Detection

The UK map uses Local Authority District boundaries from ONS (Office for National Statistics):
- **391 LADs** covering England, Wales, Scotland, and Northern Ireland
- **Point-in-polygon detection** with bounding box optimization
- **~991KB GeoJSON** simplified from original ~35MB data
- **Douglas-Peucker algorithm** for smooth boundary rendering

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+

## Installation

1. Clone the repository
2. Open `Been There.xcodeproj` in Xcode
3. Build and run on your device (simulator has limited location features)

## Privacy

- Location data is stored locally on device
- Optional sync to your own PhoneTrack server
- No third-party analytics or tracking
- Full control over your data with export options

## License

Private project - All rights reserved.

## Author

Built with SwiftUI and CoreLocation for personal travel tracking.
