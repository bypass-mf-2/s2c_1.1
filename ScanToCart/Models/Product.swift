import Foundation

enum StoreName: String, Codable, CaseIterable, Identifiable {
    case target = "Target"
    case walmart = "Walmart"
    case amazon = "Amazon"
    case costco = "Costco"
    case kroger = "Kroger"
    case wholeFoods = "Whole Foods"
    case traderJoes = "Trader Joe's"

    var id: String { rawValue }
}

enum ProductCategory: String, Codable, CaseIterable, Identifiable {
    case dairy = "Dairy"
    case produce = "Produce"
    case snacks = "Snacks"
    case beverages = "Beverages"
    case meat = "Meat"
    case bakery = "Bakery"
    case frozen = "Frozen"
    case pantry = "Pantry"
    case cereal = "Cereal"
    case condiments = "Condiments"
    case supplements = "Supplements"

    var id: String { rawValue }
}

struct NutritionInfo: Codable, Hashable {
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var fiber: Double
    var sugar: Double
    var sodium: Double
    var servingSize: String
}

struct StorePrice: Codable, Hashable, Identifiable {
    var store: StoreName
    var price: Double
    var id: String { store.rawValue }
}

struct Product: Codable, Hashable, Identifiable {
    var id: String
    var barcode: String
    var name: String
    var brand: String
    var imageURL: String
    var category: ProductCategory
    var nutrition: NutritionInfo
    var prices: [StorePrice]
    var nutriScoreGrade: String? = nil

    func price(at store: StoreName) -> Double {
        prices.first(where: { $0.store == store })?.price ?? prices.first?.price ?? 0
    }

    var healthScore: HealthScore {
        HealthScore.compute(nutrition: nutrition, nutriScoreGrade: nutriScoreGrade)
    }
}

struct ScannedItem: Codable, Hashable, Identifiable {
    var id: String
    var product: Product
    var scannedAt: Date
    var addedToCart: Bool
    var store: StoreName?
    var quantity: Int
}