//
//  PrayerTimeManager.swift
//  ForMe
//
//  Fetches prayer times from Aladhan API.
//  Location chain: GPS (most accurate) → IP geolocation → hardcoded fallback.
//

import Foundation
import CoreLocation
import MapKit

// MARK: - Prayer Schedules

struct PrayerSchedule {
    var fajr: Date
    var dhuhr: Date
    var asr: Date
    var maghrib: Date
    var isha: Date

    var all: [(name: String, time: Date)] {
        [("Fajr", fajr), ("Dhuhr", dhuhr), ("Asr", asr), ("Maghrib", maghrib), ("Isha", isha)]
    }
}

// MARK: - API Response

private struct AladhanResponse: Decodable {
    let code: Int
    let data: AladhanData
    struct AladhanData: Decodable { let timings: AladhanTimings }
    struct AladhanTimings: Decodable {
        let Fajr: String; let Dhuhr: String; let Asr: String
        let Maghrib: String; let Isha: String
    }
}

// MARK: - PrayerTimeManager

@Observable
@MainActor
final class PrayerTimeManager: NSObject, CLLocationManagerDelegate {

    var nextPrayerString: String = "Loading…"
    var schedule: PrayerSchedule?
    var cityName: String = ""
    var locationSource: String = "" // "GPS", "IP", or "Default"
    var latitude: Double?
    var longitude: Double?

    private let locationManager = CLLocationManager()
    private var hasFetchedToday = false
    private var countdownTimer: Timer?
    private var locationContinuation: CheckedContinuation<CLLocation?, Never>?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    /// Called from view's .task modifier
    func startFetching(force: Bool = false) async {
        if force {
            hasFetchedToday = false
            nextPrayerString = "Loading…"
            cityName = ""
            locationSource = ""
            latitude = nil
            longitude = nil
        }
        guard !hasFetchedToday else { return }

        // 1. Try GPS — request permission if needed
        if let location = await requestGPSLocation() {
            locationSource = "GPS"
            let coord = location.coordinate
            latitude = coord.latitude
            longitude = coord.longitude
            await reverseGeocode(location)
            await callAladhan(lat: coord.latitude, lng: coord.longitude)
            if hasFetchedToday { return }
        }

        // 2. Fall back to IP geolocation
        if let (lat, lng) = await getIPLocation() {
            locationSource = "IP"
            latitude = lat
            longitude = lng
            await callAladhan(lat: lat, lng: lng)
            if hasFetchedToday { return }
        }

        // 3. Hardcoded fallback (Makassar, Indonesia)
        locationSource = "Fallback"
        latitude = -5.1477
        longitude = 119.4327
        if cityName.isEmpty { cityName = "Makassar" }
        await callAladhan(lat: -5.1477, lng: 119.4327)
    }

    // MARK: - GPS Location

    private func requestGPSLocation() async -> CLLocation? {
        let status = locationManager.authorizationStatus

        if status == .notDetermined {
            // Request permission — this shows a system dialog
            locationManager.requestWhenInUseAuthorization()
            // Wait up to 30 seconds for user to respond to the dialog
            for _ in 0..<60 {
                try? await Task.sleep(for: .milliseconds(500))
                let newStatus = locationManager.authorizationStatus
                if newStatus != .notDetermined { break }
            }
        }

        let currentStatus = locationManager.authorizationStatus
        guard currentStatus == .authorized || currentStatus == .authorizedAlways else {
            return nil
        }

        // Prevent continuation leak through concurrent requests
        if self.locationContinuation != nil {
            return nil
        }

        // Request a single location update and wait for it
        return await withCheckedContinuation { continuation in
            self.locationContinuation = continuation
            self.locationManager.requestLocation()

            // Timeout after 10 seconds
            Task {
                try? await Task.sleep(for: .seconds(10))
                if let cont = self.locationContinuation {
                    self.locationContinuation = nil
                    cont.resume(returning: nil)
                }
            }
        }
    }

    // MARK: - Reverse Geocoding (GPS → city/district name)

