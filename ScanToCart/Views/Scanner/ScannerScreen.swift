import SwiftUI
import AVFoundation

struct ScannerScreen: View {
    @Environment(AppStore.self) private var store

    @State private var cameraAuthorized: Bool? = nil
    @State private var lookedUpProduct: Product?
    @State private var isLookingUp = false
    @State private var lookupError: String?
    @State private var showingSearch = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                cameraSection

                searchButton
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .background(Theme.background)
            }
            .navigationTitle("Scan")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $lookedUpProduct) { product in
                ProductDetailSheet(product: product)
                    .environment(store)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showingSearch) {
                SearchScreen()
                    .environment(store)
            }
            .task { await checkCameraPermission() }
            .alert("Lookup failed", isPresented: .constant(lookupError != nil), presenting: lookupError) { _ in
                Button("OK") { lookupError = nil }
            } message: { msg in Text(msg) }
        }
    }

    private var searchButton: some View {
        Button {
            showingSearch = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                Text("Search products by name")
                    .fontWeight(.medium)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
            .foregroundStyle(Theme.textPrimary)
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var cameraSection: some View {
        switch cameraAuthorized {
        case .some(true):
            ZStack {
                BarcodeScannerView { code in
                    Task { await handleScan(code) }
                }
                .ignoresSafeArea(edges: .bottom)

                viewfinder

                if isLookingUp {
                    ProgressView("Looking up…")
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        case .some(false):
            permissionDenied
        case .none:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var viewfinder: some View {
        VStack {
            Spacer()
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.9), lineWidth: 2)
                .frame(width: 280, height: 160)
                .shadow(color: .black.opacity(0.3), radius: 8)
            Spacer()
            Text("Point at a barcode")
                .font(.callout)
                .foregroundStyle(.white)
                .padding(.bottom, 20)
        }
    }

    private var permissionDenied: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.metering.unknown")
                .font(.system(size: 56))
                .foregroundStyle(Theme.textSecondary)
            Text("Camera access is needed to scan barcodes")
                .font(.headline)
                .multilineTextAlignment(.center)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
        }
        .padding()
    }

    private func checkCameraPermission() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            cameraAuthorized = true
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            cameraAuthorized = granted
        default:
            cameraAuthorized = false
        }
    }

    private func handleScan(_ code: String) async {
        isLookingUp = true
        defer { isLookingUp = false }
        if let product = await store.lookup(barcode: code) {
            lookedUpProduct = product
        } else {
            lookupError = "No product found for barcode \(code)"
        }
    }
}
