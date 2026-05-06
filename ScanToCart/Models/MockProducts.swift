import Foundation

enum MockProducts {
    static let all: [Product] = [
        Product(
            id: "mock-1",
            barcode: "0049000028911",
            name: "Greek Yogurt, Plain",
            brand: "Chobani",
            imageURL: "https://images.openfoodfacts.org/images/products/081/899/100/0335/front_en.3.400.jpg",
            category: .dairy,
            nutrition: NutritionInfo(calories: 130, protein: 12, carbs: 9, fat: 5, fiber: 0, sugar: 7, sodium: 60, servingSize: "1 cup (227g)"),
            prices: storeRange(base: 4.49)
        ),
        Product(
            id: "mock-2",
            barcode: "0028400090000",
            name: "Whole Grain Cheerios",
            brand: "General Mills",
            imageURL: "https://images.openfoodfacts.org/images/products/001/600/027/8499/front_en.46.400.jpg",
            category: .cereal,
            nutrition: NutritionInfo(calories: 140, protein: 5, carbs: 29, fat: 2.5, fiber: 4, sugar: 1, sodium: 190, servingSize: "1.5 cups (40g)"),
            prices: storeRange(base: 5.29)
        ),
        Product(
            id: "mock-3",
            barcode: "0030000056103",
            name: "Organic Bananas",
            brand: "Dole",
            imageURL: "https://images.openfoodfacts.org/images/products/006/950/100/4318/front_en.7.400.jpg",
            category: .produce,
            nutrition: NutritionInfo(calories: 105, protein: 1.3, carbs: 27, fat: 0.4, fiber: 3.1, sugar: 14, sodium: 1, servingSize: "1 medium (118g)"),
            prices: storeRange(base: 0.69)
        ),
        Product(
            id: "mock-4",
            barcode: "0044000037215",
            name: "Sourdough Bread",
            brand: "La Brea",
            imageURL: "https://images.openfoodfacts.org/images/products/004/138/710/0146/front_en.4.400.jpg",
            category: .bakery,
            nutrition: NutritionInfo(calories: 130, protein: 4, carbs: 25, fat: 1, fiber: 1, sugar: 1, sodium: 280, servingSize: "1 slice (43g)"),
            prices: storeRange(base: 4.99)
        ),
        Product(
            id: "mock-5",
            barcode: "0078742229898",
            name: "Almond Milk, Unsweetened",
            brand: "Silk",
            imageURL: "https://images.openfoodfacts.org/images/products/002/500/004/2620/front_en.10.400.jpg",
            category: .beverages,
            nutrition: NutritionInfo(calories: 30, protein: 1, carbs: 1, fat: 2.5, fiber: 1, sugar: 0, sodium: 170, servingSize: "1 cup (240ml)"),
            prices: storeRange(base: 3.99)
        ),
        Product(
            id: "mock-6",
            barcode: "0021000615267",
            name: "Boneless Chicken Breast",
            brand: "Perdue",
            imageURL: "https://images.openfoodfacts.org/images/products/007/280/044/0148/front_en.7.400.jpg",
            category: .meat,
            nutrition: NutritionInfo(calories: 165, protein: 31, carbs: 0, fat: 3.6, fiber: 0, sugar: 0, sodium: 74, servingSize: "100g"),
            prices: storeRange(base: 8.99)
        )
    ]

    private static func storeRange(base: Double) -> [StorePrice] {
        let ratios: [(store: StoreName, ratio: Double)] = [
            (.walmart, 0.92), (.costco, 0.85), (.target, 1.00),
            (.kroger, 0.95), (.amazon, 1.08), (.wholeFoods, 1.18),
            (.traderJoes, 0.90)
        ]
        return ratios.map { entry in
            let raw = base * entry.ratio
            let rounded = (raw * 100).rounded() / 100
            return StorePrice(store: entry.store, price: max(0.99, rounded))
        }
    }
}