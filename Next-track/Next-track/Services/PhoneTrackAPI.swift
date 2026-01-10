//
//  PhoneTrackAPI.swift
//  Next-track
//
//  HTTP requests to Nextcloud PhoneTrack server
//

import Foundation
import Combine
import CoreLocation

enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidConfiguration
    case networkError(Error)
    case serverError(Int)
    case unknownError

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .invalidConfiguration:
            return "Server not configured"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serverError(let code):
            return "Server error: HTTP \(code)"
        case .unknownError:
            return "Unknown error occurred"
        }
    }
}

enum APIResult {
    case success
    case failure(APIError)
}

class PhoneTrackAPI: ObservableObject {
    static let shared = PhoneTrackAPI()

    @Published var lastResult: APIResult?
    @Published var isSending: Bool = false
    @Published var connectionStatus: ConnectionStatus = .unknown

    enum ConnectionStatus {
        case unknown
        case connected
        case disconnected
        case error
    }

    private let session: URLSession
    private var currentTask: URLSessionDataTask?

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
    }

    // MARK: - Send Location

    func sendLocation(_ location: CLLocation, completion: @escaping (APIResult) -> Void) {
        let batteryLevel = BatteryMonitor.shared.batteryLevel
        let locationData = LocationData(from: location, batteryLevel: batteryLevel)
        sendLocationData(locationData, completion: completion)
    }

    func sendLocationData(_ locationData: LocationData, completion: @escaping (APIResult) -> Void) {
        let config = SettingsManager.shared.serverConfig
        let settings = SettingsManager.shared.trackingSettings

        #if DEBUG
        print("[PhoneTrackAPI] Attempting to send location...")
        print("[PhoneTrackAPI] Server URL: \(config.serverURL)")
        print("[PhoneTrackAPI] Token: \(config.token.prefix(8))...")
        print("[PhoneTrackAPI] Device: \(config.deviceName)")
        print("[PhoneTrackAPI] Config valid: \(config.isValid)")
        #endif

        guard config.isValid else {
            #if DEBUG
            print("[PhoneTrackAPI] ERROR: Invalid configuration!")
            #endif
            let result = APIResult.failure(.invalidConfiguration)
            DispatchQueue.main.async {
                self.lastResult = result
                self.connectionStatus = .error
            }
            completion(result)
            return
        }

        #if DEBUG
        print("[PhoneTrackAPI] Logging URL base: \(config.loggingURL)")
        #endif

        guard let url = locationData.buildURL(baseURL: config.loggingURL, settings: settings) else {
            #if DEBUG
            print("[PhoneTrackAPI] ERROR: Failed to build URL!")
            #endif
            let result = APIResult.failure(.invalidURL)
            DispatchQueue.main.async {
                self.lastResult = result
                self.connectionStatus = .error
            }
            completion(result)
            return
        }

        #if DEBUG
        print("[PhoneTrackAPI] Full URL: \(url.absoluteString)")
        #endif

        DispatchQueue.main.async {
            self.isSending = true
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Next-track iOS", forHTTPHeaderField: "User-Agent")

        // Capture start time for latency measurement
        let requestStartTime = CFAbsoluteTimeGetCurrent()

        currentTask = session.dataTask(with: request) { [weak self] data, response, error in
            let requestEndTime = CFAbsoluteTimeGetCurrent()
            let latencyMs = (requestEndTime - requestStartTime) * 1000 // Convert to milliseconds

            DispatchQueue.main.async {
                self?.isSending = false

                if let error = error {
                    #if DEBUG
                    print("[PhoneTrackAPI] Network error: \(error.localizedDescription)")
                    #endif
                    let result = APIResult.failure(.networkError(error))
                    self?.lastResult = result
                    self?.connectionStatus = .disconnected
                    completion(result)
                    return
                }

                if let httpResponse = response as? HTTPURLResponse {
                    #if DEBUG
                    print("[PhoneTrackAPI] Response: HTTP \(httpResponse.statusCode)")
                    #endif
                    if (200...299).contains(httpResponse.statusCode) {
                        #if DEBUG
                        print("[PhoneTrackAPI] ✅ SUCCESS - Location sent!")
                        #endif

                        // Record latency on successful requests
                        ConnectionMonitor.shared.recordLatency(latencyMs)

                        let result = APIResult.success
                        self?.lastResult = result
                        self?.connectionStatus = .connected
                        completion(result)
                    } else {
                        #if DEBUG
                        print("[PhoneTrackAPI] ❌ Server error: \(httpResponse.statusCode)")
                        #endif
                        let result = APIResult.failure(.serverError(httpResponse.statusCode))
                        self?.lastResult = result
                        self?.connectionStatus = .error
                        completion(result)
                    }
                } else {
                    let result = APIResult.failure(.unknownError)
                    self?.lastResult = result
                    self?.connectionStatus = .error
                    completion(result)
                }
            }
        }

        currentTask?.resume()
    }

    // MARK: - Test Connection

    func testConnection(completion: @escaping (Bool, String) -> Void) {
        let config = SettingsManager.shared.serverConfig

        guard config.isValid else {
            completion(false, "Server configuration is incomplete")
            return
        }

        guard let url = URL(string: config.loggingURL) else {
            completion(false, "Invalid server URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10

        session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(false, "Connection failed: \(error.localizedDescription)")
                    return
                }

                if let httpResponse = response as? HTTPURLResponse {
                    if (200...299).contains(httpResponse.statusCode) {
                        completion(true, "Connection successful!")
                    } else {
                        completion(false, "Server returned error: HTTP \(httpResponse.statusCode)")
                    }
                } else {
                    completion(false, "Invalid server response")
                }
            }
        }.resume()
    }

    // MARK: - Retry Pending Locations

    /// Send all pending locations with completion tracking
    /// - Parameter completion: Called when all pending sends complete (or queue is empty)
    func sendPendingLocations(completion: (() -> Void)? = nil) {
        let queue = PendingLocationQueue.shared
        let settings = SettingsManager.shared.trackingSettings

        guard !queue.isEmpty else {
            completion?()
            return
        }

        // Remove locations that exceeded retry limit
        queue.removeExceedingRetries(maxRetries: settings.maxRetryAttempts)

        let pendingItems = queue.getAll()
        guard !pendingItems.isEmpty else {
            completion?()
            return
        }

        // Track completion of all requests
        let dispatchGroup = DispatchGroup()

        for pending in pendingItems {
            dispatchGroup.enter()
            sendLocationData(pending.locationData) { result in
                switch result {
                case .success:
                    queue.remove(id: pending.id)
                    SettingsManager.shared.recordSuccessfulSend()
                case .failure:
                    queue.incrementRetry(id: pending.id)
                    SettingsManager.shared.recordFailedSend()
                }
                dispatchGroup.leave()
            }
        }

        // Notify when all requests complete
        dispatchGroup.notify(queue: .main) {
            print("[PhoneTrackAPI] All pending locations processed")
            completion?()
        }
    }

    // MARK: - Cancel

    func cancelCurrentRequest() {
        currentTask?.cancel()
        currentTask = nil
        isSending = false
    }
}
