import Foundation

struct OFFProduct: Decodable {
    let code: String?
    let product: OFFProductDetails?
    let status: Int?
}

struct OFFSearchResponse: Decodable {
    let products: [OFFSearchHit]?
    let count: Int?
}

struct OFFSearchHit: Decodable {
    let code: String?
    let product_name: String?
    let brands: String?
    let image_url: String?
    let nutriments: OFFNutriments?
    let serving_size: String?
    let nutriscore_grade: String?
}

// MARK: - USDA FoodData Central

struct USDASearchResponse: Decodable {
    let foods: [USDAFood]?
}

struct USDAFood: Decodable {
    let fdcId: Int
    let description: String?
    let brandOwner: String?
    let brandName: String?
    let gtinUpc: String?
    let servingSize: Double?
    let servingSizeUnit: String?
    let foodNutrients: [USDAFoodNutrient]?
}

struct USDAFoodNutrient: Decodable {
    let nutrientId: Int?
    let nutrientName: String?
    let value: Double?
}

struct OFFProductDetails: Decodable {
    let product_name: String?
    let brands: String?
    let image_url: String?
    let nutriments: OFFNutriments?
    let serving_size: String?
    let nutriscore_grade: String?

    enum CodingKeys: String, CodingKey {
        case product_name, brands, image_url, nutriments, serving_size, nutriscore_grade
    }
}

struct OFFNutriments: Decodable {
    let energy_kcal_serving: Double?
    let energy_kcal_100g: Double?
    let proteins_serving: Double?
    let proteins_100g: Double?
    let carbohydrates_serving: Double?
    let carbohydrates_100g: Double?
    let fat_serving: Double?
    let fat_100g: Double?
    let fiber_serving: Double?
    let fiber_100g: Double?
    let sugars_serving: Double?
    let sugars_100g: Double?
    let sodium_serving: Double?
    let sodium_100g: Double?

    enum CodingKeys: String, CodingKey {
        case energy_kcal_serving = "energy-kcal_serving"
        case energy_kcal_100g = "energy-kcal_100g"
        case proteins_serving = "proteins_serving"
        case proteins_100g = "proteins_100g"
        case carbohydrates_serving = "carbohydrates_serving"
        case carbohydrates_100g = "carbohydrates_100g"
        case fat_serving = "fat_serving"
        case fat_100g = "fat_100g"
        case fiber_serving = "fiber_serving"
        case fiber_100g = "fiber_100g"
        case sugars_serving = "sugars_serving"
        case sugars_100g = "sugars_100g"
        case sodium_serving = "sodium_serving"
        case sodium_100g = "sodium_100g"
    }
}

enum FoodDatabaseError: Error {
    case notFound
    case network(Error)
    case invalidResponse
}

final class FoodDatabase {
    static let shared = FoodDatabase()

    private let session = URLSession.shared

    /// Look up a product by barcode against Open Food Facts, then enrich
    /// prices via SerpAPI if a key is configured. Falls back to mocks.
    func lookup(barcode: String) async -> Product? {
        if let mock = MockProducts.all.first(where: { $0.barcode == barcode }) {
            return mock
        }

        let urlString = "https://world.openfoodfacts.org/api/v2/product/\(barcode).json"
        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, _) = try await session.data(from: url)
            let response = try JSONDecoder().decode(OFFProduct.self, from: data)
            guard response.status == 1, let details = response.product else { return nil }
            var product = Self.makeProduct(barcode: barcode, details: details)

