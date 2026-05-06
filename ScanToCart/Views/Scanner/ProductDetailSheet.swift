import SwiftUI

struct ProductDetailSheet: View {
    let product: Product
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var selectedStore: StoreName = .target
    @State private var quantity: Int = 1
    @State private var showingNearby = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header

                    HealthScoreBadge(score: product.healthScore)

                    nutritionPanel

                    storePicker

                    actionButtons
                }
                .padding()
            }
            .navigationTitle(product.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .onAppear { selectedStore = store.settings.preferredStore }
        .sheet(isPresented: $showingNearby) {
            NearbyStoresView(product: product)
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            if let url = URL(string: product.imageURL), !product.imageURL.isEmpty {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFit()
                    default:
                        placeholderImage
                    }
                }
                .frame(height: 160)
            } else {
                placeholderImage.frame(height: 160)
            }

            VStack(spacing: 4) {
                Text(product.brand).font(.subheadline).foregroundStyle(Theme.textSecondary)
                Text(product.category.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.accentSoft)
                    .foregroundStyle(Theme.accent)
                    .clipShape(Capsule())
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .cardStyle()
    }

    private var placeholderImage: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Theme.accentSoft)
            .overlay {
                Image(systemName: "basket")
                    .font(.system(size: 48))
                    .foregroundStyle(Theme.accent)
            }
    }

    private var nutritionPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nutrition")
                .font(.headline)
            Text("Per \(product.nutrition.servingSize)")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)

            HStack {
                nutritionStat("Calories", value: "\(Int(product.nutrition.calories))", color: Theme.accent)
                nutritionStat("Protein", value: "\(Int(product.nutrition.protein))g", color: .blue)
                nutritionStat("Carbs", value: "\(Int(product.nutrition.carbs))g", color: .orange)
                nutritionStat("Fat", value: "\(Int(product.nutrition.fat))g", color: .purple)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func nutritionStat(_ label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var storePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Compare prices")
                    .font(.headline)
                Spacer()
                Button {
                    showingNearby = true
                } label: {
                    Label("Nearby", systemImage: "location.fill")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(Theme.accent)
            }

            ForEach(product.prices) { entry in
                HStack {
                    Text(entry.store.rawValue)
                        .font(.subheadline)
                        .foregroundStyle(entry.store == selectedStore ? Theme.accent : Theme.textPrimary)
                    Spacer()
                    Text(String(format: "$%.2f", entry.price))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                    if entry.store == selectedStore {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { selectedStore = entry.store }
                .padding(.vertical, 6)

                if entry.id != product.prices.last?.id {
                    Divider()
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Quantity")
                    .font(.subheadline)
                Spacer()
                Stepper("\(quantity)", value: $quantity, in: 1...20)
                    .labelsHidden()
                Text("\(quantity)").font(.subheadline.weight(.semibold)).monospacedDigit()
            }
            .padding(.horizontal)

            Button {
                store.addItem(product, store: selectedStore, quantity: quantity)
                dismiss()
            } label: {
                Label("Add to \(selectedStore.rawValue) cart", systemImage: "cart.badge.plus")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)

            Button {
                store.addItem(product, store: nil, quantity: quantity)
                dismiss()
            } label: {
                Text("Log without adding to cart")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
            .tint(Theme.textSecondary)
        }
    }
}