import SwiftUI

struct ListsScreen: View {
    @Environment(AppStore.self) private var store
    @State private var kroger = KrogerService.shared
    @State private var sendingToKroger = false
    @State private var krogerStatus: String?

    var body: some View {
        NavigationStack {
            Group {
                if store.scannedItems.isEmpty {
                    emptyState
                } else {
                    listView
                }
            }
            .navigationTitle("Cart")
            .alert("Kroger", isPresented: .constant(krogerStatus != nil), presenting: krogerStatus) { _ in
                Button("OK") { krogerStatus = nil }
            } message: { Text($0) }
        }
        .task { await kroger.bootstrap() }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "cart")
                .font(.system(size: 56))
                .foregroundStyle(Theme.textSecondary)
            Text("Your cart is empty")
                .font(.headline)
            Text("Scan products and add them to your cart to see them here.")
                .font(.callout)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var listView: some View {
        List {
            Section {
                HStack {
                    Text("Total")
                        .font(.headline)
                    Spacer()
                    Text(String(format: "$%.2f", totalCost))
                        .font(.headline)
                        .monospacedDigit()
                }
                HStack {
                    Text("Items")
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Text("\(store.scannedItems.reduce(0) { $0 + $1.quantity })")
                        .monospacedDigit()
                }
            }

            Section("Items") {
                ForEach(store.scannedItems) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.product.name)
                                .font(.subheadline.weight(.medium))
                                .lineLimit(2)
                            HStack(spacing: 6) {
                                Text(item.store?.rawValue ?? "Logged")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Theme.accentSoft)
                                    .foregroundStyle(Theme.accent)
                                    .clipShape(Capsule())
                                Text("× \(item.quantity)")
                                    .font(.caption)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                        Spacer()
                        Text(String(format: "$%.2f", lineCost(for: item)))
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        store.removeItem(id: store.scannedItems[index].id)
                    }
                }
            }

            Section("Send to store") {
                krogerCartButton
            }
        }
    }

    @ViewBuilder
    private var krogerCartButton: some View {
        Button {
            Task { await sendToKroger() }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "cart.fill.badge.plus")
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                VStack(alignment: .leading, spacing: 2) {
                    Text(kroger.isConnected ? "Send to Kroger cart" : "Connect Kroger")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(kroger.isConnected
                         ? "Add \(krogerEligibleCount) items to your online cart"
                         : "Sign in to push your list to Kroger.com")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                if sendingToKroger {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
        .disabled(sendingToKroger)
    }

    private var krogerEligibleCount: Int {
        store.scannedItems
            .filter { !$0.product.barcode.isEmpty }
            .reduce(0) { $0 + $1.quantity }
    }

    private func sendToKroger() async {
        if !kroger.isConnected {
            sendingToKroger = true
            await kroger.connect()
            sendingToKroger = false
            return
        }
        let items = store.scannedItems
            .filter { !$0.product.barcode.isEmpty }
            .map { (upc: $0.product.barcode, quantity: $0.quantity) }
        guard !items.isEmpty else {
            krogerStatus = "Items must have a barcode to send to Kroger."
            return
        }

        sendingToKroger = true
        let result = await kroger.addToCart(items: items)
        sendingToKroger = false
        switch result {
        case .success(let count):
            krogerStatus = "Added \(count) items to your Kroger cart."
        case .failure(let err):
            krogerStatus = err.message
        }
    }

    private var totalCost: Double {
        store.scannedItems.reduce(0) { $0 + lineCost(for: $1) }
    }

    private func lineCost(for item: ScannedItem) -> Double {
        let storeName = item.store ?? store.settings.preferredStore
        return item.product.price(at: storeName) * Double(item.quantity)
    }
}
