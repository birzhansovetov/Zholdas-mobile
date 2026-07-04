import Foundation
import Security

final class TokenStorage: @unchecked Sendable {
    static let shared = TokenStorage()
    
    private let accountAccess = "zholdas_access_token"
    private let accountRefresh = "zholdas_refresh_token"
    private let service = "app.zholdas.keychain"
    
    private init() {}
    
    func saveTokens(accessToken: String, refreshToken: String) -> Bool {
        let accessSaved = save(key: accountAccess, value: accessToken)
        let refreshSaved = save(key: accountRefresh, value: refreshToken)
        return accessSaved && refreshSaved
    }
    
    func getAccessToken() -> String? {
        return read(key: accountAccess)
    }
    
    func getRefreshToken() -> String? {
        return read(key: accountRefresh)
    }
    
    func clear() {
        delete(key: accountAccess)
        delete(key: accountRefresh)
    }
    
    // MARK: - Low Level SecItem Operations
    
    private func save(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        
        // Сначала удаляем старое значение
        delete(key: key)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    private func read(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess, let data = dataTypeRef as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
    
    private func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
