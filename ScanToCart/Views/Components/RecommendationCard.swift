import SwiftUI

struct RecommendationCard: View {
    let recommendation: Recommendation
    var onSuggestedTap: ((Product) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: recommendation.icon.rawValue)
                        .foregroundStyle(accentColor)
                        .font(.system(size: 16, weight: .semibold))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(recommendation.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(recommendation.description)
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let product = recommendation.suggestedProduct {
                Button {
                    onSuggestedTap?(product)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.caption)
                        Text("Try \(product.name)")
                            .font(.caption.weight(.medium))
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                    }
                    .foregroundStyle(accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(accentColor.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var accentColor: Color {
        switch recommendation.type {
        case .nutrition: return Theme.accent
        case .budget: return Theme.warmAccent
        }
    }
}
