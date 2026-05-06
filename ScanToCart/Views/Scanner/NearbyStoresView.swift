import SwiftUI
import MapKit

struct NearbyStoresView: View {
    let product: Product
    @State private var location = LocationService.shared
    @State private var displayMode: DisplayMode = .list
    @State private var selectedStore: NearbyStore?
    @State private var cameraPosition: MapCameraPosition = .automatic
    @Environment(\.dismiss) private var dismiss

    enum DisplayMode: String, CaseIterable {
        case list = "List"
        case map = "Map"
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Nearby stores")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                    ToolbarItem(placement: .principal) {
                        if location.authState == .authorized && !location.nearbyStores.isEmpty {
                            Picker("View", selection: $displayMode) {
                                ForEach(DisplayMode.allCases, id: \.self) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 160)
                        }
                    }
                }
                .task { await loadIfPossible() }
                .sheet(item: $selectedStore) { store in
                    storeDetailSheet(for: store)
                        .presentationDetents([.height(220)])
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch location.authState {
        case .notDetermined:
            permissionPrompt
        case .denied:
            permissionDenied
        case .authorized:
            if location.isSearching && location.nearbyStores.isEmpty {
                ProgressView("Searching nearby…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if location.nearbyStores.isEmpty {
                noResults
            } else {
                switch displayMode {
                case .list: resultsList
                case .map: mapView
                }
            }
        }
    }

    // MARK: - Map

    private var mapView: some View {
        Map(position: $cameraPosition, selection: mapSelection) {
            UserAnnotation()
            ForEach(location.nearbyStores) { nearby in
                Marker(
                    nearby.chain.rawValue,
                    systemImage: "cart.fill",
                    coordinate: nearby.coordinate
                )
                .tint(pinColor(for: nearby))
                .tag(nearby.id)
            }
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .onAppear { fitCameraToStores() }
    }

    private var mapSelection: Binding<String?> {
        Binding(
            get: { selectedStore?.id },
            set: { id in
                selectedStore = location.nearbyStores.first(where: { $0.id == id })
            }
        )
    }

    private func storeDetailSheet(for nearby: NearbyStore) -> some View {
        let price = product.price(at: nearby.chain)
        return VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(nearby.name)
                        .font(.headline)
                    Text(nearby.address)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "$%.2f", price))
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                    Text(nearby.distanceLabel)
                        .font(.caption)
                        .foregroundStyle(Theme.accent)
                }
            }
            .padding(.top, 8)

            Button {
                openInMaps(nearby)
            } label: {
                Label("Get directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
        }
        .padding(.horizontal)
        .padding(.bottom, 16)
    }

    private func pinColor(for nearby: NearbyStore) -> Color {
        let prices = location.nearbyStores.map { product.price(at: $0.chain) }.filter { $0 > 0 }
        guard let cheapest = prices.min(), product.price(at: nearby.chain) == cheapest else {
            return Theme.accent
        }
        return Theme.warmAccent  // Highlights the cheapest option in orange
    }

    private func fitCameraToStores() {
        guard let center = location.currentLocation?.coordinate else { return }
        cameraPosition = .region(MKCoordinateRegion(
            center: center,
            latitudinalMeters: 40_000,
            longitudinalMeters: 40_000
        ))
    }

    // MARK: - List

    private var resultsList: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(location.nearbyStores) { nearby in
                    storeRow(for: nearby)
                }
            }
            .padding()
        }
    }

    private func storeRow(for nearby: NearbyStore) -> some View {
        let price = product.price(at: nearby.chain)
        return Button {
            openInMaps(nearby)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(nearby.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    Text(nearby.address)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(2)
                    HStack(spacing: 6) {
                        Image(systemName: "location.fill")
                            .font(.caption2)
                        Text(nearby.distanceLabel)
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(Theme.accent)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "$%.2f", price))
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .cardStyle()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Permission states

    private var permissionPrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 48))
                .foregroundStyle(Theme.accent)
            Text("Find stores near you")
                .font(.headline)
            Text("Allow location access to compare prices at grocery stores within 25 miles.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Allow location") {
                location.requestAccess()
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
        }
        .padding()
    }

    private var permissionDenied: some View {
        VStack(spacing: 16) {
            Image(systemName: "location.slash")
                .font(.system(size: 48))
                .foregroundStyle(Theme.textSecondary)
            Text("Location access denied")
                .font(.headline)
            Text("Enable location in Settings to see nearby stores.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }

    private var noResults: some View {
        VStack(spacing: 12) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 48))
                .foregroundStyle(Theme.textSecondary)
            Text("No grocery stores within 25 miles")
                .font(.headline)
        }
        .padding()
    }

    // MARK: - Helpers

    private func openInMaps(_ nearby: NearbyStore) {
        let placemark = MKPlacemark(coordinate: nearby.coordinate)
        let item = MKMapItem(placemark: placemark)
        item.name = nearby.name
        item.openInMaps()
    }

    private func loadIfPossible() async {
        if location.authState == .authorized && location.nearbyStores.isEmpty {
            await location.refreshNearbyStores()
        }
    }
}
