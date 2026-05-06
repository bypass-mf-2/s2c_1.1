import Foundation
import Observation

@Observable
final class AppStore {
    var scannedItems: [ScannedItem]
    var settings: UserSettings
    var lastError: String?

    private let storage = Storage.shared

    init() {
        self.scannedItems = Storage.shared.loadScannedItems()
        self.settings = Storage.shared.loadSettings()
    }

    // MARK: - Scanned items

    func addItem(_ product: Product, store: StoreName? = nil, quantity: Int = 1) {
        let item = ScannedItem(
            id: UUID().uuidString,
            product: product,
            scannedAt: Date(),
            addedToCart: store != nil,
            store: store,
            quantity: quantity
        )
        scannedItems.insert(item, at: 0)
        storage.saveScannedItems(scannedItems)

        // Mirror to Apple Health if the user has it connected.
        let appleHealth = settings.healthApps.first(where: { $0.name == "Apple Health" })
        if appleHealth?.connected == true {
            Task { await HealthService.shared.logMeal(product, quantity: quantity) }
        }
    }

    func removeItem(id: String) {
        scannedItems.removeAll { $0.id == id }
        storage.saveScannedItems(scannedItems)
    }

    func updateQuantity(itemId: String, quantity: Int) {
        guard let idx = scannedItems.firstIndex(where: { $0.id == itemId }) else { return }
        scannedItems[idx].quantity = max(1, quantity)
        storage.saveScannedItems(scannedItems)
    }

    // MARK: - Settings

    func updateSettings(_ update: (inout UserSettings) -> Void) {
        update(&settings)
        storage.saveSettings(settings)
    }

    func toggleHealthApp(_ name: String) {
        guard let idx = settings.healthApps.firstIndex(where: { $0.name == name }) else { return }
        settings.healthApps[idx].connected.toggle()
        settings.healthApps[idx].lastSync = settings.healthApps[idx].connected ? Date() : nil
        storage.saveSettings(settings)

        // Apple Health is the only one we have a real integration for; the
        // others stay stubbed for now (UI toggles only).
        if name == "Apple Health" && settings.healthApps[idx].connected {
            Task {
                let granted = await HealthService.shared.requestAuthorization()
                if !granted {
                    // User declined — flip the toggle back to keep state honest.
                    settings.healthApps[idx].connected = false
                    settings.healthApps[idx].lastSync = nil
                    storage.saveSettings(settings)
                }
            }
        }
    }

    // MARK: - Derived

    var todayItems: [ScannedItem] {
        let cal = Calendar.current
        return scannedItems.filter { cal.isDateInToday($0.scannedAt) }
    }

    var todayNutrition: NutritionInfo {
        todayItems.reduce(into: NutritionInfo(calories: 0, protein: 0, carbs: 0, fat: 0, fiber: 0, sugar: 0, sodium: 0, servingSize: "")) { acc, item in
            let q = Double(item.quantity)
            let n = item.product.nutrition
            acc.calories += n.calories * q
            acc.protein += n.protein * q
            acc.carbs += n.carbs * q
            acc.fat += n.fat * q
            acc.fiber += n.fiber * q
            acc.sugar += n.sugar * q
            acc.sodium += n.sodium * q
        }
    }

    var monthlyItems: [ScannedItem] {
        let cal = Calendar.current
        let now = Date()
        return scannedItems.filter {
            cal.isDate($0.scannedAt, equalTo: now, toGranularity: .month)
        }
    }

    var monthlySpending: Double {
        monthlyItems.reduce(0) { total, item in
            let store = item.store ?? settings.preferredStore
            return total + item.product.price(at: store) * Double(item.quantity)
        }
    }

    var categorySpending: [(category: ProductCategory, amount: Double)] {
        var map: [ProductCategory: Double] = [:]
        for item in monthlyItems {
            let store = item.store ?? settings.preferredStore
            let amount = item.product.price(at: store) * Double(item.quantity)
            map[item.product.category, default: 0] += amount
        }
        return map.map { (category: $0.key, amount: $0.value) }
            .sorted { $0.amount > $1.amount }
    }

