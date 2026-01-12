//
//  iCloudSyncManager.swift
//  Next-track
//
//  Manages iCloud sync for all app data across user's devices
//

import Foundation
import CloudKit
import Combine

/// Manages synchronization of app data across devices using iCloud
class iCloudSyncManager: ObservableObject {
    static let shared = iCloudSyncManager()

    // MARK: - Published Properties

    @Published var isEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "iCloudSyncEnabled")
            if isEnabled && iCloudAvailable {
                Task {
                    await syncAllData()
                }
            }
        }
    }

    @Published var isSyncing: Bool = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?
    @Published var iCloudAvailable: Bool = false
    @Published var syncProgress: Double = 0

    // MARK: - Private Properties

    /// Key-Value Store for small data (settings, config, geofences)
    private let kvStore = NSUbiquitousKeyValueStore.default

    /// CloudKit container for larger data
    private lazy var container: CKContainer = {
        CKContainer(identifier: "iCloud.com.nexttrack.beenthere")
    }()

    private lazy var privateDatabase: CKDatabase = {
        container.privateCloudDatabase
    }()

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Storage Keys (Key-Value Store)

    private enum KVKeys {
        static let serverConfig = "sync_serverConfig"
        static let trackingSettings = "sync_trackingSettings"
        static let trackingStats = "sync_trackingStats"
        static let geofenceZones = "sync_geofenceZones"
        static let lastSyncTimestamp = "sync_lastTimestamp"
    }

    // MARK: - CloudKit Record Types

    private enum RecordType {
        static let trackingSession = "TrackingSession"
        static let visitedCountry = "VisitedCountry"
        static let visitedCity = "VisitedCity"
        static let detectedPlace = "DetectedPlace"
        static let ukCity = "UKCity"
    }

    // MARK: - Initialization

    private init() {
        // Load enabled state (defaults to true if not set)
        let savedEnabled = UserDefaults.standard.object(forKey: "iCloudSyncEnabled") as? Bool ?? true
        _isEnabled = Published(initialValue: savedEnabled)

        checkiCloudAvailability()
        setupObservers()
        loadLastSyncDate()

        // Auto-sync from iCloud on app launch (fetches data from other devices)
        performInitialSync()
    }

    /// Perform initial sync on app launch to fetch any data from other devices
    private func performInitialSync() {
        // Small delay to let iCloud availability check complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self, self.isEnabled, self.iCloudAvailable else { return }

            Task {
                await self.syncAllData()
                print("[iCloudSync] Initial sync completed on app launch")
            }
        }
    }

    // MARK: - iCloud Availability

    func checkiCloudAvailability() {
        container.accountStatus { [weak self] status, error in
            DispatchQueue.main.async {
                switch status {
                case .available:
                    self?.iCloudAvailable = true
                    print("[iCloudSync] iCloud available")
                case .noAccount:
                    self?.iCloudAvailable = false
                    self?.syncError = "No iCloud account. Please sign in to iCloud in Settings."
                    print("[iCloudSync] No iCloud account")
                case .restricted:
                    self?.iCloudAvailable = false
                    self?.syncError = "iCloud access restricted"
                    print("[iCloudSync] iCloud restricted")
                case .couldNotDetermine:
                    self?.iCloudAvailable = false
                    self?.syncError = "Could not determine iCloud status"
                    print("[iCloudSync] Could not determine iCloud status")
                case .temporarilyUnavailable:
                    self?.iCloudAvailable = false
                    self?.syncError = "iCloud temporarily unavailable"
                    print("[iCloudSync] iCloud temporarily unavailable")
                @unknown default:
                    self?.iCloudAvailable = false
                    print("[iCloudSync] Unknown iCloud status")
                }

                if let error = error {
                    print("[iCloudSync] Error checking iCloud: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Setup Observers

    private func setupObservers() {
        // Listen for Key-Value Store changes from other devices
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(kvStoreDidChange(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: kvStore
        )

        // Sync key-value store
        kvStore.synchronize()

        // Listen for CloudKit changes
        setupCloudKitSubscriptions()
    }

    @objc private func kvStoreDidChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let changeReason = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int else {
            return
        }

        print("[iCloudSync] KV Store changed - reason: \(changeReason)")

        // Handle the change
        DispatchQueue.main.async { [weak self] in
            self?.handleRemoteKeyValueChanges(notification)
        }
    }

    private func handleRemoteKeyValueChanges(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let changedKeys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] else {
            return
        }

        print("[iCloudSync] Changed keys: \(changedKeys)")

        for key in changedKeys {
            switch key {
            case KVKeys.serverConfig:
                loadServerConfigFromCloud()
            case KVKeys.trackingSettings:
                loadTrackingSettingsFromCloud()
            case KVKeys.geofenceZones:
                loadGeofenceZonesFromCloud()
            default:
                break
            }
        }

        lastSyncDate = Date()
        saveLastSyncDate()
    }

    // MARK: - CloudKit Subscriptions

    private func setupCloudKitSubscriptions() {
        // Subscribe to changes for each record type
        let recordTypes = [
            RecordType.trackingSession,
            RecordType.visitedCountry,
            RecordType.visitedCity,
            RecordType.detectedPlace,
            RecordType.ukCity
        ]

        for recordType in recordTypes {
            let subscriptionID = "subscription_\(recordType)"
            let subscription = CKQuerySubscription(
                recordType: recordType,
                predicate: NSPredicate(value: true),
                subscriptionID: subscriptionID,
                options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
            )

            let notificationInfo = CKSubscription.NotificationInfo()
            notificationInfo.shouldSendContentAvailable = true
            subscription.notificationInfo = notificationInfo

            privateDatabase.save(subscription) { _, error in
                if let error = error as? CKError, error.code != .serverRejectedRequest {
                    print("[iCloudSync] Subscription error for \(recordType): \(error.localizedDescription)")
                } else {
                    print("[iCloudSync] Subscribed to \(recordType) changes")
                }
            }
        }
    }

    // MARK: - Sync All Data

    /// Sync all app data to/from iCloud
    func syncAllData() async {
        guard iCloudAvailable else {
            print("[iCloudSync] iCloud not available - skipping sync")
            return
        }

        await MainActor.run {
            isSyncing = true
            syncProgress = 0
            syncError = nil
        }

        print("[iCloudSync] Starting full sync...")

        do {
            // Step 1: Sync Key-Value Store data (settings, config, geofences)
            await MainActor.run { syncProgress = 0.1 }
            syncKeyValueData()

            // Step 2: Sync Countries
            await MainActor.run { syncProgress = 0.25 }
            try await syncCountries()

            // Step 3: Sync Cities
            await MainActor.run { syncProgress = 0.4 }
            try await syncCities()

            // Step 4: Sync Places
            await MainActor.run { syncProgress = 0.55 }
            try await syncPlaces()

            // Step 5: Sync UK Cities
            await MainActor.run { syncProgress = 0.7 }
            try await syncUKCities()

            // Step 6: Sync Tracking Sessions
            await MainActor.run { syncProgress = 0.85 }
            try await syncTrackingSessions()

            await MainActor.run {
                syncProgress = 1.0
                lastSyncDate = Date()
                saveLastSyncDate()
                print("[iCloudSync] Full sync completed successfully")
            }

        } catch {
            await MainActor.run {
                syncError = error.localizedDescription
                print("[iCloudSync] Sync error: \(error.localizedDescription)")
            }
        }

        await MainActor.run {
            isSyncing = false
        }
    }

    // MARK: - Key-Value Store Sync (Small Data)

    private func syncKeyValueData() {
        // Force sync
        kvStore.synchronize()

        // Upload local data to cloud
        saveServerConfigToCloud()
        saveTrackingSettingsToCloud()
        saveGeofenceZonesToCloud()

        print("[iCloudSync] Key-Value data synced")
    }

    // MARK: - Server Config Sync

    func saveServerConfigToCloud() {
        let config = SettingsManager.shared.serverConfig
        if let data = try? JSONEncoder().encode(config) {
            kvStore.set(data, forKey: KVKeys.serverConfig)
            kvStore.synchronize()
            print("[iCloudSync] Server config saved to cloud")
        }
    }

    private func loadServerConfigFromCloud() {
        guard let data = kvStore.data(forKey: KVKeys.serverConfig),
              let config = try? JSONDecoder().decode(ServerConfig.self, from: data) else {
            return
        }

        // Merge: Use cloud config if local is not configured
        if !SettingsManager.shared.serverConfig.isValid && config.isValid {
            SettingsManager.shared.updateServerConfig(config)
            print("[iCloudSync] Server config loaded from cloud")
        }
    }

    // MARK: - Tracking Settings Sync

    func saveTrackingSettingsToCloud() {
        let settings = SettingsManager.shared.trackingSettings
        if let data = try? JSONEncoder().encode(settings) {
            kvStore.set(data, forKey: KVKeys.trackingSettings)
            kvStore.synchronize()
            print("[iCloudSync] Tracking settings saved to cloud")
        }
    }

    private func loadTrackingSettingsFromCloud() {
        guard let data = kvStore.data(forKey: KVKeys.trackingSettings),
              let settings = try? JSONDecoder().decode(TrackingSettings.self, from: data) else {
            return
        }

        SettingsManager.shared.updateTrackingSettings(settings)
        print("[iCloudSync] Tracking settings loaded from cloud")
    }

    // MARK: - Geofence Zones Sync

    func saveGeofenceZonesToCloud() {
        let zones = GeofenceManager.shared.zones
        if let data = try? JSONEncoder().encode(zones) {
            kvStore.set(data, forKey: KVKeys.geofenceZones)
            kvStore.synchronize()
            print("[iCloudSync] Geofence zones saved to cloud (\(zones.count) zones)")
        }
    }

    private func loadGeofenceZonesFromCloud() {
        guard let data = kvStore.data(forKey: KVKeys.geofenceZones),
              let cloudZones = try? JSONDecoder().decode([GeofenceZone].self, from: data) else {
            return
        }

        // Merge zones: Add any cloud zones not present locally
        let localZones = GeofenceManager.shared.zones
        let localIds = Set(localZones.map { $0.id })

        for cloudZone in cloudZones {
            if !localIds.contains(cloudZone.id) {
                GeofenceManager.shared.addZone(cloudZone)
                print("[iCloudSync] Added zone from cloud: \(cloudZone.name)")
            }
        }
    }

    // MARK: - CloudKit Sync - Countries

    private func syncCountries() async throws {
        let localCountries = CountriesManager.shared.visitedCountries

        // Fetch existing cloud records
        let query = CKQuery(recordType: RecordType.visitedCountry, predicate: NSPredicate(value: true))
        let (results, _) = try await privateDatabase.records(matching: query)

        var cloudCountryIds = Set<String>()

        // Process cloud records
        for (_, result) in results {
            if case .success(let record) = result {
                if let isoCode = record["isoCode"] as? String {
                    cloudCountryIds.insert(isoCode.uppercased())

                    // Check if this country exists locally
                    if !localCountries.contains(where: { $0.isoCode.uppercased() == isoCode.uppercased() }) {
                        // Import from cloud
                        if let country = decodeCountryFromRecord(record) {
                            await MainActor.run {
                                CountriesManager.shared.visitedCountries.append(country)
                            }
                            print("[iCloudSync] Imported country from cloud: \(country.name)")
                        }
                    }
                }
            }
        }

        // Upload local countries not in cloud
        for country in localCountries {
            if !cloudCountryIds.contains(country.isoCode.uppercased()) {
                let record = encodeCountryToRecord(country)
                try await privateDatabase.save(record)
                print("[iCloudSync] Uploaded country to cloud: \(country.name)")
            }
        }

        print("[iCloudSync] Countries sync complete")
    }

    private func encodeCountryToRecord(_ country: VisitedCountry) -> CKRecord {
        let record = CKRecord(recordType: RecordType.visitedCountry, recordID: CKRecord.ID(recordName: country.id.uuidString))
        record["id"] = country.id.uuidString
        record["name"] = country.name
        record["isoCode"] = country.isoCode
        record["continent"] = country.continent
        record["isAutoDetected"] = country.isAutoDetected
        record["isManuallyAdded"] = country.isManuallyAdded
        record["firstVisitDate"] = country.firstVisitDate
        record["lastVisitDate"] = country.lastVisitDate
        record["autoDetectedCityCount"] = country.autoDetectedCityCount
        record["totalTimeSpent"] = country.totalTimeSpent
        record["createdAt"] = country.createdAt
        record["updatedAt"] = country.updatedAt

        // Encode trips as JSON
        if let tripsData = try? JSONEncoder().encode(country.trips) {
            record["tripsData"] = tripsData
        }

        // Encode visit sessions as JSON
        if let sessionsData = try? JSONEncoder().encode(country.visitSessions) {
            record["visitSessionsData"] = sessionsData
        }

        return record
    }

    private func decodeCountryFromRecord(_ record: CKRecord) -> VisitedCountry? {
        guard let idString = record["id"] as? String,
              let id = UUID(uuidString: idString),
              let name = record["name"] as? String,
              let isoCode = record["isoCode"] as? String else {
            return nil
        }

        var trips: [CountryTrip] = []
        if let tripsData = record["tripsData"] as? Data {
            trips = (try? JSONDecoder().decode([CountryTrip].self, from: tripsData)) ?? []
        }

        var visitSessions: [VisitSession] = []
        if let sessionsData = record["visitSessionsData"] as? Data {
            visitSessions = (try? JSONDecoder().decode([VisitSession].self, from: sessionsData)) ?? []
        }

        return VisitedCountry(
            id: id,
            name: name,
            isoCode: isoCode,
            continent: record["continent"] as? String,
            isAutoDetected: record["isAutoDetected"] as? Bool ?? false,
            isManuallyAdded: record["isManuallyAdded"] as? Bool ?? false,
            firstVisitDate: record["firstVisitDate"] as? Date,
            lastVisitDate: record["lastVisitDate"] as? Date,
            trips: trips,
            autoDetectedCityCount: record["autoDetectedCityCount"] as? Int ?? 0,
            totalTimeSpent: record["totalTimeSpent"] as? TimeInterval ?? 0,
            visitSessions: visitSessions
        )
    }

    // MARK: - CloudKit Sync - Cities

    private func syncCities() async throws {
        let localCities = CityTracker.shared.visitedCities

        // Fetch existing cloud records
        let query = CKQuery(recordType: RecordType.visitedCity, predicate: NSPredicate(value: true))
        let (results, _) = try await privateDatabase.records(matching: query)

        var cloudCityKeys = Set<String>()

        // Process cloud records
        for (_, result) in results {
            if case .success(let record) = result {
                if let name = record["name"] as? String,
                   let country = record["country"] as? String {
                    let key = "\(name)_\(country)"
                    cloudCityKeys.insert(key)

                    // Check if this city exists locally
                    if !localCities.contains(where: { $0.name == name && $0.country == country }) {
                        if let city = decodeCityFromRecord(record) {
                            await MainActor.run {
                                CityTracker.shared.visitedCities.append(city)
                            }
                            print("[iCloudSync] Imported city from cloud: \(city.name)")
                        }
                    }
                }
            }
        }

        // Upload local cities not in cloud
        for city in localCities {
            let key = "\(city.name)_\(city.country)"
            if !cloudCityKeys.contains(key) {
                let record = encodeCityToRecord(city)
                try await privateDatabase.save(record)
                print("[iCloudSync] Uploaded city to cloud: \(city.name)")
            }
        }

        print("[iCloudSync] Cities sync complete")
    }

    private func encodeCityToRecord(_ city: VisitedCity) -> CKRecord {
        let record = CKRecord(recordType: RecordType.visitedCity, recordID: CKRecord.ID(recordName: city.id.uuidString))
        record["id"] = city.id.uuidString
        record["name"] = city.name
        record["state"] = city.state
        record["country"] = city.country
        record["countryCode"] = city.countryCode
        record["latitude"] = city.latitude
        record["longitude"] = city.longitude
        record["firstVisitDate"] = city.firstVisitDate
        record["lastVisitDate"] = city.lastVisitDate
        record["visitCount"] = city.visitCount
        record["totalPointsRecorded"] = city.totalPointsRecorded
        return record
    }

    private func decodeCityFromRecord(_ record: CKRecord) -> VisitedCity? {
        guard let idString = record["id"] as? String,
              let id = UUID(uuidString: idString),
              let name = record["name"] as? String,
              let country = record["country"] as? String,
              let latitude = record["latitude"] as? Double,
              let longitude = record["longitude"] as? Double else {
            return nil
        }

        return VisitedCity(
            id: id,
            name: name,
            state: record["state"] as? String,
            country: country,
            countryCode: record["countryCode"] as? String,
            firstVisitDate: record["firstVisitDate"] as? Date ?? Date(),
            lastVisitDate: record["lastVisitDate"] as? Date ?? Date(),
            visitCount: record["visitCount"] as? Int ?? 1,
            totalPointsRecorded: record["totalPointsRecorded"] as? Int ?? 1,
            latitude: latitude,
            longitude: longitude
        )
    }

    // MARK: - CloudKit Sync - Places

    private func syncPlaces() async throws {
        let localPlaces = PlaceDetectionManager.shared.detectedPlaces

        // Fetch existing cloud records
        let query = CKQuery(recordType: RecordType.detectedPlace, predicate: NSPredicate(value: true))
        let (results, _) = try await privateDatabase.records(matching: query)

        var cloudPlaceIds = Set<UUID>()

        // Process cloud records
        for (_, result) in results {
            if case .success(let record) = result {
                if let idString = record["id"] as? String,
                   let id = UUID(uuidString: idString) {
                    cloudPlaceIds.insert(id)

                    // Check if this place exists locally
                    if !localPlaces.contains(where: { $0.id == id }) {
                        if let place = decodePlaceFromRecord(record) {
                            await MainActor.run {
                                PlaceDetectionManager.shared.detectedPlaces.append(place)
                            }
                            print("[iCloudSync] Imported place from cloud: \(place.name ?? "Unknown")")
                        }
                    }
                }
            }
        }

        // Upload local places not in cloud
        for place in localPlaces {
            if !cloudPlaceIds.contains(place.id) {
                let record = encodePlaceToRecord(place)
                try await privateDatabase.save(record)
                print("[iCloudSync] Uploaded place to cloud: \(place.name ?? "Unknown")")
            }
        }

        print("[iCloudSync] Places sync complete")
    }

    private func encodePlaceToRecord(_ place: DetectedPlace) -> CKRecord {
        let record = CKRecord(recordType: RecordType.detectedPlace, recordID: CKRecord.ID(recordName: place.id.uuidString))
        record["id"] = place.id.uuidString
        record["name"] = place.name
        record["latitude"] = place.latitude
        record["longitude"] = place.longitude
        record["radius"] = place.radius
        record["category"] = place.category.rawValue
        record["confidence"] = place.confidence
        record["isConfirmed"] = place.isConfirmed
        record["streetAddress"] = place.streetAddress
        record["createdAt"] = place.createdAt
        record["lastVisitedAt"] = place.lastVisitedAt

        // Encode visit history as JSON
        if let visitData = try? JSONEncoder().encode(place.visitHistory) {
            record["visitHistoryData"] = visitData
        }

        return record
    }

    private func decodePlaceFromRecord(_ record: CKRecord) -> DetectedPlace? {
        guard let idString = record["id"] as? String,
              let id = UUID(uuidString: idString),
              let latitude = record["latitude"] as? Double,
              let longitude = record["longitude"] as? Double else {
            return nil
        }

        var visitHistory: [PlaceVisit] = []
        if let visitData = record["visitHistoryData"] as? Data {
            visitHistory = (try? JSONDecoder().decode([PlaceVisit].self, from: visitData)) ?? []
        }

        let categoryString = record["category"] as? String ?? "other"
        let category = PlaceCategory(rawValue: categoryString) ?? .other

        return DetectedPlace(
            id: id,
            latitude: latitude,
            longitude: longitude,
            radius: record["radius"] as? Double ?? 50,
            name: record["name"] as? String,
            streetAddress: record["streetAddress"] as? String,
            category: category,
            confidence: record["confidence"] as? Double ?? 0.5,
            visitHistory: visitHistory,
            createdAt: record["createdAt"] as? Date ?? Date(),
            lastVisitedAt: record["lastVisitedAt"] as? Date ?? Date(),
            isConfirmed: record["isConfirmed"] as? Bool ?? false
        )
    }

    // MARK: - CloudKit Sync - UK Cities

    private func syncUKCities() async throws {
        let localUKCities = UKCitiesManager.shared.visitedCities

        // Fetch existing cloud records
        let query = CKQuery(recordType: RecordType.ukCity, predicate: NSPredicate(value: true))
        let (results, _) = try await privateDatabase.records(matching: query)

        var cloudCityNames = Set<String>()

        // Process cloud records
        for (_, result) in results {
            if case .success(let record) = result {
                if let name = record["name"] as? String {
                    cloudCityNames.insert(name.lowercased())

                    // Check if this UK city exists locally
                    if !localUKCities.contains(where: { $0.name.lowercased() == name.lowercased() }) {
                        if let city = decodeUKCityFromRecord(record) {
                            await MainActor.run {
                                UKCitiesManager.shared.visitedCities.append(city)
                            }
                            print("[iCloudSync] Imported UK city from cloud: \(city.name)")
                        }
                    }
                }
            }
        }

        // Upload local UK cities not in cloud
        for city in localUKCities {
            if !cloudCityNames.contains(city.name.lowercased()) {
                let record = encodeUKCityToRecord(city)
                try await privateDatabase.save(record)
                print("[iCloudSync] Uploaded UK city to cloud: \(city.name)")
            }
        }

        print("[iCloudSync] UK Cities sync complete")
    }

    private func encodeUKCityToRecord(_ city: VisitedUKCity) -> CKRecord {
        let record = CKRecord(recordType: RecordType.ukCity, recordID: CKRecord.ID(recordName: city.id.uuidString))
        record["id"] = city.id.uuidString
        record["name"] = city.name
        record["region"] = city.region
        record["latitude"] = city.latitude
        record["longitude"] = city.longitude
        record["radius"] = city.radius
        record["firstVisitDate"] = city.firstVisitDate
        record["lastVisitDate"] = city.lastVisitDate
        record["visitCount"] = city.visitCount

        // Encode places array as JSON
        if let placesData = try? JSONEncoder().encode(city.places) {
            record["placesData"] = placesData
        }

        return record
    }

    private func decodeUKCityFromRecord(_ record: CKRecord) -> VisitedUKCity? {
        guard let idString = record["id"] as? String,
              let id = UUID(uuidString: idString),
              let name = record["name"] as? String,
              let region = record["region"] as? String,
              let latitude = record["latitude"] as? Double,
              let longitude = record["longitude"] as? Double else {
            return nil
        }

        var places: [String] = []
        if let placesData = record["placesData"] as? Data {
            places = (try? JSONDecoder().decode([String].self, from: placesData)) ?? []
        }

        return VisitedUKCity(
            id: id,
            name: name,
            region: region,
            latitude: latitude,
            longitude: longitude,
            radius: record["radius"] as? Double ?? 5000,
            visitCount: record["visitCount"] as? Int ?? 1,
            firstVisitDate: record["firstVisitDate"] as? Date,
            lastVisitDate: record["lastVisitDate"] as? Date,
            places: places
        )
    }

    // MARK: - CloudKit Sync - Tracking Sessions

    private func syncTrackingSessions() async throws {
        let localSessions = TrackingHistoryManager.shared.sessions

        // Fetch existing cloud records (just IDs to check existence)
        let query = CKQuery(recordType: RecordType.trackingSession, predicate: NSPredicate(value: true))
        let (results, _) = try await privateDatabase.records(matching: query)

        var cloudSessionIds = Set<UUID>()

        // Process cloud records
        for (_, result) in results {
            if case .success(let record) = result {
                if let idString = record["id"] as? String,
                   let id = UUID(uuidString: idString) {
                    cloudSessionIds.insert(id)

                    // Check if this session exists locally
                    if !localSessions.contains(where: { $0.id == id }) {
                        if let session = decodeSessionFromRecord(record) {
                            await MainActor.run {
                                TrackingHistoryManager.shared.sessions.append(session)
                            }
                            print("[iCloudSync] Imported session from cloud: \(session.name)")
                        }
                    }
                }
            }
        }

        // Upload local sessions not in cloud (batch to avoid rate limits)
        var uploadCount = 0
        for session in localSessions {
            if !cloudSessionIds.contains(session.id) {
                let record = encodeSessionToRecord(session)
                try await privateDatabase.save(record)
                uploadCount += 1

                // Small delay to avoid rate limiting
                if uploadCount % 10 == 0 {
                    try await Task.sleep(nanoseconds: 100_000_000) // 100ms
                }
            }
        }

        if uploadCount > 0 {
            print("[iCloudSync] Uploaded \(uploadCount) sessions to cloud")
        }

        print("[iCloudSync] Sessions sync complete")
    }

    private func encodeSessionToRecord(_ session: TrackingSession) -> CKRecord {
        let record = CKRecord(recordType: RecordType.trackingSession, recordID: CKRecord.ID(recordName: session.id.uuidString))
        record["id"] = session.id.uuidString
        record["startTime"] = session.startTime
        record["endTime"] = session.endTime
        record["pointsCount"] = session.pointsCount
        record["totalDistance"] = session.totalDistance

        // Encode locations as JSON (can be large!)
        if let locationsData = try? JSONEncoder().encode(session.locations) {
            // Store as CKAsset if too large for record field
            if locationsData.count > 1_000_000 { // > 1MB
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(session.id.uuidString)_locations.json")
                try? locationsData.write(to: tempURL)
                record["locationsAsset"] = CKAsset(fileURL: tempURL)
            } else {
                record["locationsData"] = locationsData
            }
        }

        return record
    }

    private func decodeSessionFromRecord(_ record: CKRecord) -> TrackingSession? {
        guard let idString = record["id"] as? String,
              let id = UUID(uuidString: idString),
              let startTime = record["startTime"] as? Date else {
            return nil
        }

        var locations: [StoredLocation] = []

        // Try loading from asset first, then from data field
        if let asset = record["locationsAsset"] as? CKAsset,
           let fileURL = asset.fileURL,
           let data = try? Data(contentsOf: fileURL) {
            locations = (try? JSONDecoder().decode([StoredLocation].self, from: data)) ?? []
        } else if let locationsData = record["locationsData"] as? Data {
            locations = (try? JSONDecoder().decode([StoredLocation].self, from: locationsData)) ?? []
        }

        return TrackingSession(
            id: id,
            startTime: startTime,
            endTime: record["endTime"] as? Date,
            pointsCount: record["pointsCount"] as? Int ?? locations.count,
            totalDistance: record["totalDistance"] as? Double ?? 0,
            locations: locations
        )
    }

    // MARK: - Last Sync Date Persistence

    private func loadLastSyncDate() {
        if let timestamp = kvStore.object(forKey: KVKeys.lastSyncTimestamp) as? Date {
            lastSyncDate = timestamp
        }
    }

    private func saveLastSyncDate() {
        if let date = lastSyncDate {
            kvStore.set(date, forKey: KVKeys.lastSyncTimestamp)
            kvStore.synchronize()
        }
    }

    // MARK: - Manual Sync Triggers

    /// Call this when countries data changes locally
    func syncCountriesNow() {
        guard iCloudAvailable else { return }
        Task {
            do {
                try await syncCountries()
            } catch {
                print("[iCloudSync] Countries sync error: \(error.localizedDescription)")
            }
        }
    }

    /// Call this when cities data changes locally
    func syncCitiesNow() {
        guard iCloudAvailable else { return }
        Task {
            do {
                try await syncCities()
            } catch {
                print("[iCloudSync] Cities sync error: \(error.localizedDescription)")
            }
        }
    }

    /// Call this when places data changes locally
    func syncPlacesNow() {
        guard iCloudAvailable else { return }
        Task {
            do {
                try await syncPlaces()
            } catch {
                print("[iCloudSync] Places sync error: \(error.localizedDescription)")
            }
        }
    }

    /// Call this when geofence zones change locally
    func syncGeofencesNow() {
        saveGeofenceZonesToCloud()
    }

    /// Call this when settings change locally
    func syncSettingsNow() {
        saveServerConfigToCloud()
        saveTrackingSettingsToCloud()
    }

    /// Call this when UK cities data changes locally
    func syncUKCitiesNow() {
        guard iCloudAvailable else { return }
        Task {
            do {
                try await syncUKCities()
            } catch {
                print("[iCloudSync] UK Cities sync error: \(error.localizedDescription)")
            }
        }
    }

    /// Call this when a tracking session ends
    func syncSessionNow(_ session: TrackingSession) {
        guard iCloudAvailable else { return }
        Task {
            do {
                let record = encodeSessionToRecord(session)
                try await privateDatabase.save(record)
                print("[iCloudSync] Session synced: \(session.name)")
            } catch {
                print("[iCloudSync] Session sync error: \(error.localizedDescription)")
            }
        }
    }
}
