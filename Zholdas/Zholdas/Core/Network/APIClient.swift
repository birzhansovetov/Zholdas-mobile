import Foundation

enum APIError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError(Error)
    case serverError(statusCode: Int, message: String)
    case unauthorized
    case missingSupabaseAnonKey
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Неверный URL адрес"
        case .noData:
            return "Нет данных от сервера"
        case .decodingError(let error):
            return "Ошибка декодирования данных: \(error.localizedDescription)"
        case .serverError(_, let message):
            return message
        case .unauthorized:
            return "Не авторизован. Войдите заново"
        case .missingSupabaseAnonKey:
            return "Не настроен Supabase anon key"
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}

actor APIClient {
    nonisolated static let shared = APIClient()
    
    private let baseURL = AppConfig.backendBaseURL
    
    // Переменная для объединения параллельных запросов на рефреш
    private var refreshTask: Task<String, Error>?
    
    private init() {}
    
    // MARK: - Generic request method

    func signInWithPassword(email: String, password: String) async throws -> TokenResponse {
        let payload = SignInRequest(email: email, password: password)
        let body = try JSONEncoder().encode(payload)
        return try await supabaseAuthRequest(
            "/auth/v1/token?grant_type=password",
            method: "POST",
            body: body
        )
    }

    func signUp(email: String, password: String, username: String, fullName: String) async throws -> TokenResponse? {
        struct SupabaseSignUpRequest: Codable {
            let email: String
            let password: String
            let data: [String: String]
        }

        struct SupabaseSignUpResponse: Codable {
            let accessToken: String?
            let refreshToken: String?

            enum CodingKeys: String, CodingKey {
                case accessToken = "access_token"
                case refreshToken = "refresh_token"
            }
        }

        let payload = SupabaseSignUpRequest(
            email: email,
            password: password,
            data: [
                "username": username,
                "full_name": fullName
            ]
        )
        let response: SupabaseSignUpResponse = try await supabaseAuthRequest(
            "/auth/v1/signup",
            method: "POST",
            body: try JSONEncoder().encode(payload)
        )

        guard let accessToken = response.accessToken, let refreshToken = response.refreshToken else {
            return nil
        }
        return TokenResponse(accessToken: accessToken, refreshToken: refreshToken)
    }

    func sendPasswordResetEmail(email: String) async throws {
        struct RecoverRequest: Codable {
            let email: String
        }

        var components = URLComponents(url: SupabaseConfig.projectURL.appendingPathComponent("auth/v1/recover"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "redirect_to", value: "zholdas://reset-password")
        ]

        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        try await supabaseAuthVoidRequest(
            url: url,
            method: "POST",
            body: try JSONEncoder().encode(RecoverRequest(email: email))
        )
    }

    func resendEmailConfirmation(email: String) async throws {
        struct ResendRequest: Codable {
            let type: String
            let email: String
        }

        try await supabaseAuthVoidRequest(
            "/auth/v1/resend",
            method: "POST",
            body: try JSONEncoder().encode(ResendRequest(type: "signup", email: email))
        )
    }

    func updateSupabasePassword(accessToken: String, newPassword: String) async throws {
        struct UpdatePasswordRequest: Codable {
            let password: String
        }

        try await supabaseAuthVoidRequest(
            "/auth/v1/user",
            method: "PUT",
            body: try JSONEncoder().encode(UpdatePasswordRequest(password: newPassword)),
            bearerToken: accessToken
        )
    }
    
    func request<T: Decodable>(_ path: String, method: String = "GET", body: Data? = nil, requiresAuth: Bool = true) async throws -> T {
        let request = try buildRequest(path: path, method: method, body: body, requiresAuth: requiresAuth)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.noData
            }
            
            if httpResponse.statusCode == 401 && requiresAuth {
                // Если получили 401 — пытаемся обновить токен и повторить запрос
                let newAccessToken = try await refreshAccessToken()
                var updatedRequest = request
                updatedRequest.setValue("Bearer \(newAccessToken)", forHTTPHeaderField: "Authorization")
                
                let (retryData, retryResponse) = try await URLSession.shared.data(for: updatedRequest)
                guard let retryHTTPResponse = retryResponse as? HTTPURLResponse else {
                    throw APIError.noData
                }
                
                try checkResponse(retryHTTPResponse, data: retryData)
                return try decode(retryData)
            }
            
            try checkResponse(httpResponse, data: data)
            return try decode(data)
            
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.unknown(error)
        }
    }
    
    // MARK: - Multipart Form Upload Helper
    
    func upload(fileData: Data, fileName: String, mimeType: String, to path: String) async throws -> String {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw APIError.invalidURL
        }
        
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        if let token = await TokenStorage.shared.getAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        var body = Data()
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.noData
            }
            
            if httpResponse.statusCode == 401 {
                // Try refresh
                let newAccessToken = try await refreshAccessToken()
                var updatedRequest = request
                updatedRequest.setValue("Bearer \(newAccessToken)", forHTTPHeaderField: "Authorization")
                
                let (retryData, retryResponse) = try await URLSession.shared.data(for: updatedRequest)
                guard let retryHTTPResponse = retryResponse as? HTTPURLResponse else {
                    throw APIError.noData
                }
                
                try checkResponse(retryHTTPResponse, data: retryData)
                struct UploadResponse: Codable {
                    let url: String
                }
                let uploadResult: UploadResponse = try decode(retryData)
                return uploadResult.url
            }
            
            try checkResponse(httpResponse, data: data)
            struct UploadResponse: Codable {
                let url: String
            }
            let uploadResult: UploadResponse = try decode(data)
            return uploadResult.url
            
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.unknown(error)
        }
    }
    
    // MARK: - Private Helpers
    
    private func buildRequest(path: String, method: String, body: Data?, requiresAuth: Bool) throws -> URLRequest {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        
        if requiresAuth {
            if let token = TokenStorage.shared.getAccessToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
        }
        
        return request
    }
    
    private func checkResponse(_ response: HTTPURLResponse, data: Data) throws {
        if (200...299).contains(response.statusCode) {
            return
        }
        
        if let errorJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let message = errorJSON["error_description"] as? String
                ?? errorJSON["msg"] as? String
                ?? errorJSON["message"] as? String
                ?? errorJSON["error"] as? String

            if let message {
                throw APIError.serverError(statusCode: response.statusCode, message: authErrorMessage(message))
            }
        }
        
        throw APIError.serverError(statusCode: response.statusCode, message: "Код ошибки сервера: \(response.statusCode)")
    }

    private func authErrorMessage(_ message: String) -> String {
        switch message {
        case "Invalid login credentials":
            return "Неверная почта или пароль"
        case "Email not confirmed":
            return "Подтвердите email перед входом"
        case "Signup is disabled":
            return "Регистрация отключена в Supabase"
        default:
            return message
        }
    }
    
    private func decode<T: Decodable>(_ data: Data) throws -> T {
        let decoder = JSONDecoder()
        
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateStr = try container.decode(String.self)
            
            // Настройка парсинга дат из Go RFC3339
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            if let date = formatter.date(from: dateStr) {
                return date
            }
            
            // Запасной вариант парсинга для стандартного ISO8601
            let fallbackFormatter = ISO8601DateFormatter()
            if let date = fallbackFormatter.date(from: dateStr) {
                return date
            }
            
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Неверный формат даты: \(dateStr)")
        }
        
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }
    
    // MARK: - Token Refreshing logic (Потокобезопасный через Actor и Task)
    
    private func refreshAccessToken() async throws -> String {
        // Если рефреш уже запущен другим параллельным запросом, ждем его завершения
        if let existingTask = refreshTask {
            return try await existingTask.value
        }
        
        let task = Task<String, Error> {
            defer {
                // Сбрасываем таску после завершения
                self.resetRefreshTask()
            }
            
            guard let refreshToken = TokenStorage.shared.getRefreshToken() else {
                NotificationCenter.default.post(name: .unauthorizedNotification, object: nil)
                throw APIError.unauthorized
            }
            
            let refreshReq = RefreshRequest(refreshToken: refreshToken)
            let tokenResponse: TokenResponse = try await supabaseAuthRequest(
                "/auth/v1/token?grant_type=refresh_token",
                method: "POST",
                body: try JSONEncoder().encode(refreshReq)
            )
            
            // Сохраняем новые токены в Keychain
            _ = TokenStorage.shared.saveTokens(
                accessToken: tokenResponse.accessToken,
                refreshToken: tokenResponse.refreshToken
            )
            
            return tokenResponse.accessToken
        }
        
        self.refreshTask = task
        return try await task.value
    }
    
    private func resetRefreshTask() {
        self.refreshTask = nil
    }

    private func supabaseAuthRequest<T: Decodable>(_ path: String, method: String, body: Data) async throws -> T {
        guard SupabaseConfig.isConfigured else {
            throw APIError.missingSupabaseAnonKey
        }

        guard let url = URL(string: path, relativeTo: SupabaseConfig.projectURL) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.noData
        }

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            TokenStorage.shared.clear()
            NotificationCenter.default.post(name: .unauthorizedNotification, object: nil)
            throw APIError.unauthorized
        }

        try checkResponse(httpResponse, data: data)
        return try decode(data)
    }

    private func supabaseAuthVoidRequest(_ path: String, method: String, body: Data, bearerToken: String? = nil) async throws {
        guard SupabaseConfig.isConfigured else {
            throw APIError.missingSupabaseAnonKey
        }

        guard let url = URL(string: path, relativeTo: SupabaseConfig.projectURL) else {
            throw APIError.invalidURL
        }

        try await supabaseAuthVoidRequest(url: url, method: method, body: body, bearerToken: bearerToken)
    }

    private func supabaseAuthVoidRequest(url: URL, method: String, body: Data, bearerToken: String? = nil) async throws {
        guard SupabaseConfig.isConfigured else {
            throw APIError.missingSupabaseAnonKey
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(bearerToken ?? SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.noData
        }

        try checkResponse(httpResponse, data: data)
    }
}

// MARK: - Notification Extension for Auth Events

extension NSNotification.Name {
    static let unauthorizedNotification = NSNotification.Name("unauthorized_notification")
}
