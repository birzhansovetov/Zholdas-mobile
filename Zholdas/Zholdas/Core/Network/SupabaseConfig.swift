import Foundation

enum SupabaseConfig {
    static let projectURL = URL(string: "https://wqjaolhmpxanjvadxngn.supabase.co")!
    private static let placeholderAnonKey = "PASTE_SUPABASE_ANON_KEY_HERE"

    // Replace this with Supabase Dashboard -> Project Settings -> API -> anon public.
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndxamFvbGhtcHhhbmp2YWR4bmduIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA3Nzc5NDUsImV4cCI6MjA5NjM1Mzk0NX0.-7z5E9OTGsmBVXnK-veSovd-Vuza_HEglhTdNZ69alM"

    static var isConfigured: Bool {
        !anonKey.isEmpty && anonKey != placeholderAnonKey
    }
}