    private func reverseGeocode(_ location: CLLocation) async {
        if let req = MKReverseGeocodingRequest(location: location) {
            do {
                let items = try await req.mapItems
                if let item = items.first {
                    // Use item.name (district/subLocality equivalent) or cityName
                    cityName = item.name ?? item.addressRepresentations?.cityName ?? "Unknown"
                }
            } catch {
                // Geocoding failed, city name stays empty or from IP
            }
        }
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        Task { @MainActor in
            if let cont = self.locationContinuation {
                self.locationContinuation = nil
                cont.resume(returning: location)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            if let cont = self.locationContinuation {
                self.locationContinuation = nil
                cont.resume(returning: nil)
            }
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // Authorization changed — the polling loop in requestGPSLocation will detect this
    }

    // MARK: - IP Geolocation (ipwho.is — HTTPS, free, no rate limit)

    private func getIPLocation() async -> (Double, Double)? {
        guard let url = URL(string: "https://ipwho.is/") else { return nil }
        do {
            var req = URLRequest(url: url)
            req.timeoutInterval = 8
            let (data, _) = try await URLSession.shared.data(for: req)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let success = json["success"] as? Bool, success,
               let lat = json["latitude"] as? Double,
               let lng = json["longitude"] as? Double {
                // Only set city from IP if GPS didn't set it
                if cityName.isEmpty, let city = json["city"] as? String {
                    cityName = city
                }
                return (lat, lng)
            }
        } catch { /* fall through */ }
        return nil
    }

    // MARK: - Aladhan API

    private func callAladhan(lat: Double, lng: Double) async {
        // Round coordinates to 2 decimal places for privacy (approx 1.1km)
        let roundedLat = (lat * 100).rounded() / 100
        let roundedLng = (lng * 100).rounded() / 100

        let gregorian = Calendar(identifier: .gregorian)
        let c = gregorian.dateComponents([.day, .month, .year], from: Date())
        guard let day = c.day, let month = c.month, let year = c.year else { return }
        let dateStr = String(format: "%02d-%02d-%04d", day, month, year)
        let urlStr = "https://api.aladhan.com/v1/timings/\(dateStr)?latitude=\(roundedLat)&longitude=\(roundedLng)&method=20"

        guard let url = URL(string: urlStr) else { return }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 15
            request.setValue("ForMe-macOS/1.0", forHTTPHeaderField: "User-Agent")

            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResp = response as? HTTPURLResponse, httpResp.statusCode != 200 { return }

            let decoded = try JSONDecoder().decode(AladhanResponse.self, from: data)
            let t = decoded.data.timings
            let today = Date()

            schedule = PrayerSchedule(
                fajr:    parseTime(t.Fajr, on: today),
                dhuhr:   parseTime(t.Dhuhr, on: today),
                asr:     parseTime(t.Asr, on: today),
                maghrib: parseTime(t.Maghrib, on: today),
                isha:    parseTime(t.Isha, on: today)
            )
            hasFetchedToday = true
            startCountdownTimer()
        } catch {
            nextPrayerString = "Sholat unavailable"
        }
    }

    // MARK: - Time Parsing

    private func parseTime(_ timeString: String, on date: Date) -> Date {
        let clean = timeString.components(separatedBy: " ").first ?? timeString
        let parts = clean.split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return date }
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: date)
        comps.hour = h; comps.minute = m; comps.second = 0
        return Calendar.current.date(from: comps) ?? date
    }

    // MARK: - Countdown

    private func startCountdownTimer() {
        updateNextPrayer()
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateNextPrayer()
            }
        }
    }

    private func updateNextPrayer() {
        guard let schedule else { return }
        let now = Date()
        if let next = schedule.all.first(where: { $0.time > now }) {
            let diff = next.time.timeIntervalSince(now)
            let h = Int(diff) / 3600, m = (Int(diff) % 3600) / 60
            nextPrayerString = h > 0 ? "\(next.name) in \(h)h \(m)m" : "\(next.name) in \(m)m"
        } else {
            nextPrayerString = "Fajr tomorrow"
        }
    }
}
