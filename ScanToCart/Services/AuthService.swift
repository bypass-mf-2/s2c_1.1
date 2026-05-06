import Foundation
import AuthenticationServices
import Supabase
import CryptoKit

/// Handles Sign in with Apple + Google OAuth (via Supabase) and exposes the
/// active user/profile to the rest of the app. Persists session in the
/// Supabase SDK's keychain-backed storage.
@MainActor
@Observable
final class AuthService: NSObject {
    static let shared = AuthService()

    enum State { case unknown, signedOut, signedIn(Profile) }

    private(set) var state: State = .unknown
    private(set) var lastError: String?

    private var currentNonce: String?
    private var nameFromApple: (first: String?, last: String?)?

    private var client: SupabaseClient? { SupabaseManager.shared }

    /// Hydrates session from keychain on launch and starts listening for
    /// auth state changes (sign-in/out from another device, etc.).
    func bootstrap() async {
        guard let client else {
            state = .signedOut
            return
        }
        do {
            let session = try await client.auth.session
            let profile = try await fetchOrCreateProfile(for: session.user)
            state = .signedIn(profile)
        } catch {
            state = .signedOut
        }
    }

    func signOut() async {
        guard let client else { return }
        try? await client.auth.signOut()
        state = .signedOut
    }

    /// Permanently deletes the user's account and all associated data.
    /// Required by Apple Guideline 5.1.1(v) for any app with sign-in.
    func deleteAccount() async -> Bool {
        guard let client else { return false }
        do {
            struct OK: Decodable { let success: Bool }
            let response: OK = try await client.functions.invoke(
                "delete-user",
                options: .init(method: .post)
            )
            if response.success {
                try? await client.auth.signOut()
                state = .signedOut
                return true
            }
            return false
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    // MARK: - Apple

    func startSignInWithApple(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
    }

    func handleSignInWithApple(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .failure(let error):
            // ASAuthorizationError code 1001 == user cancelled; not an error.
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                lastError = error.localizedDescription
            }
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let token = String(data: tokenData, encoding: .utf8),
                  let nonce = currentNonce
            else {
                lastError = "Couldn't read Apple credential"
                return
            }

            // Apple returns name only on FIRST sign-in. Capture immediately.
            if let givenName = credential.fullName?.givenName {
                nameFromApple = (givenName, credential.fullName?.familyName)
            }

            await completeSignIn(provider: .apple, idToken: token, nonce: nonce)
        }
    }

    // MARK: - Google (via Supabase OAuth + ASWebAuthenticationSession)

    func signInWithGoogle() async {
        guard let client else {
            lastError = "Supabase not configured"
            return
        }
        do {
            try await client.auth.signInWithOAuth(
                provider: .google,
                redirectTo: URL(string: "com.trevorgoodwill.scantocart://login-callback")
            ) { session in
                session.prefersEphemeralWebBrowserSession = false
            }
            // After the OAuth dance, refresh state.
            let session = try await client.auth.session
            let profile = try await fetchOrCreateProfile(for: session.user)
            state = .signedIn(profile)
        } catch {
            // ASWebAuthenticationSession user-cancelled comes through as a
            // specific error code we should swallow silently.
            let ns = error as NSError
            if ns.domain == "com.apple.AuthenticationServices.WebAuthenticationSession" {
                return
            }
            lastError = error.localizedDescription
        }
    }

    // MARK: - Profile

    func updateProfile(firstName: String?, fullName: String?) async {
        guard let client, case .signedIn(var profile) = state else { return }
        let updates: [String: AnyJSON] = [
            "first_name": .string(firstName ?? ""),
            "full_name": .string(fullName ?? "")
        ]
        do {
            try await client.from("profiles")
                .update(updates)
                .eq("id", value: profile.id.uuidString)
                .execute()
            profile.firstName = firstName
            profile.fullName = fullName
            state = .signedIn(profile)
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Internal

    private func completeSignIn(provider: OpenIDConnectCredentials.Provider, idToken: String, nonce: String) async {
        guard let client else { return }
        do {
            let response = try await client.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(provider: provider, idToken: idToken, nonce: nonce)
            )
            var profile = try await fetchOrCreateProfile(for: response.user)
            // First-time Apple sign-in is the only chance to capture the
            // user's name. Persist it now.
            if let apple = nameFromApple {
                let composedFull = [apple.first, apple.last].compactMap { $0 }.joined(separator: " ")
                if profile.firstName?.isEmpty != false {
                    profile.firstName = apple.first
                }
                if profile.fullName?.isEmpty != false, !composedFull.isEmpty {
                    profile.fullName = composedFull
                }
                await updateProfile(firstName: profile.firstName, fullName: profile.fullName)
                nameFromApple = nil
            }
            state = .signedIn(profile)
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Fetches the row from `profiles` matching the auth user's id, creating
    /// one if it doesn't exist yet. Newly-created rows are seeded with the
    /// user metadata (email + any name from the OAuth provider).
    private func fetchOrCreateProfile(for user: User) async throws -> Profile {
        guard let client else { throw NSError(domain: "AuthService", code: -1) }

        let existing: Profile? = try? await client.from("profiles")
            .select()
            .eq("id", value: user.id.uuidString)
            .single()
            .execute()
            .value

        if let existing { return existing }

        let metadata = user.userMetadata
        let fullNameFromMeta = metadata["full_name"]?.stringValue ?? metadata["name"]?.stringValue
        let firstFromMeta = metadata["given_name"]?.stringValue
            ?? fullNameFromMeta?.split(separator: " ").first.map(String.init)

        let new = Profile(
            id: user.id,
            email: user.email,
            fullName: fullNameFromMeta,
            firstName: firstFromMeta,
            avatarURL: metadata["avatar_url"]?.stringValue,
            createdAt: Date(),
            updatedAt: Date()
        )

        let inserted: Profile = try await client.from("profiles")
            .insert(new)
            .select()
            .single()
            .execute()
            .value

        return inserted
    }

    // MARK: - Apple nonce helpers

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var random: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if status != errSecSuccess { continue }
            if random < charset.count {
                result.append(charset[Int(random)])
                remaining -= 1
            }
        }
        return result
    }

    private func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
