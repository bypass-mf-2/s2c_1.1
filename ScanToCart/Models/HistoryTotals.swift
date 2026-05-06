import Foundation

struct DailyTotals: Identifiable, Hashable {
    let date: Date
    var calories: Double
    var protein: Double
    var spending: Double
    var id: Date { date }
}

struct WeeklyTotals: Identifiable, Hashable {
    let weekStart: Date
    var calories: Double
    var protein: Double
    var spending: Double
    var id: Date { weekStart }
}
