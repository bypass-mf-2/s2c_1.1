import SwiftUI

enum Theme {
    static let accent = Color(red: 0.039, green: 0.561, blue: 0.424)
    static let accentSoft = Color(red: 0.039, green: 0.561, blue: 0.424).opacity(0.12)
    static let warmAccent = Color(red: 0.95, green: 0.55, blue: 0.20)
    static let warmAccentSoft = Color(red: 0.95, green: 0.55, blue: 0.20).opacity(0.12)

    static let background = Color(.systemBackground)
    static let card = Color(.secondarySystemBackground)
    static let border = Color(.separator).opacity(0.5)
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary

    static let cardCornerRadius: CGFloat = 16
    static let cardShadowRadius: CGFloat = 8
    static let cardShadowOpacity: Double = 0.04
}

extension View {
    func cardStyle() -> some View {
        self
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
            .shadow(color: .black.opacity(Theme.cardShadowOpacity), radius: Theme.cardShadowRadius, y: 2)
    }
}