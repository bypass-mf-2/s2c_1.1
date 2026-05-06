import SwiftUI

struct ProgressRing: View {
    let progress: Double
    let label: String
    let value: String
    let color: Color
    var size: CGFloat = 80

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.15), lineWidth: 8)

                Circle()
                    .trim(from: 0, to: min(max(progress, 0), 1))
                    .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.6), value: progress)

                Text(value)
                    .font(.system(size: size * 0.22, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
            }
            .frame(width: size, height: size)

            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
    }
}

#Preview {
    HStack(spacing: 24) {
        ProgressRing(progress: 0.65, label: "Calories", value: "1300", color: Theme.accent)
        ProgressRing(progress: 0.45, label: "Protein", value: "54g", color: .blue)
        ProgressRing(progress: 0.30, label: "Carbs", value: "75g", color: .orange)
    }
    .padding()
}