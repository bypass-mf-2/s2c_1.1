import Foundation

enum PriceEstimator {
    private static let categoryRanges: [ProductCategory: (Double, Double)] = [
        .dairy: (3, 6),
        .produce: (2, 5),
        .meat: (6, 12),
        .snacks: (3, 5),
        .beverages: (3, 6),
        .bakery: (3, 6),
        .frozen: (3, 8),
        .pantry: (2, 5),
        .cereal: (3, 6),
        .condiments: (2, 5)
    ]

    private static let storeRatios: [StoreName: Double] = [
        .walmart: 0.92,
        .costco: 0.85,
        .target: 1.00,
        .kroger: 0.95,
        .amazon: 1.08,
        .wholeFoods: 1.18,
        .traderJoes: 0.90
    ]

    static func inferCategory(from name: String) -> ProductCategory {
        let lower = name.lowercased()
        if lower.containsAny(of: ["milk", "cheese", "yogurt", "butter", "cream"]) { return .dairy }
        if lower.containsAny(of: ["apple", "banana", "berry", "fruit", "vegetable", "salad", "lettuce", "tomato", "onion", "potato", "avocado"]) { return .produce }
        if lower.containsAny(of: ["chicken", "beef", "pork", "steak", "salmon", "fish", "turkey", "sausage", "bacon", "meat"]) { return .meat }
        if lower.containsAny(of: ["chip", "cookie", "cracker", "pretzel", "popcorn", "candy", "snack", "bar"]) { return .snacks }
        if lower.containsAny(of: ["soda", "juice", "water", "coffee", "tea", "drink", "beverage", "cola"]) { return .beverages }
        if lower.containsAny(of: ["bread", "muffin", "bagel", "roll", "cake", "donut", "pastry", "bun"]) { return .bakery }
        if lower.containsAny(of: ["frozen", "ice cream", "pizza"]) { return .frozen }
        if lower.containsAny(of: ["cereal", "oat", "granola"]) { return .cereal }
        if lower.containsAny(of: ["sauce", "ketchup", "mustard", "mayo", "dressing", "vinegar", "oil", "spice", "seasoning"]) { return .condiments }
        return .pantry
    }

    static func estimateStorePrices(category: ProductCategory, calories: Double) -> [StorePrice] {
        let (minP, maxP) = categoryRanges[category] ?? (2, 5)
        let calorieFactor = min(1, max(0, (calories - 50) / 450))
        let basePrice = ((minP + calorieFactor * (maxP - minP)) * 100).rounded() / 100

        return StoreName.allCases.map { store in
            let ratio = storeRatios[store] ?? 1.0
            let price = max(0.99, (basePrice * ratio * 100).rounded() / 100)
            return StorePrice(store: store, price: price)
        }
    }
}

private extension String {
    func containsAny(of needles: [String]) -> Bool {
        needles.contains { contains($0) }
    }
}