import SwiftUI

struct DisclaimerBanner: View {
    @AppStorage("scantocart.dismissedDisclaimerV1") private var dismissed = false

    var body: some View {
        if !dismissed {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(Theme.warmAccent)
                    .font(.subheadline)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Beta — limited price data")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Real prices currently work for Kroger when connected. Other stores show estimates while we partner with each chain. Connect Kroger in Profile for live data.")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Button {
                    withAnimation { dismissed = true }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .padding(6)
                }
            }
            .padding(12)
            .background(Theme.warmAccentSoft)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Theme.warmAccent.opacity(0.3), lineWidth: 1)
            )
        }
    }
}
