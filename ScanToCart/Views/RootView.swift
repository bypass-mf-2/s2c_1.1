import SwiftUI

enum AppTab: Hashable {
    case home, scanner, nutrition, budget, lists, profile
}

struct RootView: View {
    @State private var store = AppStore()
    @State private var auth = AuthService.shared
    @State private var onboardingComplete: Bool = Storage.shared.onboardingComplete
    @State private var selectedTab: AppTab = .home

    var body: some View {
        Group {
            switch auth.state {
            case .unknown:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.background)
            case .signedOut:
                LoginScreen()
            case .signedIn:
                if onboardingComplete {
                    mainTabs
                } else {
                    OnboardingView {
                        Storage.shared.onboardingComplete = true
                        withAnimation { onboardingComplete = true }
                    }
                }
            }
        }
        .environment(store)
        .tint(Theme.accent)
    }

    private var mainTabs: some View {
        TabView(selection: $selectedTab) {
            HomeScreen(selectedTab: $selectedTab)
                .tabItem { Label("Home", systemImage: "house") }
                .tag(AppTab.home)

            ScannerScreen()
                .tabItem { Label("Scan", systemImage: "barcode.viewfinder") }
                .tag(AppTab.scanner)

            NutritionScreen()
                .tabItem { Label("Nutrition", systemImage: "chart.pie") }
                .tag(AppTab.nutrition)

            BudgetScreen()
                .tabItem { Label("Budget", systemImage: "dollarsign.circle") }
                .tag(AppTab.budget)

            ListsScreen()
                .tabItem { Label("Cart", systemImage: "cart") }
                .tag(AppTab.lists)

            ProfileScreen()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                .tag(AppTab.profile)
        }
    }
}
