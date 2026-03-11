import Foundation
import Supabase

let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://cmkcxffaizmlfctzrmlb.supabase.co")!,
    supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNta2N4ZmZhaXptbGZjdHpybWxiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIxMTQwMTEsImV4cCI6MjA4NzY5MDAxMX0.B00cPs6aatcurjEiSzxjh-7uPXt5h0PUiJQxOeDn7Ds",
    options: .init(auth: .init(emitLocalSessionAsInitialSession: true))
)
