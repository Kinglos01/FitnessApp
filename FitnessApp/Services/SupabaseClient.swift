import Foundation
import Supabase

let supabase: SupabaseClient = {
    var authConfig = AuthClient.Configuration()
    // Opt into the new behavior so the local session is emitted as the initial session
    authConfig.emitLocalSessionAsInitialSession = true
    var clientConfig = SupabaseClient.Configuration()
    clientConfig.auth = authConfig
    clientConfig.auth.storage = AuthStateStorage.local

    return SupabaseClient(
        supabaseURL: URL(string: "https://cmkcxffaizmlfctzrmlb.supabase.co")!,
        supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNta2N4ZmZhaXptbGZjdHpybGxiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIxMTQwMTEsImV4cCI6MjA4NzY5MDAxMX0.B00cPs6aatcurjEiSzxjh-7uPXt5h0PUiJQxOeDn7Ds",
        configuration: clientConfig
    )
}()

