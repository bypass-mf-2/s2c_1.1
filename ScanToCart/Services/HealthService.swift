import Foundation
import HealthKit

/// Wraps HealthKit reads/writes for nutrition data. Each call gracefully
/// degrades to no-op when HealthKit isn't available (simulator, denied auth).
@MainActor
@Observable
final class HealthService {
    static let shared = HealthService()

    private let store = HKHealthStore()
    private(set) var isAuthorized = false

    private var writeTypes: Set<HKSampleType> {
        var set: Set<HKSampleType> = []
        for id in writeIdentifiers {
            if let type = HKObjectType.quantityType(forIdentifier: id) {
                set.insert(type)
            }
        }
        return set
    }

    private let writeIdentifiers: [HKQuantityTypeIdentifier] = [
        .dietaryEnergyConsumed,
        .dietaryProtein,
        .dietaryCarbohydrates,
        .dietaryFatTotal,
        .dietaryFiber,
        .dietarySugar,
        .dietarySodium
    ]

    func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        do {
            try await store.requestAuthorization(toShare: writeTypes, read: [])
            isAuthorized = true
            return true
        } catch {
            isAuthorized = false
            return false
        }
    }

    /// Writes the nutrition for one logged item to HealthKit. Silently does
    /// nothing if not authorized — the user can flip Apple Health off in
    /// Profile if they don't want this.
    func logMeal(_ product: Product, quantity: Int) async {
        guard isAuthorized else { return }
        let q = Double(quantity)
        let n = product.nutrition

        let now = Date()
        var samples: [HKQuantitySample] = []

        func sample(_ id: HKQuantityTypeIdentifier, _ unit: HKUnit, _ value: Double) -> HKQuantitySample? {
            guard value > 0, let type = HKObjectType.quantityType(forIdentifier: id) else { return nil }
            let qty = HKQuantity(unit: unit, doubleValue: value)
            return HKQuantitySample(
                type: type,
                quantity: qty,
                start: now,
                end: now,
                metadata: [HKMetadataKeyFoodType: product.name]
            )
        }

        if let s = sample(.dietaryEnergyConsumed, .kilocalorie(), n.calories * q) { samples.append(s) }
        if let s = sample(.dietaryProtein, .gram(), n.protein * q) { samples.append(s) }
        if let s = sample(.dietaryCarbohydrates, .gram(), n.carbs * q) { samples.append(s) }
        if let s = sample(.dietaryFatTotal, .gram(), n.fat * q) { samples.append(s) }
        if let s = sample(.dietaryFiber, .gram(), n.fiber * q) { samples.append(s) }
        if let s = sample(.dietarySugar, .gram(), n.sugar * q) { samples.append(s) }
        if let s = sample(.dietarySodium, .gramUnit(with: .milli), n.sodium * q * 1000) { samples.append(s) }

        guard !samples.isEmpty else { return }
        try? await store.save(samples)
    }
}
