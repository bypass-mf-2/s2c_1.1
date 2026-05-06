import SwiftUI

struct HealthScoreBadge: View {
    let score: HealthScore

    var body: some View {
        HStack(spacing: 14) {
            scoreCircle

            VStack(alignment: .leading, spacing: 2) {
                Text(score.level.label)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(score.level.color)
                Text(captionText)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(score.level.color.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius)
                .strokeBorder(score.level.color.opacity(0.3), lineWidth: 1)
        )
    }

    private var scoreCircle: some View {
        ZStack {
            Circle()
                .stroke(score.level.color.opacity(0.2), lineWidth: 5)
                .frame(width: 56, height: 56)
            Circle()
                .trim(from: 0, to: CGFloat(score.score) / 100)
                .stroke(score.level.color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .frame(width: 56, height: 56)
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(score.score)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(score.level.color)
                Text("/100")
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private var captionText: String {
        if let grade = score.grade {
            return "Nutri-Score \(grade) · health rating"
        }
        return "Estimated from nutrition"
    }
}
