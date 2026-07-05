import Foundation

enum AppConfig {
    #if DEBUG
    #if targetEnvironment(simulator)
    static let backendBaseURL = URL(string: "http://localhost:8080")!
    static let webSocketBaseURL = URL(string: "ws://localhost:8080")!
    #else
    static let backendBaseURL = URL(string: "https://zholdas-mobile.onrender.com")!
    static let webSocketBaseURL = URL(string: "wss://zholdas-mobile.onrender.com")!
    #endif
    #else
    static let backendBaseURL = URL(string: "https://zholdas-mobile.onrender.com")!
    static let webSocketBaseURL = URL(string: "wss://zholdas-mobile.onrender.com")!
    #endif

    static func backendAbsoluteURL(for path: String) -> String {
        if path.hasPrefix("http") {
            return path
        }
        return backendBaseURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))).absoluteString
    }
}
