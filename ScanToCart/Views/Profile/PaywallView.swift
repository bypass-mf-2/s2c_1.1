import SwiftUI
import RevenueCat

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var subscription = SubscriptionService.shared

    @State private var purchasing = false
    @State private var loading = true
    @State private var purchaseError: String?

    private let features = [
        "Scan any barcode for instant product info",
        "Track nutrition & macros daily",
        "Compare prices across 7 major stores",
        "Find nearby stores with location",
        "Yuka-style health scores",
        "Smart shopping lists",
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header
                    featureList
                    priceCard
                    actions
                    legal
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Maybe later") { dismiss() }
                }
            }
            .alert("Purchase failed", isPresented: .constant(purchaseError != nil), presenting: purchaseError) { _ in
                Button("OK") { purchaseError = nil }
            } message: { Text($0) }
            .task {
                await subscription.loadOfferings()
                loading = false
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundStyle(Theme.accent)
            Text("Unlock Premium")
                .font(.largeTitle.weight(.bold))
            Text("Start your free trial — cancel anytime.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 12)
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(features, id: \.self) { feature in
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.accent)
                    Text(feature)
                        .font(.subheadline)
                    Spacer()
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    @ViewBuilder
    private var priceCard: some View {
        if let pkg = monthlyPackage {
            VStack(spacing: 6) {
                Text("Monthly")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .textCase(.uppercase)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(pkg.localizedPriceString)
                        .font(.system(size: 36, weight: .bold))
                    Text("/month")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
                Text("Start with a free trial")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardCornerRadius)
                    .strokeBorder(Theme.accent, lineWidth: 2)
            )
        } else if loading {
            ProgressView().frame(height: 100)
        } else {
            Text("Pricing unavailable")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding()
                .cardStyle()
        }
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button {
                guard let pkg = monthlyPackage else { return }
                Task { await purchase(pkg) }
            } label: {
                Group {
                    if purchasing {
                        ProgressView().tint(.white)
                    } else {
                        Text("Start Free Trial")
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .disabled(monthlyPackage == nil || purchasing)

            Button {
                Task { await restore() }
            } label: {
                Text("Restore Purchase")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
            .disabled(purchasing)
        }
    }

    private var legal: some View {
        Text("Payment is charged to your App Store account after the free trial. Subscription renews automatically unless cancelled at least 24 hours before the period ends.")
            .font(.caption2)
            .foregroundStyle(Theme.textSecondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
    }

    private var monthlyPackage: Package? {
        subscription.availablePackages.first(where: { $0.packageType == .monthly })
            ?? subscription.availablePackages.first
    }

    private func purchase(_ package: Package) async {
        purchasing = true
        defer { purchasing = false }
        do {
            let success = try await subscription.purchase(package)
            if success { dismiss() }
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    private func restore() async {
        purchasing = true
        defer { purchasing = false }
        let success = await subscription.restore()
        if success {
            dismiss()
        } else {
            purchaseError = "No active subscription found for your account."
        }
    }
}
