import SwiftUI

struct MacroBar: View {
    let label: String
    let current: Double
    let goal: Double
    let unit: String
    let color: Color

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(max(current / goal, 0), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("\(Int(current))/\(Int(goal))\(unit)")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .monospacedDigit()
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.15))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geo.size.width * progress)
                        .animation(.easeOut(duration: 0.4), value: progress)
                }
            }
            .frame(height: 8)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        MacroBar(label: "Protein", current: 54, goal: 120, unit: "g", color: .blue)
        MacroBar(label: "Carbs", current: 180, goal: 250, unit: "g", color: .orange)
        MacroBar(label: "Fat", current: 38, goal: 65, unit: "g", color: .purple)
    }
    .padding()
}