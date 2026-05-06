import Foundation

/// Reads runtime configuration injected via Config.xcconfig → Info.plist.
/// Mirrors the EXPO_PUBLIC_* env vars used by the React Native build, so
/// both apps can be configured against the same project credentials.
enum Config {
    static let supabaseURL = string(for: "SUPABASE_URL")
    static let supabaseAnonKey = string(for: "SUPABASE_ANON_KEY")
    static let usdaAPIKey = string(for: "USDA_API_KEY")
    static let garminProxyURL = string(for: "GARMIN_PROXY_URL")
    static let serpAPIKey = string(for: "SERPAPI_KEY")
    static let revenueCatAPIKey = string(for: "REVENUECAT_API_KEY")
    static let sentryDSN = string(for: "SENTRY_DSN")

    /// True when the key is set to a non-empty value in Config.xcconfig.
    static func has(_ key: String) -> Bool {
        !string(for: key).isEmpty
    }

    private static func string(for key: String) -> String {
        let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String ?? ""
        return raw.trimmingCharacters(in: .whitespaces)
    }
}