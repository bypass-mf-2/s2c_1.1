import SwiftUI

struct ProfileScreen: View {
    @Environment(AppStore.self) private var store
    @State private var subscription = SubscriptionService.shared
    @State private var auth = AuthService.shared
    @State private var kroger = KrogerService.shared
    @State private var showingPaywall = false
    @State private var showingEditProfile = false
    @State private var showingDeleteConfirm = false
    @State private var deleting = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        showingPaywall = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "sparkles")
                                .foregroundStyle(.white)
                                .frame(width: 28, height: 28)
                                .background(Theme.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(subscription.isPremium ? "Premium active" : "Unlock Premium")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.textPrimary)
                                Text(subscription.isPremium
                                     ? "Thanks for supporting Scan to Cart"
                                     : "Free trial · cancel anytime")
                                    .font(.caption)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            Spacer()
                            if !subscription.isPremium {
                                Image(systemName: "chevron.right")
                                    .font(.footnote)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .disabled(subscription.isPremium)
                }

                Section("Preferred store") {
                    Picker("Store", selection: Binding(
                        get: { store.settings.preferredStore },
                        set: { newValue in store.updateSettings { $0.preferredStore = newValue } }
                    )) {
                        ForEach(StoreName.allCases) { Text($0.rawValue).tag($0) }
                    }
                }

                Section("Daily nutrition goals") {
                    nutritionStepper(
                        label: "Calories",
                        binding: bindingFor(\.calories),
                        range: 1000...4000,
                        step: 50
                    )
                    nutritionStepper(
                        label: "Protein (g)",
                        binding: bindingFor(\.protein),
                        range: 30...300,
                        step: 5
                    )
                    nutritionStepper(
                        label: "Carbs (g)",
                        binding: bindingFor(\.carbs),
                        range: 50...500,
                        step: 10
                    )
                    nutritionStepper(
                        label: "Fat (g)",
                        binding: bindingFor(\.fat),
                        range: 20...200,
                        step: 5
                    )
                }

                Section("Monthly budget") {
                    HStack {
                        Text("$")
                        TextField("Budget", value: Binding(
                            get: { store.settings.monthlyBudget },
                            set: { newValue in store.updateSettings { $0.monthlyBudget = max(0, newValue) } }
                        ), format: .number)
                        .keyboardType(.decimalPad)
                    }
                }

                Section("Kroger") {
                    if kroger.isConnected {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Connected")
                            Spacer()
                            if let loc = kroger.preferredLocation {
                                Text(loc.name)
                                    .font(.caption)
                                    .foregroundStyle(Theme.textSecondary)
                                    .lineLimit(1)
                            }
                        }
                        Button(role: .destructive) {
                            Task { await kroger.disconnect() }
                        } label: {
                            Text("Disconnect Kroger")
                        }
                    } else {
                        Button {
                            Task { await kroger.connect() }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "cart.badge.plus")
                                    .foregroundStyle(.white)
                                    .frame(width: 28, height: 28)
                                    .background(Color.blue)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Connect Kroger")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Theme.textPrimary)
                                    Text("Send shopping lists to Kroger.com")
                                        .font(.caption)
                                        .foregroundStyle(Theme.textSecondary)
                                }
                            }
                        }
                    }
                }

                Section("Health integrations") {
                    ForEach(store.settings.healthApps) { app in
                        Toggle(app.name, isOn: Binding(
                            get: { app.connected },
                            set: { _ in store.toggleHealthApp(app.name) }
                        ))
                    }
                    Text("Apple Health writes nutrition data when you log a scan. Garmin / Fitbit integration is coming soon.")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                }

                Section("History") {
                    NavigationLink("All scans (\(store.scannedItems.count))") {
                        ScanHistoryView()
                    }
                }

                Section("Account") {
                    if case .signedIn(let profile) = auth.state {
                        HStack {
                            Text("Signed in as")
                            Spacer()
                            Text(profile.email ?? profile.greetingName)
                                .foregroundStyle(Theme.textSecondary)
                                .lineLimit(1)
                        }
                        Button {
                            showingEditProfile = true
                        } label: {
                            HStack {
                                Text("Edit profile")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.footnote)
                                    .foregroundStyle(.tertiary)
                            }
                            .foregroundStyle(Theme.textPrimary)
                        }
                    }
                    Button {
                        Task { await auth.signOut() }
                    } label: {
                        Text("Sign out")
                    }
                    Button(role: .destructive) {
                        showingDeleteConfirm = true
                    } label: {
                        Text("Delete account")
                    }
                }

                Section("Help") {
                    Link(destination: feedbackMailto) {
                        Label("Send feedback", systemImage: "envelope")
                            .foregroundStyle(Theme.textPrimary)
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("2.0").foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            .navigationTitle("Profile")
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
            .sheet(isPresented: $showingEditProfile) {
                EditProfileSheet()
            }
            .alert("Delete account?", isPresented: $showingDeleteConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task {
                        deleting = true
                        _ = await auth.deleteAccount()
                        deleting = false
                    }
                }
            } message: {
                Text("This permanently deletes your account, profile, and any connected services (Kroger, Apple Health). This cannot be undone.")
            }
            .task { await kroger.bootstrap() }
        }
    }

    private var feedbackMailto: URL {
        let subject = "Scan to Cart — beta feedback".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let body = "App version: 2.0\nDevice: \(UIDevice.current.model) (iOS \(UIDevice.current.systemVersion))\n\nWhat's working / not working:\n\n"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "mailto:trevorm.goodwill@gmail.com?subject=\(subject)&body=\(body)")!
    }

    private func bindingFor(_ keyPath: WritableKeyPath<NutritionGoals, Double>) -> Binding<Double> {
        Binding(
            get: { store.settings.nutritionGoals[keyPath: keyPath] },
            set: { newValue in
                store.updateSettings { $0.nutritionGoals[keyPath: keyPath] = newValue }
            }
        )
    }

    private func nutritionStepper(
        label: String,
        binding: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double
    ) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text("\(Int(binding.wrappedValue))")
                .monospacedDigit()
                .foregroundStyle(Theme.textSecondary)
            Stepper("", value: binding, in: range, step: step)
                .labelsHidden()
        }
    }
}

private struct ScanHistoryView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        List {
            ForEach(store.scannedItems) { item in
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.product.name).font(.subheadline.weight(.medium))
                    HStack {
                        Text(item.scannedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                        Spacer()
                        Text(String(format: "$%.2f", item.product.price(at: item.store ?? store.settings.preferredStore)))
                            .font(.caption.monospacedDigit())
                    }
                }
            }
            .onDelete { indexSet in
                for index in indexSet {
                    store.removeItem(id: store.scannedItems[index].id)
                }
            }
        }
        .navigationTitle("History")
    }
}