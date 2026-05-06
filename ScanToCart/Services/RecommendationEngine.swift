import Foundation

/// Generates personalized nutrition + budget tips. Mirrors the logic from
/// the React Native version's `recommendations.ts`. Returns at most 5 tips,
/// already ordered by priority.
enum RecommendationEngine {
    static func generate(
        todayNutrition: NutritionInfo,
        goals: NutritionGoals,
        monthlySpending: Double,
        monthlyBudget: Double,
        scannedItems: [ScannedItem],
        preferredStore: StoreName
    ) -> [Recommendation] {
        var recs: [Recommendation] = []

        // MARK: Nutrition

        let proteinPct = goals.protein > 0 ? todayNutrition.protein / goals.protein : 1
        if proteinPct < 0.6 {
            let gap = Int((goals.protein - todayNutrition.protein).rounded())
            recs.append(Recommendation(
                id: "rec_low_protein",
                type: .nutrition,
                title: "Boost Your Protein",
                description: "You're \(gap)g below your protein goal today. Try Greek yogurt or chicken breast at your next meal.",
                icon: .zap,
                suggestedProduct: findHighProtein()
            ))
        }

        let fiberGoal = 25.0
        let fiberPct = todayNutrition.fiber / fiberGoal
        if fiberPct < 0.5 {
            let gap = Int((fiberGoal - todayNutrition.fiber).rounded())
            recs.append(Recommendation(
                id: "rec_low_fiber",
                type: .nutrition,
                title: "Add More Fiber",
                description: "Your fiber intake is \(gap)g below the daily target. Consider spinach or whole-grain cereal.",
                icon: .leaf,
                suggestedProduct: findHighFiber()
            ))
        }

        let caloriePct = goals.calories > 0 ? todayNutrition.calories / goals.calories : 0
        if caloriePct > 0.9 {
            let remaining = max(Int((goals.calories - todayNutrition.calories).rounded()), 0)
            recs.append(Recommendation(
                id: "rec_calorie_alert",
                type: .nutrition,
                title: "Calorie Alert",
                description: "You've consumed \(Int(caloriePct * 100))% of your daily calories. Only \(remaining) cal remaining — choose wisely!",
                icon: .alertTriangle,
                suggestedProduct: nil
            ))
        }

        let fatPct = goals.fat > 0 ? todayNutrition.fat / goals.fat : 0
        if fatPct > 0.8 && proteinPct < 0.7 {
            recs.append(Recommendation(
                id: "rec_swap_fat_protein",
                type: .nutrition,
                title: "Swap Fat for Protein",
                description: "Your fat intake is high but protein is lagging. Try lean chicken breast or Greek yogurt.",
                icon: .arrowDownCircle,
                suggestedProduct: findLeanProtein()
            ))
        }

        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let recent = scannedItems.filter { $0.scannedAt >= sevenDaysAgo }
        if !recent.isEmpty {
            let avgSugar = recent.reduce(0.0) { $0 + $1.product.nutrition.sugar * Double($1.quantity) } / Double(recent.count)
            if avgSugar > 15 {
                recs.append(Recommendation(
                    id: "rec_high_sugar",
                    type: .nutrition,
                    title: "Lower-Sugar Alternative",
                    description: "Your recent items average \(Int(avgSugar.rounded()))g sugar each. Consider lower-sugar swaps.",
                    icon: .arrowDownCircle,
                    suggestedProduct: findLowSugar(in: scannedItems)
                ))
            }
        }

        // MARK: Budget

        let budgetPct = monthlyBudget > 0 ? monthlySpending / monthlyBudget : 0
        if budgetPct > 0.8 {
            let remaining = max(monthlyBudget - monthlySpending, 0)
            let cal = Calendar.current
            let now = Date()
            let range = cal.range(of: .day, in: .month, for: now) ?? 1..<31
            let daysInMonth = range.count
            let day = cal.component(.day, from: now)
            let daysLeft = max(daysInMonth - day, 1)
            let perDay = remaining / Double(daysLeft)
            recs.append(Recommendation(
                id: "rec_budget_warning",
                type: .budget,
                title: "Budget Warning",
                description: "You've used \(Int(budgetPct * 100))% of your monthly budget. You have $\(String(format: "%.2f", perDay))/day for the rest of the month.",
                icon: .alertTriangle,
                suggestedProduct: nil
            ))
        }

        var totalSavings = 0.0
        var savingsStore: StoreName?
        for item in scannedItems.prefix(20) {
            let boughtStore = item.store ?? preferredStore
            guard let bought = item.product.prices.first(where: { $0.store == boughtStore }) else { continue }
            guard let cheapest = item.product.prices.min(by: { $0.price < $1.price }) else { continue }
            if cheapest.store != boughtStore {
                let saving = (bought.price - cheapest.price) * Double(item.quantity)
                if saving > 0 {
                    totalSavings += saving
                    if savingsStore == nil { savingsStore = cheapest.store }
                }
            }
        }
        if totalSavings > 0.5, let store = savingsStore {
            recs.append(Recommendation(
                id: "rec_store_switch",
                type: .budget,
                title: "Save by Switching Stores",
                description: "You could save $\(String(format: "%.2f", totalSavings)) by buying some items at \(store.rawValue) instead.",
                icon: .piggyBank,
                suggestedProduct: nil
            ))
        }

        var categoryCounts: [ProductCategory: Int] = [:]
        for item in scannedItems {
            categoryCounts[item.product.category, default: 0] += item.quantity
        }
        if let top = categoryCounts.max(by: { $0.value < $1.value }), top.value >= 3 {
            recs.append(Recommendation(
                id: "rec_bulk_buying",
                type: .budget,
                title: "Try Bulk Buying",
                description: "You buy \(top.key.rawValue) frequently (\(top.value) items). Consider Costco for bulk deals long-term.",
                icon: .trendingDown,
                suggestedProduct: nil
            ))
        }

        return Array(recs.prefix(5))
    }

    // MARK: - Helpers (mock-product based — same as RN version)

    private static func findHighProtein() -> Product? {
        MockProducts.all.first { $0.nutrition.protein >= 15 }
    }

    private static func findHighFiber() -> Product? {
        MockProducts.all.first { $0.nutrition.fiber >= 3 }
    }

    private static func findLeanProtein() -> Product? {
        MockProducts.all.first { $0.nutrition.protein >= 15 && $0.nutrition.fat <= 3 }
    }

    private static func findLowSugar(in scannedItems: [ScannedItem]) -> Product? {
        let recentCategories = Set(scannedItems.prefix(10).map(\.product.category))
        return MockProducts.all.first {
            recentCategories.contains($0.category) && $0.nutrition.sugar <= 5
        }
    }
}
