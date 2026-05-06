import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var page: Int = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "barcode.viewfinder",
            title: "Scan any barcode",
            subtitle: "Pull nutrition, prices, and ingredients in seconds."
        ),
        OnboardingPage(
            icon: "chart.pie.fill",
            title: "Track every macro",
            subtitle: "Daily calorie and protein goals with progress rings."
        ),
        OnboardingPage(
            icon: "dollarsign.circle.fill",
            title: "Stay on budget",
            subtitle: "Monthly grocery limits with category breakdowns."
        )
    ]

    var body: some View {
        VStack {
            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { idx in
                    pageView(pages[idx]).tag(idx)
                }
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button {
                if page < pages.count - 1 {
                    withAnimation { page += 1 }
                } else {
                    onFinish()
                }
            } label: {
                Text(page == pages.count - 1 ? "Get started" : "Next")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .padding()

            Button("Skip") { onFinish() }
                .font(.callout)
                .foregroundStyle(Theme.textSecondary)
                .padding(.bottom, 24)
        }
    }

    private func pageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: 24) {
            Image(systemName: page.icon)
                .font(.system(size: 96))
                .foregroundStyle(Theme.accent)
                .padding(.top, 80)

            VStack(spacing: 12) {
                Text(page.title)
                    .font(.title.weight(.semibold))
                Text(page.subtitle)
                    .font(.body)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }
}

private struct OnboardingPage {
    let icon: String
    let title: String
    let subtitle: String
}