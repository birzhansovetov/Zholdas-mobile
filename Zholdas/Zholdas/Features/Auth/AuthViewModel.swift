import Foundation
import Combine
import UIKit
import UserNotifications

@MainActor
class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentUserProfile: UserProfile?
    @Published var unreadNotificationsCount: Int = 0
    @Published var infoMessage: String?
    @Published var isShowingPasswordReset = false
    @Published var passwordResetMessage: String?
    @Published var passwordResetAccessToken: String?
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        checkAuth()
        setupNotificationObserver()
    }
    
    func checkAuth() {
        // Если в Keychain есть оба токена — считаем пользователя авторизованным
        if TokenStorage.shared.getAccessToken() != nil && TokenStorage.shared.getRefreshToken() != nil {
            self.isAuthenticated = true
            Task {
                await fetchUserProfile()
            }
        } else {
            self.isAuthenticated = false
        }
    }
    
    func signIn(email: String, password: String) async {
        self.isLoading = true
        self.errorMessage = nil
        self.infoMessage = nil
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        do {
            let response = try await APIClient.shared.signInWithPassword(email: normalizedEmail, password: password)
            
            // Сохраняем токены
            let saved = TokenStorage.shared.saveTokens(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken
            )
            
            if saved {
                self.isAuthenticated = true
                await fetchUserProfile()
            } else {
                self.errorMessage = "Не удалось сохранить токены безопасности"
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
        
        self.isLoading = false
    }
    
    func signUp(
        email: String,
        password: String,
        username: String,
        fullName: String,
        avatarURL: String? = nil,
        bio: String? = nil,
        city: String? = nil,
        gender: String? = nil,
        birthYear: Int? = nil
    ) async {
        self.isLoading = true
        self.errorMessage = nil
        self.infoMessage = nil
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        do {
            if let response = try await APIClient.shared.signUp(email: normalizedEmail, password: password, username: username, fullName: fullName) {
                let saved = TokenStorage.shared.saveTokens(
                    accessToken: response.accessToken,
                    refreshToken: response.refreshToken
                )
                if saved {
                    self.isAuthenticated = true
                } else {
                    self.errorMessage = "Не удалось сохранить токены безопасности"
                    self.isLoading = false
                    return
                }
            } else {
                self.infoMessage = "Аккаунт создан. Подтвердите email через письмо, затем войдите."
                self.isLoading = false
                return
            }
            
            // Если указаны дополнительные параметры, обновляем профиль
            if avatarURL != nil || bio != nil || city != nil || gender != nil || birthYear != nil {
                struct UpdateProfileBody: Codable {
                    let fullName: String
                    let bio: String
                    let city: String
                    let avatarURL: String
                    let gender: String?
                    let birthYear: Int?
                    
                    enum CodingKeys: String, CodingKey {
                        case fullName = "full_name"
                        case bio
                        case city
                        case avatarURL = "avatar_url"
                        case gender
                        case birthYear = "birth_year"
                    }
                }
                let updateBody = UpdateProfileBody(
                    fullName: fullName,
                    bio: bio ?? "",
                    city: city ?? "Алматы",
                    avatarURL: avatarURL ?? "",
                    gender: gender,
                    birthYear: birthYear
                )
                let updateData = try JSONEncoder().encode(updateBody)
                let _: [String: String] = try await APIClient.shared.request(
                    "/auth/profile",
                    method: "PUT",
                    body: updateData,
                    requiresAuth: true
                )
                await fetchUserProfile()
            }
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
        }
    }
    
    func signOut() {
        self.isLoading = true
        
        // Посылаем запрос логаута в фоне на сервер
        Task {
            do {
                let _: [String: String] = try await APIClient.shared.request(
                    "/auth/logout",
                    method: "POST",
                    requiresAuth: true
                )
            } catch {
                print("Ошибка логаута на сервере: \(error.localizedDescription)")
            }
            
            // В любом случае очищаем Keychain локально
            TokenStorage.shared.clear()
            
            await MainActor.run {
                self.isAuthenticated = false
                self.currentUserProfile = nil
                self.isLoading = false
            }
        }
    }

    func sendPasswordResetEmail(email: String) async {
        self.isLoading = true
        self.errorMessage = nil
        self.passwordResetMessage = nil
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        do {
            try await APIClient.shared.sendPasswordResetEmail(email: normalizedEmail)
            self.passwordResetMessage = "Письмо для сброса пароля отправлено. Проверьте почту."
        } catch {
            self.errorMessage = error.localizedDescription
        }

        self.isLoading = false
    }

    func resendEmailConfirmation(email: String) async {
        self.isLoading = true
        self.errorMessage = nil
        self.infoMessage = nil
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        do {
            try await APIClient.shared.resendEmailConfirmation(email: normalizedEmail)
            self.infoMessage = "Письмо подтверждения отправлено еще раз. Проверьте почту."
        } catch {
            self.errorMessage = error.localizedDescription
        }

        self.isLoading = false
    }

    func handlePasswordResetURL(_ url: URL) {
        guard isPasswordResetURL(url) else { return }
        let params = url.fragmentParameters.merging(url.queryParameters) { fragmentValue, _ in fragmentValue }

        if let errorDescription = params["error_description"] ?? params["error"] {
            self.errorMessage = errorDescription.removingPercentEncoding ?? errorDescription
            return
        }

        guard params["type"] == "recovery", let accessToken = params["access_token"] else {
            self.errorMessage = "Неверная или устаревшая ссылка для сброса пароля"
            return
        }

        self.passwordResetAccessToken = accessToken
        if let refreshToken = params["refresh_token"] {
            _ = TokenStorage.shared.saveTokens(accessToken: accessToken, refreshToken: refreshToken)
        }
        self.isShowingPasswordReset = true
    }

    private func isPasswordResetURL(_ url: URL) -> Bool {
        if url.scheme == "zholdas" {
            return url.host == "reset-password" || url.path.contains("reset-password")
        }

        if url.scheme == "https", ["zholdas.app", "www.zholdas.app"].contains(url.host ?? "") {
            return url.path == "/reset-password"
        }

        return false
    }

    func resetPassword(newPassword: String) async -> Bool {
        guard let accessToken = passwordResetAccessToken ?? TokenStorage.shared.getAccessToken() else {
            self.errorMessage = "Ссылка для сброса пароля недействительна"
            return false
        }

        self.isLoading = true
        self.errorMessage = nil

        do {
            try await APIClient.shared.updateSupabasePassword(accessToken: accessToken, newPassword: newPassword)
            self.passwordResetMessage = "Пароль обновлен. Теперь можно войти с новым паролем."
            self.passwordResetAccessToken = nil
            self.isShowingPasswordReset = false
            TokenStorage.shared.clear()
            self.isAuthenticated = false
            self.currentUserProfile = nil
            self.isLoading = false
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
            return false
        }
    }
    
    private func setupNotificationObserver() {
        // Подписываемся на уведомление об отзыве авторизации из сетевого клиента
        NotificationCenter.default.publisher(for: .unauthorizedNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.isAuthenticated = false
                self?.currentUserProfile = nil
                self?.errorMessage = "Сессия истекла. Войдите заново"
            }
            .store(in: &cancellables)
    }
    
    func fetchUserProfile() async {
        self.isLoading = true
        self.errorMessage = nil
        
        do {
            let profile: UserProfile = try await APIClient.shared.request(
                "/auth/me",
                method: "GET",
                requiresAuth: true
            )
            self.currentUserProfile = profile
            
            // Also fetch notifications count in background
            await fetchNotificationsCount()
            
            // Trigger device token registration
            triggerDeviceTokenRegistration()
        } catch {
            self.errorMessage = "Не удалось загрузить профиль: \(error.localizedDescription)"
            TokenStorage.shared.clear()
            self.isAuthenticated = false
            self.currentUserProfile = nil
        }
        
        self.isLoading = false
    }
    
    func fetchUserProfile(by id: String) async -> User? {
        do {
            let profile: User = try await APIClient.shared.request(
                "/users/\(id)",
                method: "GET",
                requiresAuth: true
            )
            return profile
        } catch {
            print("Failed to fetch user profile \(id): \(error)")
            return nil
        }
    }
    
    func fetchNotificationsCount() async {
        do {
            let list: [NotificationItem] = try await APIClient.shared.request(
                "/notifications",
                method: "GET",
                requiresAuth: true
            )
            self.unreadNotificationsCount = list.filter { !$0.isRead }.count
        } catch {
            print("Failed to fetch notification count: \(error)")
        }
    }
    
    func updateUserProfile(
        fullName: String,
        bio: String,
        city: String,
        avatarURL: String,
        gender: String? = nil,
        birthYear: Int? = nil
    ) async -> Bool {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        struct UpdateProfileRequest: Codable {
            let fullName: String
            let bio: String
            let city: String
            let avatarURL: String
            let gender: String?
            let birthYear: Int?
            
            enum CodingKeys: String, CodingKey {
                case fullName = "full_name"
                case bio
                case city
                case avatarURL = "avatar_url"
                case gender
                case birthYear = "birth_year"
            }
        }
        
        let req = UpdateProfileRequest(
            fullName: fullName,
            bio: bio,
            city: city,
            avatarURL: avatarURL,
            gender: gender,
            birthYear: birthYear
        )
        
        do {
            let reqBody = try JSONEncoder().encode(req)
            let _: [String: String] = try await APIClient.shared.request(
                "/auth/profile",
                method: "PUT",
                body: reqBody,
                requiresAuth: true
            )
            
            // Reload user profile locally
            await fetchUserProfile()
            return true
        } catch {
            await MainActor.run {
                self.errorMessage = "Не удалось обновить профиль: \(error.localizedDescription)"
            }
            return false
        }
    }
    
    // MARK: - Friends API
    
    func sendFriendRequest(to userID: String) async -> Bool {
        do {
            let _: [String: String] = try await APIClient.shared.request(
                "/friends/request/\(userID)",
                method: "POST",
                requiresAuth: true
            )
            return true
        } catch {
            print("Failed to send friend request: \(error)")
            return false
        }
    }
    
    func acceptFriendRequest(from userID: String) async -> Bool {
        do {
            let _: [String: String] = try await APIClient.shared.request(
                "/friends/accept/\(userID)",
                method: "POST",
                requiresAuth: true
            )
            return true
        } catch {
            print("Failed to accept friend request: \(error)")
            return false
        }
    }
    
    func rejectFriendRequest(from userID: String) async -> Bool {
        do {
            let _: [String: String] = try await APIClient.shared.request(
                "/friends/reject/\(userID)",
                method: "POST",
                requiresAuth: true
            )
            return true
        } catch {
            print("Failed to reject friend request: \(error)")
            return false
        }
    }
    
    func fetchFriends() async -> [User] {
        do {
            let list: [User] = try await APIClient.shared.request(
                "/friends",
                method: "GET",
                requiresAuth: true
            )
            return list
        } catch {
            print("Failed to fetch friends: \(error)")
            return []
        }
    }
    
    func fetchFriendRequests() async -> [User] {
        do {
            let list: [User] = try await APIClient.shared.request(
                "/friends/requests",
                method: "GET",
                requiresAuth: true
            )
            return list
        } catch {
            print("Failed to fetch friend requests: \(error)")
            return []
        }
    }
    
    func getFriendshipStatus(with userID: String) async -> String {
        struct StatusResponse: Codable {
            let status: String
        }
        do {
            let res: StatusResponse = try await APIClient.shared.request(
                "/friends/status/\(userID)",
                method: "GET",
                requiresAuth: true
            )
            return res.status
        } catch {
            print("Failed to get friendship status: \(error)")
            return "none"
        }
    }
    
    // MARK: - Reviews & Ratings API
    
    func rateParticipant(eventID: Int32, rateeID: String, rating: Int, comment: String) async -> Bool {
        struct RateRequest: Codable {
            let rateeID: String
            let rating: Int
            let comment: String
            
            enum CodingKeys: String, CodingKey {
                case rateeID = "ratee_id"
                case rating
                case comment
            }
        }
        
        let req = RateRequest(rateeID: rateeID, rating: rating, comment: comment)
        do {
            let reqBody = try JSONEncoder().encode(req)
            let _: [String: String] = try await APIClient.shared.request(
                "/events/\(eventID)/rate",
                method: "POST",
                body: reqBody,
                requiresAuth: true
            )
            return true
        } catch {
            print("Failed to rate participant: \(error)")
            return false
        }
    }
    
    func fetchUserReviews(userID: String) async -> [UserReview] {
        do {
            let list: [UserReview] = try await APIClient.shared.request(
                "/users/\(userID)/reviews",
                method: "GET",
                requiresAuth: true
            )
            return list
        } catch {
            print("Failed to fetch user reviews: \(error)")
            return []
        }
    }
    
    // MARK: - Reports API
    
    func sendReport(reportedUserID: String?, eventID: Int32?, messageID: Int32?, reason: String, description: String) async -> Bool {
        struct CreateReportRequest: Codable {
            let reportedUserID: String?
            let eventID: Int32?
            let messageID: Int32?
            let reason: String
            let description: String
            
            enum CodingKeys: String, CodingKey {
                case reportedUserID = "reported_user_id"
                case eventID = "event_id"
                case messageID = "message_id"
                case reason
                case description
            }
        }
        
        let req = CreateReportRequest(
            reportedUserID: reportedUserID,
            eventID: eventID,
            messageID: messageID,
            reason: reason,
            description: description
        )
        
        do {
            let reqBody = try JSONEncoder().encode(req)
            let _: [String: String] = try await APIClient.shared.request(
                "/reports",
                method: "POST",
                body: reqBody,
                requiresAuth: true
            )
            return true
        } catch {
            print("Failed to send report: \(error)")
            return false
        }
    }
    
    // MARK: - Moderation & Blocks API
    
    func fetchReports() async -> [Report] {
        do {
            let list: [Report] = try await APIClient.shared.request(
                "/moderation/reports",
                method: "GET",
                requiresAuth: true
            )
            return list
        } catch {
            print("Failed to fetch reports: \(error)")
            return []
        }
    }
    
    func banUser(userID: String, reason: String) async -> Bool {
        struct BanRequest: Codable {
            let reason: String
        }
        let req = BanRequest(reason: reason)
        do {
            let reqBody = try JSONEncoder().encode(req)
            let _: [String: String] = try await APIClient.shared.request(
                "/moderation/users/\(userID)/ban",
                method: "POST",
                body: reqBody,
                requiresAuth: true
            )
            return true
        } catch {
            print("Failed to ban user: \(error)")
            return false
        }
    }
    
    func unbanUser(userID: String) async -> Bool {
        do {
            let _: [String: String] = try await APIClient.shared.request(
                "/moderation/users/\(userID)/unban",
                method: "POST",
                requiresAuth: true
            )
            return true
        } catch {
            print("Failed to unban user: \(error)")
            return false
        }
    }
    
    func closeReport(reportID: Int32) async -> Bool {
        do {
            let _: [String: String] = try await APIClient.shared.request(
                "/moderation/reports/\(reportID)/close",
                method: "POST",
                requiresAuth: true
            )
            return true
        } catch {
            print("Failed to close report: \(error)")
            return false
        }
    }
    
    func blockUser(userID: String) async -> Bool {
        do {
            let _: [String: String] = try await APIClient.shared.request(
                "/users/\(userID)/block",
                method: "POST",
                requiresAuth: true
            )
            return true
        } catch {
            print("Failed to block user: \(error)")
            return false
        }
    }
    
    func unblockUser(userID: String) async -> Bool {
        do {
            let _: [String: String] = try await APIClient.shared.request(
                "/users/\(userID)/unblock",
                method: "POST",
                requiresAuth: true
            )
            return true
        } catch {
            print("Failed to unblock user: \(error)")
            return false
        }
    }
    
    // MARK: - Image Uploading
    
    func uploadImage(data: Data, fileName: String) async -> String? {
        do {
            let relativePath = try await APIClient.shared.upload(
                fileData: data,
                fileName: fileName,
                mimeType: "image/jpeg",
                to: "/upload"
            )
            return relativePath
        } catch {
            print("Failed to upload image: \(error)")
            return nil
        }
    }
    
    func registerDeviceToken(_ token: String) async {
        struct DeviceTokenPayload: Codable {
            let deviceToken: String
            let platform: String
            
            enum CodingKeys: String, CodingKey {
                case deviceToken = "device_token"
                case platform
            }
        }
        
        let payload = DeviceTokenPayload(deviceToken: token, platform: "ios")
        do {
            let body = try JSONEncoder().encode(payload)
            let _: [String: String] = try await APIClient.shared.request(
                "/auth/device-token",
                method: "POST",
                body: body,
                requiresAuth: true
            )
            print("AuthViewModel: Push device token registered successfully: \(token)")
        } catch {
            print("AuthViewModel Error registering device token: \(error.localizedDescription)")
        }
    }
    
    func triggerDeviceTokenRegistration() {
        Task {
            if let savedToken = UserDefaults.standard.string(forKey: "apns_device_token") {
                await registerDeviceToken(savedToken)
            } else {
                let mockToken = "sim_token_\(currentUserProfile?.id ?? "")_apns_key"
                await registerDeviceToken(mockToken)
            }
        }
    }
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification permission granted.")
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } else if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }
}

private extension URL {
    var queryParameters: [String: String] {
        URLComponents(url: self, resolvingAgainstBaseURL: false)?
            .queryItems?
            .reduce(into: [String: String]()) { result, item in
                result[item.name] = item.value
            } ?? [:]
    }

    var fragmentParameters: [String: String] {
        guard let fragment else { return [:] }
        return URLComponents(string: "?\(fragment)")?
            .queryItems?
            .reduce(into: [String: String]()) { result, item in
                result[item.name] = item.value
            } ?? [:]
    }
}
