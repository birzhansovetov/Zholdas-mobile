import Foundation

enum AppConfig {
    #if DEBUG
    #if targetEnvironment(simulator)
    static let backendBaseURL = URL(string: "http://localhost:8080")!
    static let webSocketBaseURL = URL(string: "ws://localhost:8080")!
    #else
    static let backendBaseURL = URL(string: "https://api.zholdas.app")!
    static let webSocketBaseURL = URL(string: "wss://api.zholdas.app")!
    #endif
    #else
    static let backendBaseURL = URL(string: "https://api.zholdas.app")!
    static let webSocketBaseURL = URL(string: "wss://api.zholdas.app")!
    #endif

    static func backendAbsoluteURL(for path: String) -> String {
        if path.hasPrefix("http") {
            return path
        }
        return backendBaseURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))).absoluteString
    }
}
