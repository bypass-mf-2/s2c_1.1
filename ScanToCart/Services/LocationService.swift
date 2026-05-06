import Foundation
import CoreLocation
import MapKit

/// Wraps CoreLocation + MapKit local search to find nearby grocery stores.
/// Returns Apple Maps results filtered to the StoreName chains we know.
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    static let shared = LocationService()

    enum AuthState { case notDetermined, denied, authorized }

    private(set) var authState: AuthState = .notDetermined
    private(set) var currentLocation: CLLocation?
    private(set) var nearbyStores: [NearbyStore] = []
    private(set) var isSearching: Bool = false

    private let manager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocation?, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        syncAuth(manager.authorizationStatus)
    }

    func requestAccess() {
        manager.requestWhenInUseAuthorization()
    }

    /// Refreshes location + searches nearby grocery stores within 25 miles.
    /// Caches in `nearbyStores`. Returns whether the search succeeded.
    @discardableResult
    func refreshNearbyStores() async -> Bool {
        guard authState == .authorized else { return false }
        isSearching = true
        defer { isSearching = false }

        let location = await waitForLocation()
        guard let coord = location?.coordinate else { return false }
        currentLocation = location

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "grocery store"
        request.region = MKCoordinateRegion(
            center: coord,
            latitudinalMeters: 40_234,
            longitudinalMeters: 40_234
        )
        request.resultTypes = [.pointOfInterest]

        do {
            let response = try await MKLocalSearch(request: request).start()
            let from = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            nearbyStores = response.mapItems.compactMap { item -> NearbyStore? in
                guard let chain = matchChain(item.name ?? "") else { return nil }
                let dest = CLLocation(
                    latitude: item.placemark.coordinate.latitude,
                    longitude: item.placemark.coordinate.longitude
                )
                return NearbyStore(
                    chain: chain,
                    name: item.name ?? chain.rawValue,
                    distanceMeters: from.distance(from: dest),
                    address: item.placemark.title ?? "",
                    coordinate: item.placemark.coordinate
                )
            }
            .sorted { $0.distanceMeters < $1.distanceMeters }
            return true
        } catch {
            return false
        }
    }

    // MARK: - Internal

    private func waitForLocation() async -> CLLocation? {
        if let cached = manager.location {
            return cached
        }
        return await withCheckedContinuation { cont in
            locationContinuation = cont
            manager.requestLocation()
        }
    }

    private func matchChain(_ name: String) -> StoreName? {
        let lower = name.lowercased()
        if lower.contains("walmart") { return .walmart }
        if lower.contains("target") { return .target }
        if lower.contains("costco") { return .costco }
        if lower.contains("kroger") || lower.contains("ralphs") || lower.contains("fred meyer") { return .kroger }
        if lower.contains("whole foods") { return .wholeFoods }
        if lower.contains("trader joe") { return .traderJoes }
        if lower.contains("amazon fresh") { return .amazon }
        return nil
    }

    private func syncAuth(_ status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            authState = .authorized
        case .denied, .restricted:
            authState = .denied
        default:
            authState = .notDetermined
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        syncAuth(manager.authorizationStatus)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let last = locations.last {
            currentLocation = last
            locationContinuation?.resume(returning: last)
            locationContinuation = nil
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationContinuation?.resume(returning: nil)
        locationContinuation = nil
    }
}

struct NearbyStore: Identifiable, Hashable {
    let chain: StoreName
    let name: String
    let distanceMeters: Double
    let address: String
    let coordinate: CLLocationCoordinate2D
    var id: String { "\(chain.rawValue)-\(coordinate.latitude),\(coordinate.longitude)" }

    var distanceLabel: String {
        let miles = distanceMeters / 1609.34
        if miles < 0.1 {
            return "Nearby"
        }
        return String(format: "%.1f mi", miles)
    }
}

extension CLLocationCoordinate2D: @retroactive Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(latitude)
        hasher.combine(longitude)
    }
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}
