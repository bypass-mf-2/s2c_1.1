import SwiftUI

enum HealthLevel: String, Codable {
    case excellent
    case good
    case fair
    case poor
    case bad

    var label: String {
        switch self {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .fair: return "Fair"
        case .poor: return "Poor"
        case .bad: return "Bad"
        }
    }

    var color: Color {
        switch self {
        case .excellent: return Color(red: 0.13, green: 0.66, blue: 0.36)
        case .good: return Color(red: 0.45, green: 0.78, blue: 0.32)
        case .fair: return Color(red: 0.97, green: 0.78, blue: 0.18)
        case .poor: return Color(red: 0.95, green: 0.55, blue: 0.20)
        case .bad: return Color(red: 0.90, green: 0.30, blue: 0.24)
        }
    }
}

struct HealthScore: Hashable {
    let score: Int
    let level: HealthLevel
    let grade: String?

    static func compute(nutrition: NutritionInfo, nutriScoreGrade: String?) -> HealthScore {
        if let grade = nutriScoreGrade?.lowercased(), let mapped = fromNutriScore(grade) {
            return mapped
        }
        return fromNutrition(nutrition)
    }

    private static func fromNutriScore(_ grade: String) -> HealthScore? {
        switch grade {
        case "a": return HealthScore(score: 90, level: .excellent, grade: "A")
        case "b": return HealthScore(score: 70, level: .good, grade: "B")
        case "c": return HealthScore(score: 50, level: .fair, grade: "C")
        case "d": return HealthScore(score: 30, level: .poor, grade: "D")
        case "e": return HealthScore(score: 10, level: .bad, grade: "E")
        default: return nil
        }
    }

    /// Heuristic fallback when Open Food Facts has no Nutri-Score for the
    /// product. Loosely models the Nutri-Score weighting (calories, sugar,
    /// sodium are negative; fiber, protein are positive). Score is clamped 0–100.
    private static func fromNutrition(_ n: NutritionInfo) -> HealthScore {
        var score = 70.0

        if n.calories > 400 { score -= 25 }
        else if n.calories > 250 { score -= 12 }
        else if n.calories < 80 { score += 5 }

        if n.sugar > 22 { score -= 25 }
        else if n.sugar > 10 { score -= 12 }
        else if n.sugar < 2 { score += 6 }

        if n.sodium > 0.6 { score -= 18 }
        else if n.sodium > 0.3 { score -= 8 }

        if n.fat > 17 { score -= 12 }
        else if n.fat > 10 { score -= 6 }

        if n.fiber > 6 { score += 12 }
        else if n.fiber > 3 { score += 6 }

        if n.protein > 12 { score += 10 }
        else if n.protein > 6 { score += 5 }

        let clamped = max(0, min(100, Int(score.rounded())))
        return HealthScore(score: clamped, level: levelFor(clamped), grade: nil)
    }

    private static func levelFor(_ score: Int) -> HealthLevel {
        switch score {
        case 80...: return .excellent
        case 60..<80: return .good
        case 40..<60: return .fair
        case 20..<40: return .poor
        default: return .bad
        }
    }
}
