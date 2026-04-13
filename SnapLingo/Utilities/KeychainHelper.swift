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

    // MARK: - Save

    @discardableResult
    static func saveAPIKey(_ key: String) -> Bool {
        let data = Data(key.utf8)
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: apiKeyAccount
        ]
        // 先删再写，避免重复项冲突
        SecItemDelete(query as CFDictionary)

        let attributes: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: apiKeyAccount,
            kSecValueData:   data
        ]
        return SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess
    }

    // MARK: - Load

    static func loadAPIKey() -> String? {
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrService:      service,
            kSecAttrAccount:      apiKeyAccount,
            kSecReturnData:       true,
            kSecMatchLimit:       kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            return nil
        }
        return key
    }

    // MARK: - Delete

    @discardableResult
    static func deleteAPIKey() -> Bool {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: apiKeyAccount
        ]
        return SecItemDelete(query as CFDictionary) == errSecSuccess
    }

    static var hasAPIKey: Bool {
        loadAPIKey() != nil
    }
}
