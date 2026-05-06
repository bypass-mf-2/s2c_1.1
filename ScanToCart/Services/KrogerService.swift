import Foundation
import Supabase
import AuthenticationServices

/// Wraps the Supabase Edge Functions that proxy Kroger's API. All calls
/// require an authenticated Supabase user (we attach the user's JWT).
@MainActor
@Observable
final class KrogerService: NSObject {
    static let shared = KrogerService()

    private(set) var isConnected: Bool = false
    private(set) var preferredLocation: KrogerLocation?
    private(set) var lastError: String?

    private let prefKey = "scantocart.kroger.preferredLocation"

    private var client: SupabaseClient? { SupabaseManager.shared }

    func bootstrap() async {
        loadPreferredLocation()
        await refreshConnectionStatus()
    }

    // MARK: - Connection

    func refreshConnectionStatus() async {
        guard let client else { isConnected = false; return }
        do {
            let session = try await client.auth.session
            let response: [KrogerSessionRow] = try await client.from("kroger_sessions")
                .select("user_id")
                .eq("user_id", value: session.user.id.uuidString)
                .limit(1)
                .execute()
                .value
            isConnected = !response.isEmpty
        } catch {
            isConnected = false
        }
    }

    /// Initiates the Kroger OAuth flow. Opens a web auth session, lets the
    /// user sign into Kroger, then completes when they're redirected back
    /// via the custom URL scheme.
    func connect() async {
        guard let client else {
            lastError = "Supabase not configured"
            return
        }
        do {
            // 1. Ask edge function for the auth URL (it knows our client_id + redirect)
            struct AuthResponse: Decodable { let authUrl: String }
            let authResponse: AuthResponse = try await client.functions.invoke("kroger-auth")

            guard let authURL = URL(string: authResponse.authUrl) else {
                lastError = "Bad auth URL"
                return
            }

            // 2. Open in ASWebAuthenticationSession
            let callbackURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
                let session = ASWebAuthenticationSession(
                    url: authURL,
                    callbackURLScheme: "com.trevorgoodwill.scantocart"
                ) { url, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let url {
                        continuation.resume(returning: url)
                    } else {
                        continuation.resume(throwing: NSError(domain: "Kroger", code: -1))
                    }
                }
                session.presentationContextProvider = self
                session.prefersEphemeralWebBrowserSession = false
                session.start()
            }

            // 3. Inspect callback — edge function appends ?connected=1 on success
            let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)
            if components?.queryItems?.first(where: { $0.name == "error" })?.value != nil {
                lastError = "Kroger sign-in failed"
                return
            }
            isConnected = true
        } catch {
            // Swallow user-cancelled
            let ns = error as NSError
            if ns.domain != "com.apple.AuthenticationServices.WebAuthenticationSession" {
                lastError = error.localizedDescription
            }
        }
    }

    func disconnect() async {
        guard let client else { return }
        do {
            let session = try await client.auth.session
            try await client.from("kroger_sessions")
                .delete()
                .eq("user_id", value: session.user.id.uuidString)
                .execute()
        } catch {
            lastError = error.localizedDescription
        }
        isConnected = false
        preferredLocation = nil
        UserDefaults.standard.removeObject(forKey: prefKey)
    }

    // MARK: - Locations

    func findStores(lat: Double, lng: Double) async -> [KrogerLocation] {
        guard let client else { return [] }
        do {
            struct Wrapper: Decodable { let data: [KrogerLocationRaw] }
            let wrapper: Wrapper = try await client.functions.invoke(
                "kroger-locations",
                options: .init(query: [
                    URLQueryItem(name: "lat", value: String(lat)),
                    URLQueryItem(name: "lng", value: String(lng))
                ])
            )
            return wrapper.data.compactMap { $0.toLocation() }
        } catch {
            return []
        }
    }

    func setPreferredLocation(_ location: KrogerLocation) {
        preferredLocation = location
        if let data = try? JSONEncoder().encode(location) {
            UserDefaults.standard.set(data, forKey: prefKey)
        }
    }

    private func loadPreferredLocation() {
        guard let data = UserDefaults.standard.data(forKey: prefKey),
              let decoded = try? JSONDecoder().decode(KrogerLocation.self, from: data) else { return }
        preferredLocation = decoded
    }

    // MARK: - Products

    func searchProducts(term: String) async -> [KrogerProduct] {
        guard let client else { return [] }
        var query = [URLQueryItem(name: "term", value: term)]
        if let loc = preferredLocation {
            query.append(URLQueryItem(name: "locationId", value: loc.locationId))
        }
        do {
            struct Wrapper: Decodable { let data: [KrogerProductRaw] }
            let wrapper: Wrapper = try await client.functions.invoke(
                "kroger-products-search",
                options: .init(query: query)
            )
            return wrapper.data.compactMap { $0.toProduct() }
        } catch {
            return []
        }
    }

    func lookupByUPC(_ upc: String) async -> KrogerProduct? {
        guard let client else { return nil }
        var query = [URLQueryItem(name: "upc", value: upc)]
        if let loc = preferredLocation {
            query.append(URLQueryItem(name: "locationId", value: loc.locationId))
        }
        do {
            struct Wrapper: Decodable { let data: [KrogerProductRaw] }
            let wrapper: Wrapper = try await client.functions.invoke(
                "kroger-products-upc",
                options: .init(query: query)
            )
            return wrapper.data.first?.toProduct()
        } catch {
            return nil
        }
    }

    // MARK: - Cart

    func addToCart(items: [(upc: String, quantity: Int)]) async -> Result<Int, KrogerError> {
        guard let client else { return .failure(.notConfigured) }
        struct Body: Encodable {
            struct Item: Encodable { let upc: String; let quantity: Int }
            let items: [Item]
        }
        struct OK: Decodable { let success: Bool; let itemsAdded: Int? }
        let body = Body(items: items.map { .init(upc: $0.upc, quantity: $0.quantity) })
        do {
            let response: OK = try await client.functions.invoke(
                "kroger-cart-add",
                options: .init(method: .post, body: body)
            )
            return .success(response.itemsAdded ?? items.count)
        } catch {
            let ns = error as NSError
            if ns.localizedDescription.contains("kroger_not_connected") || ns.localizedDescription.contains("kroger_session_expired") {
                isConnected = false
                return .failure(.notConnected)
            }
            return .failure(.network(error.localizedDescription))
        }
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension KrogerService: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        DispatchQueue.main.sync {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first?.windows.first(where: \.isKeyWindow) ?? ASPresentationAnchor()
        }
    }
}