            let realPrices = await PriceService.shared.enrich(
                barcode: barcode,
                productName: product.name,
                category: product.category,
                calories: product.nutrition.calories
            )
            if !realPrices.isEmpty {
                product.prices = realPrices
            }
            return product
        } catch {
            return nil
        }
    }

    /// Searches Open Food Facts by name. Pages through results when `page` > 1.
    /// Returns estimated prices (no SerpAPI here — barcode lookup only).
    func search(query: String, page: Int = 1) async -> [Product] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else { return [] }

        var components = URLComponents(string: "https://world.openfoodfacts.org/api/v2/search")
        components?.queryItems = [
            URLQueryItem(name: "search_terms", value: trimmed),
            URLQueryItem(name: "fields", value: "code,product_name,brands,image_url,nutriments,serving_size,nutriscore_grade"),
            URLQueryItem(name: "page_size", value: "50"),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "lc", value: "en")
        ]
        guard let url = components?.url else { return [] }

        do {
            var request = URLRequest(url: url)
            request.setValue("ScanToCart/1.0 (iOS app — barcode + price comparison)", forHTTPHeaderField: "User-Agent")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.timeoutInterval = 8
            let (data, urlResponse) = try await session.data(for: request)
            // OFF returns HTML 503 pages when overloaded — bail cleanly rather
            // than throwing a JSON decode error.
            if let http = urlResponse as? HTTPURLResponse, http.statusCode != 200 {
                return []
            }
            let body = try JSONDecoder().decode(OFFSearchResponse.self, from: data)
            let queryTokens = trimmed.lowercased().split(separator: " ").map(String.init)
            return (body.products ?? []).compactMap { hit -> Product? in
                guard let code = hit.code,
                      let name = hit.product_name?.trimmingCharacters(in: .whitespaces).nonEmpty
                else { return nil }
                // Keep only hits where every query word appears in the name
                // or brand. Filters out OFF's overzealous fuzzy matches.
                let haystack = (name + " " + (hit.brands ?? "")).lowercased()
                guard queryTokens.allSatisfy({ haystack.contains($0) }) else { return nil }
                let details = OFFProductDetails(
                    product_name: name,
                    brands: hit.brands,
                    image_url: hit.image_url,
                    nutriments: hit.nutriments,
                    serving_size: hit.serving_size,
                    nutriscore_grade: hit.nutriscore_grade
                )
                return Self.makeProduct(barcode: code, details: details)
            }
        } catch {
            return []
        }
    }

    /// Searches USDA FoodData Central. Pages through results when `page` > 1.
    func searchUSDA(query: String, page: Int = 1) async -> [Product] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2, !Config.usdaAPIKey.isEmpty else { return [] }

        var components = URLComponents(string: "https://api.nal.usda.gov/fdc/v1/foods/search")
        components?.queryItems = [
            URLQueryItem(name: "query", value: trimmed),
            URLQueryItem(name: "pageSize", value: "30"),
            URLQueryItem(name: "pageNumber", value: String(page)),
            URLQueryItem(name: "dataType", value: "Branded,Foundation,SR Legacy"),
            URLQueryItem(name: "api_key", value: Config.usdaAPIKey)
        ]
        guard let url = components?.url else { return [] }

        do {
            let (data, _) = try await session.data(from: url)
            let response = try JSONDecoder().decode(USDASearchResponse.self, from: data)
            let queryTokens = trimmed.lowercased().split(separator: " ").map(String.init)
            return (response.foods ?? []).compactMap { food -> Product? in
                guard let name = food.description?.trimmingCharacters(in: .whitespaces).nonEmpty else { return nil }
                let brand = food.brandName ?? food.brandOwner ?? ""
                let haystack = (name + " " + brand).lowercased()
                guard queryTokens.allSatisfy({ haystack.contains($0) }) else { return nil }
                return Self.makeUSDAProduct(food: food, name: name, brand: brand)
            }
        } catch {
            return []
        }
    }

    private static func makeUSDAProduct(food: USDAFood, name: String, brand: String) -> Product {
        let nutrients = Dictionary(grouping: food.foodNutrients ?? [], by: \.nutrientId)
            .compactMapValues { $0.first?.value }

        // USDA returns per-100g for raw foods, per-serving for branded.
        // Either way, we treat the values as the serving baseline.
        let nutrition = NutritionInfo(
            calories: nutrients[1008] ?? 0,
            protein: nutrients[1003] ?? 0,
            carbs: nutrients[1005] ?? 0,
            fat: nutrients[1004] ?? 0,
            fiber: nutrients[1079] ?? 0,
            sugar: nutrients[2000] ?? 0,
            sodium: (nutrients[1093] ?? 0) / 1000,  // USDA mg → grams to match OFF
            servingSize: servingSizeLabel(food: food)
        )

        let category = PriceEstimator.inferCategory(from: name)
        let prices = PriceEstimator.estimateStorePrices(category: category, calories: nutrition.calories)
        let id = food.gtinUpc?.nonEmpty ?? "fdc-\(food.fdcId)"

        return Product(
            id: id,
            barcode: food.gtinUpc ?? "",
            name: name,
            brand: brand.nonEmpty ?? "USDA",
            imageURL: "",
            category: category,
            nutrition: nutrition,
            prices: prices
        )
    }

    private static func servingSizeLabel(food: USDAFood) -> String {
        if let size = food.servingSize, let unit = food.servingSizeUnit {
            let formatted = size.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(size))" : String(format: "%.1f", size)
            return "\(formatted) \(unit)"
        }
        return "100 g"
    }

    static func makeProduct(barcode: String, details: OFFProductDetails) -> Product {
        let name = details.product_name?.trimmingCharacters(in: .whitespaces).nonEmpty ?? "Unknown Product"
        let brand = details.brands?.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces).nonEmpty ?? "Unknown"
        let image = details.image_url ?? ""

        let n = details.nutriments
        let nutrition = NutritionInfo(
            calories: n?.energy_kcal_serving ?? n?.energy_kcal_100g ?? 0,
            protein: n?.proteins_serving ?? n?.proteins_100g ?? 0,
            carbs: n?.carbohydrates_serving ?? n?.carbohydrates_100g ?? 0,
            fat: n?.fat_serving ?? n?.fat_100g ?? 0,
            fiber: n?.fiber_serving ?? n?.fiber_100g ?? 0,
            sugar: n?.sugars_serving ?? n?.sugars_100g ?? 0,
            sodium: n?.sodium_serving ?? n?.sodium_100g ?? 0,
            servingSize: details.serving_size ?? "1 serving"
        )

        let category = PriceEstimator.inferCategory(from: name)
        let prices = PriceEstimator.estimateStorePrices(category: category, calories: nutrition.calories)

        return Product(
            id: barcode,
            barcode: barcode,
            name: name,
            brand: brand,
            imageURL: image,
            category: category,
            nutrition: nutrition,
            prices: prices,
            nutriScoreGrade: details.nutriscore_grade
        )
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}