    // MARK: - History (derived from scannedItems)

    /// Daily calorie + spending totals for the last `days` days (oldest first,
    /// includes today). Days with no items return zero so chart x-axis is contiguous.
    func dailyHistory(days: Int) -> [DailyTotals] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let dates = (0..<days).reversed().compactMap {
            cal.date(byAdding: .day, value: -$0, to: today)
        }

        var byDay: [Date: DailyTotals] = [:]
        for date in dates {
            byDay[date] = DailyTotals(date: date, calories: 0, protein: 0, spending: 0)
        }

        for item in scannedItems {
            let day = cal.startOfDay(for: item.scannedAt)
            guard byDay[day] != nil else { continue }
            let q = Double(item.quantity)
            byDay[day]!.calories += item.product.nutrition.calories * q
            byDay[day]!.protein += item.product.nutrition.protein * q
            let s = item.store ?? settings.preferredStore
            byDay[day]!.spending += item.product.price(at: s) * q
        }

        return dates.compactMap { byDay[$0] }
    }

    /// Weekly totals (week starting Sunday) for the last `weeks` weeks.
    func weeklyHistory(weeks: Int) -> [WeeklyTotals] {
        let cal = Calendar.current
        let now = Date()
        guard let thisWeekStart = cal.dateInterval(of: .weekOfYear, for: now)?.start else { return [] }

        let starts = (0..<weeks).reversed().compactMap {
            cal.date(byAdding: .weekOfYear, value: -$0, to: thisWeekStart)
        }

        var byWeek: [Date: WeeklyTotals] = [:]
        for date in starts {
            byWeek[date] = WeeklyTotals(weekStart: date, calories: 0, protein: 0, spending: 0)
        }

        for item in scannedItems {
            guard let weekStart = cal.dateInterval(of: .weekOfYear, for: item.scannedAt)?.start,
                  byWeek[weekStart] != nil else { continue }
            let q = Double(item.quantity)
            byWeek[weekStart]!.calories += item.product.nutrition.calories * q
            byWeek[weekStart]!.protein += item.product.nutrition.protein * q
            let s = item.store ?? settings.preferredStore
            byWeek[weekStart]!.spending += item.product.price(at: s) * q
        }

        return starts.compactMap { byWeek[$0] }
    }

    var recommendations: [Recommendation] {
        RecommendationEngine.generate(
            todayNutrition: todayNutrition,
            goals: settings.nutritionGoals,
            monthlySpending: monthlySpending,
            monthlyBudget: settings.monthlyBudget,
            scannedItems: scannedItems,
            preferredStore: settings.preferredStore
        )
    }

    func recommendations(of type: RecommendationType) -> [Recommendation] {
        recommendations.filter { $0.type == type }
    }

    // MARK: - Search

    /// Searches Open Food Facts + USDA FoodData Central in parallel, merged
    /// with local mocks (only on page 1). Pages 2+ skip mocks since those
    /// are already shown.
    func search(query: String, page: Int = 1) async -> [Product] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }

        let localHits: [Product]
        if page == 1 {
            let lower = trimmed.lowercased()
            localHits = MockProducts.all.filter {
                $0.name.lowercased().contains(lower) || $0.brand.lowercased().contains(lower)
            }
        } else {
            localHits = []
        }

        async let off = FoodDatabase.shared.search(query: trimmed, page: page)
        async let usda = FoodDatabase.shared.searchUSDA(query: trimmed, page: page)
        let (offHits, usdaHits) = await (off, usda)

        var seenIDs = Set(localHits.map(\.id))
        var merged = localHits

        for hit in offHits where !seenIDs.contains(hit.id) {
            merged.append(hit)
            seenIDs.insert(hit.id)
        }
        for hit in usdaHits where !seenIDs.contains(hit.id) {
            merged.append(hit)
            seenIDs.insert(hit.id)
        }
        return merged
    }

    func lookup(barcode: String) async -> Product? {
        await FoodDatabase.shared.lookup(barcode: barcode)
    }
}