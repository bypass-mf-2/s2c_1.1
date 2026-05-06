import SwiftUI
import AuthenticationServices

struct LoginScreen: View {
    @State private var auth = AuthService.shared
    @State private var isProcessing = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "barcode.viewfinder")
                    .font(.system(size: 64))
                    .foregroundStyle(Theme.accent)
                Text("Scan to Cart")
                    .font(.largeTitle.weight(.bold))
                Text("Track nutrition & spending across your favorite stores")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()

            VStack(spacing: 12) {
                SignInWithAppleButton(.continue) { request in
                    auth.startSignInWithApple(request)
                } onCompletion: { result in
                    Task {
                        isProcessing = true
                        await auth.handleSignInWithApple(result)
                        isProcessing = false
                    }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Button {
                    Task {
                        isProcessing = true
                        await auth.signInWithGoogle()
                        isProcessing = false
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "globe")
                            .font(.title3)
                        Text("Continue with Google")
                            .font(.headline)
                    }
                    .foregroundStyle(Theme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Theme.border, lineWidth: 1)
                    )
                }
                .disabled(isProcessing)
            }
            .padding(.horizontal, 24)

            if isProcessing {
                ProgressView()
                    .padding(.top, 8)
            }

            if let error = auth.lastError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Text("By continuing you agree to our Terms and Privacy Policy.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }
}
