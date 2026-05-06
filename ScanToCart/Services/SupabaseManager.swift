import Foundation
import Supabase

/// Singleton wrapper for the Supabase client. Returns nil when SUPABASE_URL
/// or SUPABASE_ANON_KEY is missing — calling code should treat absence as
/// "auth disabled, run in offline mode".
enum SupabaseManager {
    static let shared: SupabaseClient? = makeClient()

    private static func makeClient() -> SupabaseClient? {
        let urlString = Config.supabaseURL
        let key = Config.supabaseAnonKey
        guard !urlString.isEmpty, !key.isEmpty, let url = URL(string: urlString) else {
            print("[Supabase] No URL/anon key in Config — auth will be disabled")
            return nil
        }
        return SupabaseClient(supabaseURL: url, supabaseKey: key)
    }
}
