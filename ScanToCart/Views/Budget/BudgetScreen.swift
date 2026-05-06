import SwiftUI
import Charts

struct BudgetScreen: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    overview
                    weeklyTrendChart
                    if !store.categorySpending.isEmpty {
                        categoryChart
                    }
                    tipsSection
                    budgetSettings
                }
                .padding()
            }
            .navigationTitle("Budget")
        }
    }

    private var overview: some View {
        let pct = store.settings.monthlyBudget > 0
            ? min(store.monthlySpending / store.settings.monthlyBudget, 1)
            : 0
        let remaining = max(0, store.settings.monthlyBudget - store.monthlySpending)
        let isOver = store.monthlySpending > store.settings.monthlyBudget

        return VStack(alignment: .leading, spacing: 12) {
            Text("This month")
                .font(.headline)

            HStack(alignment: .firstTextBaseline) {
                Text(String(format: "$%.2f", store.monthlySpending))
                    .font(.system(size: 36, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(String(format: "/ $%.0f", store.settings.monthlyBudget))
                    .font(.title3)
                    .foregroundStyle(Theme.textSecondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Theme.warmAccentSoft)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isOver ? .red : Theme.warmAccent)
                        .frame(width: geo.size.width * pct)
                }
            }
            .frame(height: 12)

            HStack {
                Image(systemName: isOver ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(isOver ? .red : Theme.accent)
                Text(isOver
                     ? "Over budget by $\(String(format: "%.2f", store.monthlySpending - store.settings.monthlyBudget))"
                     : "$\(String(format: "%.2f", remaining)) remaining")
                    .font(.callout)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var weeklyTrendChart: some View {
        let weeks = store.weeklyHistory(weeks: 4)
        let weeklyTarget = store.settings.monthlyBudget / 4

        return VStack(alignment: .leading, spacing: 12) {
            Text("Last 4 weeks")
                .font(.headline)

            Chart {
                ForEach(weeks) { week in
                    BarMark(
                        x: .value("Week", week.weekStart, unit: .weekOfYear),
                        y: .value("Spend", week.spending)
                    )
                    .foregroundStyle(Theme.warmAccent)
                    .cornerRadius(4)
                }
                if weeklyTarget > 0 {
                    RuleMark(y: .value("Weekly target", weeklyTarget))
                        .foregroundStyle(Theme.accent)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("Target $\(Int(weeklyTarget))")
                                .font(.caption2)
                                .foregroundStyle(Theme.accent)
                        }
                }
            }
            .frame(height: 180)
            .chartXAxis {
                AxisMarks(values: .stride(by: .weekOfYear)) { value in
                    if let date = value.as(Date.self) {
                        AxisValueLabel {
                            Text(date.formatted(.dateTime.month(.abbreviated).day()))
                                .font(.caption2)
                        }
                        AxisGridLine()
                    }
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    if let amount = value.as(Double.self) {
                        AxisValueLabel { Text("$\(Int(amount))") }
                        AxisGridLine()
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var categoryChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("By category")
                .font(.headline)

            Chart(store.categorySpending, id: \.category) { entry in
                BarMark(
                    x: .value("Amount", entry.amount),
                    y: .value("Category", entry.category.rawValue)
                )
                .foregroundStyle(Theme.warmAccent)
                .cornerRadius(4)
            }
            .frame(height: CGFloat(store.categorySpending.count) * 36 + 24)
            .chartXAxis {
                AxisMarks { value in
                    if let amount = value.as(Double.self) {
                        AxisValueLabel { Text("$\(Int(amount))") }
                        AxisGridLine()
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    @ViewBuilder
    private var tipsSection: some View {
        let tips = store.recommendations(of: .budget)
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

    private var budgetSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Monthly limit")
                .font(.headline)

            HStack {
                Text("$")
                    .font(.title3)
                    .foregroundStyle(Theme.textSecondary)
                TextField("Budget", value: Binding(
                    get: { store.settings.monthlyBudget },
                    set: { newValue in
                        store.updateSettings { $0.monthlyBudget = max(0, newValue) }
                    }
                ), format: .number)
                .keyboardType(.decimalPad)
                .font(.title3.weight(.semibold))
                .padding(8)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}