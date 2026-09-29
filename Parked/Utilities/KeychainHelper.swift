//
//  KeychainHelper.swift
//  SnapLingo
//

import Foundation
import Security

/// 安全存取 Claude API Key
enum KeychainHelper {
    private static let service = "name.Mia.SnapLingo"
    private static let apiKeyAccount = "claude_api_key"
    private static let authSessionAccount = "apple_auth_session"

    // MARK: - Shared Storage

    @discardableResult
    private static func saveData(_ data: Data, account: String) -> Bool {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        // 先删再写，避免重复项冲突
        SecItemDelete(query as CFDictionary)

        let attributes: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecValueData:   data
        ]
        return SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess
    }

    private static func loadData(account: String) -> Data? {
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrService:      service,
            kSecAttrAccount:      account,
            kSecReturnData:       true,
            kSecMatchLimit:       kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    @discardableResult
    private static func deleteData(account: String) -> Bool {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        return SecItemDelete(query as CFDictionary) == errSecSuccess
    }

    // MARK: - API Key

    @discardableResult
    static func saveAPIKey(_ key: String) -> Bool {
        saveData(Data(key.utf8), account: apiKeyAccount)
    }

    static func loadAPIKey() -> String? {
        guard let data = loadData(account: apiKeyAccount) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    static func deleteAPIKey() -> Bool {
        deleteData(account: apiKeyAccount)
    }

    static var hasAPIKey: Bool {
        loadAPIKey() != nil
    }

    // MARK: - Apple Auth Session

    @discardableResult
    static func saveAuthSession(_ session: AuthSession) -> Bool {
        guard let data = try? JSONEncoder().encode(session) else { return false }
        return saveData(data, account: authSessionAccount)
    }

    static func loadAuthSession() -> AuthSession? {
        guard let data = loadData(account: authSessionAccount) else { return nil }
        return try? JSONDecoder().decode(AuthSession.self, from: data)
    }

    @discardableResult
    static func deleteAuthSession() -> Bool {
        deleteData(account: authSessionAccount)
    }
}