// MARK: - Models

struct KrogerLocation: Identifiable, Codable, Hashable {
    let locationId: String
    let name: String
    let address: String
    let city: String
    let state: String
    let zipCode: String
    var id: String { locationId }
    var displayAddress: String { "\(address), \(city), \(state) \(zipCode)" }
}

struct KrogerProduct: Identifiable, Hashable {
    let productId: String
    let upc: String
    let description: String
    let brand: String
    let price: Double?
    let imageUrl: String?
    var id: String { productId }
}

enum KrogerError: Error {
    case notConfigured
    case notConnected
    case network(String)

    var message: String {
        switch self {
        case .notConfigured: return "Kroger sync isn't set up"
        case .notConnected: return "Connect your Kroger account in Profile first"
        case .network(let s): return s
        }
    }
}

private struct KrogerSessionRow: Decodable {
    let user_id: String
}

// MARK: - Raw API DTOs

private struct KrogerLocationRaw: Decodable {
    let locationId: String
    let name: String?
    let chain: String?
    let address: KrogerAddressRaw?

    func toLocation() -> KrogerLocation? {
        KrogerLocation(
            locationId: locationId,
            name: name ?? chain ?? "Kroger",
            address: address?.addressLine1 ?? "",
            city: address?.city ?? "",
            state: address?.state ?? "",
            zipCode: address?.zipCode ?? ""
        )
    }
}

private struct KrogerAddressRaw: Decodable {
    let addressLine1: String?
    let city: String?
    let state: String?
    let zipCode: String?
}

private struct KrogerProductRaw: Decodable {
    let productId: String
    let upc: String?
    let description: String?
    let brand: String?
    let items: [KrogerItemRaw]?
    let images: [KrogerImageRaw]?

    func toProduct() -> KrogerProduct? {
        let priceItem = items?.first?.price
        let price = priceItem?.regular ?? priceItem?.promo
        let mediumImage = images?.first?.sizes?.first(where: { $0.size == "medium" })?.url
        return KrogerProduct(
            productId: productId,
            upc: upc ?? "",
            description: description ?? "",
            brand: brand ?? "",
            price: price,
            imageUrl: mediumImage
        )
    }
}

private struct KrogerItemRaw: Decodable {
    let price: KrogerPriceRaw?
}

private struct KrogerPriceRaw: Decodable {
    let regular: Double?
    let promo: Double?
}

private struct KrogerImageRaw: Decodable {
    let sizes: [KrogerImageSizeRaw]?
}

private struct KrogerImageSizeRaw: Decodable {
    let size: String?
    let url: String?
}
