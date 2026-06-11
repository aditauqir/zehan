import Foundation
import Security

enum MistralKeychainStore {
    enum KeychainError: LocalizedError {
        case saveFailed(OSStatus)

        var errorDescription: String? {
            switch self {
            case .saveFailed(let status):
                return "Couldn't save the Mistral API key to Apple Passwords (error \(status))."
            }
        }
    }

    static let appName = "Zirn"
    private static let mistralServer = "api.mistral.ai"
    private static let legacyService = appName
    private static let legacyAccount = "Mistral API Key"

    /// Saves the Mistral API key as an internet password so it appears in Apple Passwords.
    static func saveMistralAPIKey(_ apiKey: String) throws {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            deleteMistralAPIKey()
            return
        }

        deleteMistralAPIKey()

        let passwordData = Data(trimmed.utf8)
        var query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: mistralServer,
            kSecAttrAccount as String: appName,
            kSecAttrLabel as String: "\(appName) — Mistral",
            kSecValueData as String: passwordData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        var status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let updateQuery: [String: Any] = [
                kSecClass as String: kSecClassInternetPassword,
                kSecAttrServer as String: mistralServer,
                kSecAttrAccount as String: appName
            ]
            let attributes: [String: Any] = [
                kSecValueData as String: passwordData,
                kSecAttrLabel as String: "\(appName) — Mistral"
            ]
            status = SecItemUpdate(updateQuery as CFDictionary, attributes as CFDictionary)
        }

        if status == errSecSuccess {
            return
        }

        query.removeValue(forKey: kSecAttrSynchronizable as String)
        status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    static func loadMistralAPIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: mistralServer,
            kSecAttrAccount as String: appName,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecSuccess,
           let data = item as? Data,
           let key = String(data: data, encoding: .utf8),
           !key.isEmpty {
            return key
        }

        return loadLegacyGenericMistralAPIKey()
    }

    static func deleteMistralAPIKey() {
        let internetQuery: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: mistralServer,
            kSecAttrAccount as String: appName
        ]
        SecItemDelete(internetQuery as CFDictionary)

        let genericQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: legacyService,
            kSecAttrAccount as String: legacyAccount
        ]
        SecItemDelete(genericQuery as CFDictionary)
    }

    static func migrateMistralAPIKeyFromUserDefaults(key: String) {
        let defaults = UserDefaults.standard
        guard let legacy = defaults.string(forKey: key)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !legacy.isEmpty
        else {
            defaults.removeObject(forKey: key)
            return
        }

        if loadMistralAPIKey() == nil {
            try? saveMistralAPIKey(legacy)
        }
        defaults.removeObject(forKey: key)
    }

    private static func loadLegacyGenericMistralAPIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: legacyService,
            kSecAttrAccount as String: legacyAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let key = String(data: data, encoding: .utf8),
              !key.isEmpty
        else {
            return nil
        }
        return key
    }
}
