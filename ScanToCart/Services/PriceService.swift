import Foundation

/// Fetches real grocery prices from Google Shopping via SerpAPI, with
/// 24-hour on-device caching to stay within the free tier (250 searches/mo).
///
/// Trader Joe's never appears in Google Shopping results (no online sales,
/// no product feed), so its price always falls through to the heuristic
/// estimate from `PriceEstimator`.
final class PriceService {
    static let shared = PriceService()

    private let cacheTTL: TimeInterval = 24 * 60 * 60
    private let cachePrefix = "scantocart.prices."
    private let session = URLSession.shared
    private let defaults = UserDefaults.standard

    /// Returns prices for every known store. Uses real SerpAPI data when
    /// available, fills gaps with heuristic estimates. Returns nil only if
    /// SerpAPI returned no usable data AND no fallback is appropriate.
    func enrich(barcode: String, productName: String, category: ProductCategory, calories: Double) async -> [StorePrice] {
        if let cached = cached(for: barcode) {
            return cached
        }

        var realPrices: [StoreName: Double] = [:]
        if !Config.serpAPIKey.isEmpty {
            realPrices = await fetchGoogleShopping(query: barcode)
            if realPrices.isEmpty {
                realPrices = await fetchGoogleShopping(query: productName)
            }
        }

        let merged = mergeWithEstimates(realPrices: realPrices, category: category, calories: calories)
        store(prices: merged, for: barcode)
        return merged
    }

    // MARK: - SerpAPI

    private func fetchGoogleShopping(query: String) async -> [StoreName: Double] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty,
              var components = URLComponents(string: "https://serpapi.com/search.json") else {
            return [:]
        }
        components.queryItems = [
            URLQueryItem(name: "engine", value: "google_shopping"),
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "gl", value: "us"),
            URLQueryItem(name: "hl", value: "en"),
            URLQueryItem(name: "api_key", value: Config.serpAPIKey)
        ]
        guard let url = components.url else { return [:] }

        do {
            let (data, _) = try await session.data(from: url)
            let response = try JSONDecoder().decode(SerpAPIResponse.self, from: data)
            var byStore: [StoreName: Double] = [:]
            for result in response.shopping_results ?? [] {
                guard let source = result.source,
                      let price = result.extracted_price,
                      let store = matchStore(source: source) else { continue }
                let rounded = (price * 100).rounded() / 100
                if let existing = byStore[store] {
                    byStore[store] = min(existing, rounded)
                } else {
                    byStore[store] = rounded
                }
            }
            return byStore
        } catch {
            return [:]
        }
    }

    private func matchStore(source: String) -> StoreName? {
        let lower = source.lowercased()
        if lower.contains("walmart") { return .walmart }
        if lower.contains("target") { return .target }
        if lower.contains("costco") { return .costco }
        if lower.contains("kroger") { return .kroger }
        if lower.contains("whole foods") || lower.contains("wholefoods") { return .wholeFoods }
        if lower.contains("amazon") { return .amazon }
        if lower.contains("trader joe") || lower.contains("traderjoe") { return .traderJoes }
        return nil
    }

    // MARK: - Merge with estimates

    private func mergeWithEstimates(
        realPrices: [StoreName: Double],
        category: ProductCategory,
        calories: Double
    ) -> [StorePrice] {
        // Anchor estimate using the median real price (when we have any)
        // by un-applying that store's ratio. Otherwise fall back to the
        // category × calories heuristic.
        let estimated = PriceEstimator.estimateStorePrices(category: category, calories: calories)
        let estimatedByStore = Dictionary(uniqueKeysWithValues: estimated.map { ($0.store, $0.price) })

        return StoreName.allCases.map { store in
            let real = realPrices[store]
            let price = real ?? estimatedByStore[store] ?? 1.99
            return StorePrice(store: store, price: max(0.99, price))
        }
    }

    // MARK: - Cache

    private func cached(for barcode: String) -> [StorePrice]? {
        let key = cachePrefix + barcode
        guard let data = defaults.data(forKey: key),
              let cached = try? JSONDecoder().decode(CachedPrices.self, from: data) else {
            return nil
        }
        if Date().timeIntervalSince1970 - cached.timestamp > cacheTTL {
            defaults.removeObject(forKey: key)
            return nil
        }
        return cached.prices
    }

    private func store(prices: [StorePrice], for barcode: String) {
        let entry = CachedPrices(prices: prices, timestamp: Date().timeIntervalSince1970)
        guard let data = try? JSONEncoder().encode(entry) else { return }
        defaults.set(data, forKey: cachePrefix + barcode)
    }
}

// MARK: - DTOs

private struct SerpAPIResponse: Decodable {
    let shopping_results: [SerpAPIShoppingResult]?
}

private struct SerpAPIShoppingResult: Decodable {
    let title: String?
    let source: String?
    let extracted_price: Double?
}

private struct CachedPrices: Codable {
    let prices: [StorePrice]
    let timestamp: TimeInterval
}