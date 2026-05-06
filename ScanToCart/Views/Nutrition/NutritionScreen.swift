import SwiftUI
import Charts

struct NutritionScreen: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    todaySummary
                    macros
                    historyChart
                    tipsSection
                    todayMeals
                }
                .padding()
            }
            .navigationTitle("Nutrition")
        }
    }

    private var historyChart: some View {
        let history = store.dailyHistory(days: 7)
        let goal = store.settings.nutritionGoals.calories

        return VStack(alignment: .leading, spacing: 12) {
            Text("Last 7 days")
                .font(.headline)

            Chart {
                ForEach(history) { day in
                    BarMark(
                        x: .value("Day", day.date, unit: .day),
                        y: .value("Calories", day.calories)
                    )
                    .foregroundStyle(Theme.accent)
                    .cornerRadius(4)
                }
                RuleMark(y: .value("Goal", goal))
                    .foregroundStyle(Theme.warmAccent)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("Goal \(Int(goal))")
                            .font(.caption2)
                            .foregroundStyle(Theme.warmAccent)
                    }
            }
            .frame(height: 180)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisValueLabel(format: .dateTime.weekday(.narrow))
                    AxisGridLine()
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    if let cals = value.as(Double.self) {
                        AxisValueLabel { Text("\(Int(cals))") }
                        AxisGridLine()
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var todaySummary: some View {
        VStack(spacing: 12) {
            Text("Today")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 16) {
                ProgressRing(
                    progress: store.todayNutrition.calories / store.settings.nutritionGoals.calories,
                    label: "Calories",
                    value: "\(Int(store.todayNutrition.calories))",
                    color: Theme.accent,
                    size: 110
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Goal")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                    Text("\(Int(store.settings.nutritionGoals.calories)) cal")
                        .font(.title3.weight(.semibold))
                    Divider().padding(.vertical, 4)
                    Text("Remaining")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                    Text("\(Int(max(0, store.settings.nutritionGoals.calories - store.todayNutrition.calories))) cal")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .cardStyle()
    }

    private var macros: some View {
        VStack(spacing: 16) {
            Text("Macros")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            MacroBar(
                label: "Protein",
                current: store.todayNutrition.protein,
                goal: store.settings.nutritionGoals.protein,
                unit: "g",
                color: .blue
            )
            MacroBar(
                label: "Carbs",
                current: store.todayNutrition.carbs,
                goal: store.settings.nutritionGoals.carbs,
                unit: "g",
                color: .orange
            )
            MacroBar(
                label: "Fat",
                current: store.todayNutrition.fat,
                goal: store.settings.nutritionGoals.fat,
                unit: "g",
                color: .purple
            )
            MacroBar(
                label: "Fiber",
                current: store.todayNutrition.fiber,
                goal: 30,
                unit: "g",
                color: .green
            )
        }
        .padding()
        .cardStyle()
    }

    @ViewBuilder
    private var tipsSection: some View {
        let tips = store.recommendations(of: .nutrition)
        if !tips.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Tips for you")
                    .font(.headline)
                ForEach(tips) { tip in
                    RecommendationCard(recommendation: tip)
                }
            }
        }
    }

    @ViewBuilder
    private var todayMeals: some View {
        if !store.todayItems.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Meals today")
                    .font(.headline)
                ForEach(store.todayItems) { item in
                    ProductCard(product: item.product, store: item.store ?? store.settings.preferredStore)
                }
            }
        } else {
            Text("No meals logged today. Scan a barcode to add one.")
                .font(.callout)
                .foregroundStyle(Theme.textSecondary)
                .padding()
                .frame(maxWidth: .infinity)
                .cardStyle()
        }
    }
}