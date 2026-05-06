import SwiftUI

struct ProductCard: View {
    let product: Product
    let store: StoreName
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: 12) {
                productImage

                VStack(alignment: .leading, spacing: 4) {
                    Text(product.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(2)
                    Text(product.brand)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)

                    HStack(spacing: 6) {
                        nutritionBadge("\(Int(product.nutrition.calories)) cal")
                        nutritionBadge("\(Int(product.nutrition.protein))g pro")
                    }
                    .padding(.top, 2)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "$%.2f", product.price(at: store)))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .monospacedDigit()
                    Text(store.rawValue)
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary)

                    let hs = product.healthScore
                    Text("\(hs.score)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(hs.level.color)
                        .clipShape(Circle())
                }
            }
            .padding(12)
            .cardStyle()
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var productImage: some View {
        if let url = URL(string: product.imageURL), !product.imageURL.isEmpty {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    fallbackImage
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            fallbackImage
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private var fallbackImage: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Theme.accentSoft)
            .overlay {
                Image(systemName: "basket")
                    .foregroundStyle(Theme.accent)
            }
    }

    private func nutritionBadge(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Theme.accentSoft)
            .foregroundStyle(Theme.accent)
            .clipShape(Capsule())
    }
}