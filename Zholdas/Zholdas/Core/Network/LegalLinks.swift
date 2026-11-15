import Foundation

enum LegalLinks {
    static func normalizeLanguage(_ lang: String) -> String {
        switch lang.lowercased() {
        case "kk":
            return "kk"
        case "en":
            return "en"
        default:
            return "ru"
        }
    }

    static func privacyURL(lang: String, baseURL: URL = AppConfig.backendBaseURL) -> URL {
        let validLang = normalizeLanguage(lang)
        var components = URLComponents(url: baseURL.appendingPathComponent("privacy"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "lang", value: validLang)]
        return components?.url ?? baseURL.appendingPathComponent("privacy")
    }

    static func termsURL(lang: String, baseURL: URL = AppConfig.backendBaseURL) -> URL {
        let validLang = normalizeLanguage(lang)
        var components = URLComponents(url: baseURL.appendingPathComponent("terms"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "lang", value: validLang)]
        return components?.url ?? baseURL.appendingPathComponent("terms")
    }
}
