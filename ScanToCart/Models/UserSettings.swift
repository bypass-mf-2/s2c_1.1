import Foundation

struct NutritionGoals: Codable, Hashable {
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double

    static let `default` = NutritionGoals(
        calories: 2000,
        protein: 120,
        carbs: 250,
        fat: 65
    )
}

struct HealthAppConnection: Codable, Hashable, Identifiable {
    var name: String
    var connected: Bool
    var lastSync: Date?
    var id: String { name }
}

struct UserSettings: Codable, Hashable {
    var preferredStore: StoreName
    var nutritionGoals: NutritionGoals
    var monthlyBudget: Double
    var healthApps: [HealthAppConnection]

    static let `default` = UserSettings(
        preferredStore: .target,
        nutritionGoals: .default,
        monthlyBudget: 500,
        healthApps: [
            HealthAppConnection(name: "Apple Health", connected: false)
        ]
    )
}