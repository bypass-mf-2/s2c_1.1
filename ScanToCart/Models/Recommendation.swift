import Foundation

enum RecommendationType: String, Codable {
    case nutrition
    case budget
}

enum RecommendationIcon: String {
    case zap = "bolt.fill"
    case leaf = "leaf.fill"
    case alertTriangle = "exclamationmark.triangle.fill"
    case arrowDownCircle = "arrow.down.circle.fill"
    case piggyBank = "banknote.fill"
    case trendingDown = "chart.line.downtrend.xyaxis"
}

struct Recommendation: Identifiable, Hashable {
    let id: String
    let type: RecommendationType
    let title: String
    let description: String
    let icon: RecommendationIcon
    let suggestedProduct: Product?
}
