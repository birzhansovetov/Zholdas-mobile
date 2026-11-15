import Foundation

enum EventDeepLink {
    nonisolated static func eventID(from url: URL, backendBaseURL: URL = AppConfig.backendBaseURL) -> Int? {
        let scheme = url.scheme?.lowercased()
        
        if scheme == "zholdas" {
            let host = url.host?.lowercased()
            let pathSegments = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
            
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
        
        guard let urlHost = url.host?.lowercased(),
              let backendHost = backendBaseURL.host?.lowercased(),
              urlHost == backendHost else {
            return nil
        }
        
        let pathSegments = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
        if pathSegments.count == 2,
           (pathSegments[0].lowercased() == "events" || pathSegments[0].lowercased() == "event"),
           let id = Int(pathSegments[1]), id > 0 {
            return id
        }
        
        return nil
    }
}
