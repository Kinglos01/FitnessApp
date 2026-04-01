import Foundation

/// Configuration for Supabase project access.
///
/// Replace the placeholder values with your project's REST URL and anon key.
/// - `url`: The base URL for your Supabase project, e.g. "https://your-project-id.supabase.co"
/// - `anonKey`: The public anon API key from your Supabase project's API settings.
struct SupabaseConfig {
    /// Base URL for your Supabase project, without trailing slash.
    static let url: String = "https://YOUR-PROJECT-ID.supabase.co"

    /// Public anon API key for your Supabase project.
    static let anonKey: String = "YOUR-ANON-KEY"
}
