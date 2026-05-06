import SwiftUI

struct HomeScreen: View {
    @Environment(AppStore.self) private var store
    @State private var auth = AuthService.shared
    @Binding var selectedTab: AppTab

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    greeting
                    DisclaimerBanner()
                    nutritionCard
                    spendingCard
                    scanButton
                    recentScansSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Good \(timeOfDay),")
                .font(.title3)
                .foregroundStyle(Theme.textSecondary)
            Text(name)
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(Theme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    private var name: String {
        if case .signedIn(let profile) = auth.state {
            return profile.greetingName
        }
        return "there"
    }

    private var timeOfDay: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "morning"
        case 12..<17: return "afternoon"
        default: return "evening"
        }
    }

    private var nutritionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Nutrition")
                    .font(.headline)
                Spacer()
                Button("View all") { selectedTab = .nutrition }
                    .font(.caption)
                    .tint(Theme.accent)
            }

            HStack(spacing: 16) {
                ProgressRing(
                    progress: store.todayNutrition.calories / store.settings.nutritionGoals.calories,
                    label: "Calories",
                    value: "\(Int(store.todayNutrition.calories))",
                    color: Theme.accent
                )
                ProgressRing(
                    progress: store.todayNutrition.protein / store.settings.nutritionGoals.protein,
                    label: "Protein",
                    value: "\(Int(store.todayNutrition.protein))g",
                    color: .blue
                )
                ProgressRing(
                    progress: store.todayNutrition.carbs / store.settings.nutritionGoals.carbs,
                    label: "Carbs",
                    value: "\(Int(store.todayNutrition.carbs))g",
                    color: .orange
                )
                ProgressRing(
                    progress: store.todayNutrition.fat / store.settings.nutritionGoals.fat,
                    label: "Fat",
                    value: "\(Int(store.todayNutrition.fat))g",
                    color: .purple
                )
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .cardStyle()
    }

    private var spendingCard: some View {
        let pct = store.settings.monthlyBudget > 0
            ? min(store.monthlySpending / store.settings.monthlyBudget, 1)
            : 0

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("This month")
                    .font(.headline)
                Spacer()
                Button("Budget") { selectedTab = .budget }
                    .font(.caption)
                    .tint(Theme.warmAccent)
            }

            HStack(alignment: .firstTextBaseline) {
                Text(String(format: "$%.2f", store.monthlySpending))
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(String(format: "/ $%.0f", store.settings.monthlyBudget))
                    .font(.callout)
                    .foregroundStyle(Theme.textSecondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.warmAccentSoft)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.warmAccent)
                        .frame(width: geo.size.width * pct)
                }
            }
            .frame(height: 8)
        }
        .padding()
        .cardStyle()
    }

    private var scanButton: some View {
        Button {
            selectedTab = .scanner
        } label: {
            HStack {
                Image(systemName: "barcode.viewfinder")
                    .font(.title2)
                Text("Scan a product")
                    .font(.headline)
                Spacer()
                Image(systemName: "arrow.right")
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Theme.accent)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    @ViewBuilder
    private var recentScansSection: some View {
        if store.scannedItems.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "tray")
                    .font(.system(size: 40))
                    .foregroundStyle(Theme.textSecondary)
                Text("No scans yet")
                    .font(.headline)
                Text("Scan a barcode to start tracking nutrition and spending.")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
            .padding(.horizontal)
            .cardStyle()
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("Recent")
                    .font(.headline)
                ForEach(store.scannedItems.prefix(5)) { item in
                    ProductCard(product: item.product, store: item.store ?? store.settings.preferredStore)
                }
            }
        }
    }
}