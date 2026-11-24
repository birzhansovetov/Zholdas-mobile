import Foundation

enum EventDeepLink {
    private static let webHosts: Set<String> = ["zholdas.app", "www.zholdas.app"]

    nonisolated static func webURL(for id: Int) -> URL {
        URL(string: "https://www.zholdas.app/e/\(id)")!
    }

    nonisolated static func webURL(for id: Int32) -> URL {
        webURL(for: Int(id))
    }

    nonisolated static func webURL(for id: Int64) -> URL {
        webURL(for: Int(id))
    }

    nonisolated static func eventID(from url: URL, backendBaseURL: URL = AppConfig.backendBaseURL) -> Int? {
        guard let scheme = url.scheme?.lowercased() else { return nil }
        let pathSegments = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
        
        if scheme == "zholdas" {
            let host = url.host?.lowercased()
            
            if host == "event" || host == "events" {
                if pathSegments.count == 1, let id = Int(pathSegments[0]), id > 0 {
                    return id
                }
            } else if host == nil || host?.isEmpty == true {
                if pathSegments.count == 2,
                   (pathSegments[0].lowercased() == "event" || pathSegments[0].lowercased() == "events"),
                   let id = Int(pathSegments[1]), id > 0 {
                    return id
                }
            }
            return nil
        }
        
        guard scheme == "https" || scheme == "http" else {
            return nil
        }

        guard let urlHost = url.host?.lowercased() else {
            return nil
        }

        if webHosts.contains(urlHost) {
            if pathSegments.count == 2,
               (pathSegments[0].lowercased() == "e" || pathSegments[0].lowercased() == "events" || pathSegments[0].lowercased() == "event"),
               let id = Int(pathSegments[1]), id > 0 {
                return id
            }
            return nil
        }

        if let backendHost = backendBaseURL.host?.lowercased(), urlHost == backendHost {
            if pathSegments.count == 2,
               (pathSegments[0].lowercased() == "events" || pathSegments[0].lowercased() == "event"),
               let id = Int(pathSegments[1]), id > 0 {
                return id
            }
            return nil
        }
        
        return nil
    }
}
