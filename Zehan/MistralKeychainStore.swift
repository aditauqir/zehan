import Foundation
import LocalAuthentication
import Security

enum KeychainAccessGroup {
    static func resolved() -> String? {
        var code: SecCode?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code else {
            return nil
        }

        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode else {
            return nil
        }

        var information: CFDictionary?
        guard SecCodeCopySigningInformation(
            staticCode,
            SecCSFlags(rawValue: kSecCSSigningInformation),
            &information
        ) == errSecSuccess,
            let info = information as? [String: Any]
        else {
            return nil
        }

        let entitlements = (info[kSecCodeInfoEntitlementsDict as String] as? [String: Any])
            ?? (info["entitlements-dictionary"] as? [String: Any])

        guard let groups = entitlements?["keychain-access-groups"] as? [String],
              let group = groups.first,
              !group.isEmpty
        else {
            if let applicationIdentifier = entitlements?["com.apple.application-identifier"] as? String,
               !applicationIdentifier.isEmpty {
                return applicationIdentifier
            }
            return nil
        }

        return group
    }
}

enum MistralKeychainStore {
    enum KeychainError: LocalizedError {
        case missingAccessGroup
        case authenticationUnavailable(String)
        case authenticationCancelled
        case saveFailed(String, OSStatus)

        var errorDescription: String? {
            switch self {
            case .missingAccessGroup:
                return "Couldn't access Keychain. Reinstall the latest Zirn build, or run from Xcode with your Apple ID team selected in Signing & Capabilities."
            case .authenticationUnavailable(let message):
                return message
            case .authenticationCancelled:
                return "Authentication was cancelled."
            case .saveFailed(let providerName, let status):
                if let message = SecCopyErrorMessageString(status, nil) as String? {
                    return "Couldn't save the \(providerName) API key to Apple Passwords (\(message))."
                }
                return "Couldn't save the \(providerName) API key to Apple Passwords (error \(status))."
            }
        }
    }

    enum SaveLocation: Equatable {
        case applePasswords
        case localPasswords
    }

    static let appName = "Zirn"
    private static let legacyGenericService = appName
    private static let legacyGenericAccount = "Mistral API Key"

    enum Provider {
        case mistral
        case deepSeek

        var displayName: String {
            switch self {
            case .mistral:
                return "Mistral"
            case .deepSeek:
                return "DeepSeek"
            }
        }

        var server: String {
            switch self {
            case .mistral:
                return "api.mistral.ai"
            case .deepSeek:
                return "api.deepseek.com"
            }
        }

        var account: String {
            switch self {
            case .mistral:
                return appName
            case .deepSeek:
                return "\(appName) DeepSeek"
            }
        }

        var description: String {
            "\(displayName) API Key"
        }
    }

    static func saveMistralAPIKey(_ apiKey: String) async throws -> SaveLocation {
        try await saveAPIKey(apiKey, provider: .mistral)
    }

    static func saveDeepSeekAPIKey(_ apiKey: String) async throws -> SaveLocation {
        try await saveAPIKey(apiKey, provider: .deepSeek)
    }

    private static func saveAPIKey(_ apiKey: String, provider: Provider) async throws -> SaveLocation {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            deleteAPIKey(provider: provider)
            return .localPasswords
        }

        guard let accessGroup = KeychainAccessGroup.resolved() else {
            throw KeychainError.missingAccessGroup
        }

        try await authenticateUser(
            reason: "Authenticate to save your \(provider.displayName) API key to Apple Passwords."
        )

        deleteAPIKey(provider: provider)

        let passwordData = Data(trimmed.utf8)
        let strategies: [SaveLocation] = [.applePasswords, .localPasswords]

        var lastStatus = errSecParam
        for location in strategies {
            let synchronizable = location == .applePasswords
            let status = addInternetPassword(
                passwordData,
                provider: provider,
                accessGroup: accessGroup,
                synchronizable: synchronizable
            )

            if status == errSecSuccess {
                if verifySavedEntry(provider: provider) {
                    return location
                }
                lastStatus = errSecItemNotFound
                continue
            }

            if status == errSecDuplicateItem {
                let updateStatus = updateExistingInternetPassword(
                    passwordData,
                    provider: provider,
                    accessGroup: accessGroup,
                    synchronizable: synchronizable
                )
                if updateStatus == errSecSuccess, verifySavedEntry(provider: provider) {
                    return location
                }
                lastStatus = updateStatus
                continue
            }

            lastStatus = status
        }

        throw KeychainError.saveFailed(provider.displayName, lastStatus)
    }

    static func loadMistralAPIKey() async throws -> String? {
        try await loadAPIKey(provider: .mistral)
    }

    static func loadDeepSeekAPIKey() async throws -> String? {
        try await loadAPIKey(provider: .deepSeek)
    }

    private static func loadAPIKey(provider: Provider) async throws -> String? {
        let context = LAContext()
        context.localizedReason = "Authenticate to load your \(provider.displayName) API key from Apple Passwords."

        var policyError: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &policyError),
           let key = loadStoredAPIKey(provider: provider, authenticationContext: context) {
            return key
        }

        return loadStoredAPIKey(provider: provider, authenticationContext: nil)
    }

    static func hasSavedMistralAPIKey() -> Bool {
        hasSavedAPIKey(provider: .mistral)
    }

    static func hasSavedDeepSeekAPIKey() -> Bool {
        hasSavedAPIKey(provider: .deepSeek)
    }

    private static func hasSavedAPIKey(provider: Provider) -> Bool {
        hasInternetPasswordEntry(provider: provider, synchronizable: kSecAttrSynchronizableAny)
            || hasInternetPasswordEntry(provider: provider, synchronizable: kCFBooleanFalse as Any)
            || (provider == .mistral && loadLegacyGenericPassword() != nil)
    }

    static func deleteMistralAPIKey() {
        deleteAPIKey(provider: .mistral)
    }

    static func deleteDeepSeekAPIKey() {
        deleteAPIKey(provider: .deepSeek)
    }

    private static func deleteAPIKey(provider: Provider) {
        deleteInternetPassword(provider: provider, synchronizable: kSecAttrSynchronizableAny)
        deleteInternetPassword(provider: provider, synchronizable: kCFBooleanFalse as Any)

        guard provider == .mistral else { return }
        let genericQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: legacyGenericService,
            kSecAttrAccount as String: legacyGenericAccount
        ]
        SecItemDelete(genericQuery as CFDictionary)
    }

    private static func authenticateUser(reason: String) async throws {
        let context = LAContext()
        var policyError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &policyError) else {
            throw KeychainError.authenticationUnavailable(
                policyError?.localizedDescription ?? "Touch ID or your device passcode is required."
            )
        }

        try await withCheckedThrowingContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, error in
                if success {
                    continuation.resume()
                    return
                }

                if let error = error as? LAError, error.code == .userCancel {
                    continuation.resume(throwing: KeychainError.authenticationCancelled)
                    return
                }

                continuation.resume(throwing: KeychainError.authenticationUnavailable(
                    error?.localizedDescription ?? "Authentication failed."
                ))
            }
        }
    }

    private static func accessibility(for synchronizable: Bool) -> CFString {
        synchronizable
            ? kSecAttrAccessibleWhenUnlocked
            : kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    }

    private static func internetPasswordAttributes(
        passwordData: Data,
        provider: Provider,
        accessGroup: String,
        synchronizable: Bool
    ) -> [String: Any] {
        [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrAccessGroup as String: accessGroup,
            kSecAttrAccessible as String: accessibility(for: synchronizable),
            kSecAttrServer as String: provider.server,
            kSecAttrAccount as String: provider.account,
            kSecAttrProtocol as String: kSecAttrProtocolHTTPS,
            kSecAttrAuthenticationType as String: kSecAttrAuthenticationTypeDefault,
            kSecAttrPort as String: 443,
            kSecAttrPath as String: "/",
            kSecAttrLabel as String: appName,
            kSecAttrDescription as String: provider.description,
            kSecValueData as String: passwordData,
            kSecUseDataProtectionKeychain as String: kCFBooleanTrue as Any,
            kSecAttrSynchronizable as String: synchronizable ? kCFBooleanTrue as Any : kCFBooleanFalse as Any
        ]
    }

    private static func addInternetPassword(
        _ passwordData: Data,
        provider: Provider,
        accessGroup: String,
        synchronizable: Bool
    ) -> OSStatus {
        let attributes = internetPasswordAttributes(
            passwordData: passwordData,
            provider: provider,
            accessGroup: accessGroup,
            synchronizable: synchronizable
        )
        return SecItemAdd(attributes as CFDictionary, nil)
    }

    private static func verifySavedEntry(provider: Provider) -> Bool {
        hasInternetPasswordEntry(provider: provider, synchronizable: kSecAttrSynchronizableAny)
            || hasInternetPasswordEntry(provider: provider, synchronizable: kCFBooleanFalse as Any)
    }

    private static func updateExistingInternetPassword(
        _ passwordData: Data,
        provider: Provider,
        accessGroup: String,
        synchronizable: Bool
    ) -> OSStatus {
        let attributes: [String: Any] = [
            kSecAttrAccessible as String: accessibility(for: synchronizable),
            kSecValueData as String: passwordData,
            kSecAttrLabel as String: appName,
            kSecAttrDescription as String: provider.description,
            kSecUseDataProtectionKeychain as String: kCFBooleanTrue as Any
        ]

        var lastStatus = errSecItemNotFound
        for query in internetPasswordQueryVariants(
            provider: provider,
            synchronizable: synchronizable ? kCFBooleanTrue as Any : kCFBooleanFalse as Any
        ) {
            let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            if status == errSecSuccess {
                return errSecSuccess
            }
            lastStatus = status
        }
        return lastStatus
    }

    private static func resolvedAccessGroup() -> String? {
        KeychainAccessGroup.resolved()
    }

    private static func internetPasswordQuery(
        provider: Provider,
        synchronizable: Any,
        accessGroup: String? = resolvedAccessGroup()
    ) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: provider.server,
            kSecAttrAccount as String: provider.account,
            kSecUseDataProtectionKeychain as String: kCFBooleanTrue as Any,
            kSecAttrSynchronizable as String: synchronizable
        ]

        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        return query
    }

    private static func internetPasswordQueryVariants(
        provider: Provider,
        synchronizable: Any
    ) -> [[String: Any]] {
        if let accessGroup = resolvedAccessGroup() {
            return [
                internetPasswordQuery(provider: provider, synchronizable: synchronizable, accessGroup: accessGroup),
                internetPasswordQuery(provider: provider, synchronizable: synchronizable, accessGroup: nil)
            ]
        }
        return [internetPasswordQuery(provider: provider, synchronizable: synchronizable, accessGroup: nil)]
    }

    private static func deleteInternetPassword(provider: Provider, synchronizable: Any) {
        for query in internetPasswordQueryVariants(provider: provider, synchronizable: synchronizable) {
            SecItemDelete(query as CFDictionary)
        }
    }

    private static func hasInternetPasswordEntry(provider: Provider, synchronizable: Any) -> Bool {
        for query in internetPasswordQueryVariants(provider: provider, synchronizable: synchronizable) {
            var item: CFTypeRef?
            var lookup = query
            lookup[kSecReturnAttributes as String] = kCFBooleanTrue as Any
            lookup[kSecMatchLimit as String] = kSecMatchLimitOne
            if SecItemCopyMatching(lookup as CFDictionary, &item) == errSecSuccess {
                return true
            }
        }
        return false
    }

    private static func loadStoredAPIKey(provider: Provider, authenticationContext: LAContext?) -> String? {
        var accountCandidates = [provider.account]
        if provider == .mistral {
            accountCandidates.append(contentsOf: [appName, appName.lowercased(), legacyGenericAccount])
        }
        for account in accountCandidates {
            if let key = loadInternetPassword(
                server: provider.server,
                account: account,
                synchronizable: kSecAttrSynchronizableAny,
                authenticationContext: authenticationContext
            ) {
                return key
            }

            if let key = loadInternetPassword(
                server: provider.server,
                account: account,
                synchronizable: kCFBooleanFalse as Any,
                authenticationContext: authenticationContext
            ) {
                return key
            }
        }

        if let key = loadBestMatchingInternetPassword(
            provider: provider,
            authenticationContext: authenticationContext
        ) {
            return key
        }

        return provider == .mistral ? loadLegacyGenericPassword() : nil
    }

    private static func loadInternetPassword(
        server: String,
        account: String,
        synchronizable: Any,
        authenticationContext: LAContext?
    ) -> String? {
        let queryBases: [[String: Any]] = {
            var queries: [[String: Any]] = []
            if let accessGroup = resolvedAccessGroup() {
                queries.append([
                    kSecClass as String: kSecClassInternetPassword,
                    kSecAttrServer as String: server,
                    kSecAttrAccount as String: account,
                    kSecAttrAccessGroup as String: accessGroup,
                    kSecUseDataProtectionKeychain as String: kCFBooleanTrue as Any,
                    kSecAttrSynchronizable as String: synchronizable
                ])
            }
            queries.append([
                kSecClass as String: kSecClassInternetPassword,
                kSecAttrServer as String: server,
                kSecAttrAccount as String: account,
                kSecUseDataProtectionKeychain as String: kCFBooleanTrue as Any,
                kSecAttrSynchronizable as String: synchronizable
            ])
            queries.append([
                kSecClass as String: kSecClassInternetPassword,
                kSecAttrServer as String: server,
                kSecAttrAccount as String: account,
                kSecAttrSynchronizable as String: synchronizable
            ])
            return queries
        }()

        for baseQuery in queryBases {
            var query = baseQuery
            query[kSecReturnData as String] = kCFBooleanTrue as Any
            query[kSecMatchLimit as String] = kSecMatchLimitOne
            if let key = copyPasswordData(from: query, authenticationContext: authenticationContext) {
                return key
            }
        }

        return nil
    }

    private static func loadBestMatchingInternetPassword(
        provider: Provider,
        authenticationContext: LAContext?
    ) -> String? {
        let queryBases: [[String: Any]] = {
            var queries: [[String: Any]] = []
            if let accessGroup = resolvedAccessGroup() {
                queries.append([
                    kSecClass as String: kSecClassInternetPassword,
                    kSecAttrServer as String: provider.server,
                    kSecAttrAccessGroup as String: accessGroup,
                    kSecReturnData as String: kCFBooleanTrue as Any,
                    kSecReturnAttributes as String: kCFBooleanTrue as Any,
                    kSecMatchLimit as String: kSecMatchLimitAll,
                    kSecUseDataProtectionKeychain as String: kCFBooleanTrue as Any,
                    kSecAttrSynchronizable as String: kSecAttrSynchronizableAny
                ])
                queries.append([
                    kSecClass as String: kSecClassInternetPassword,
                    kSecAttrServer as String: provider.server,
                    kSecAttrAccessGroup as String: accessGroup,
                    kSecReturnData as String: kCFBooleanTrue as Any,
                    kSecReturnAttributes as String: kCFBooleanTrue as Any,
                    kSecMatchLimit as String: kSecMatchLimitAll,
                    kSecUseDataProtectionKeychain as String: kCFBooleanTrue as Any,
                    kSecAttrSynchronizable as String: kCFBooleanFalse as Any
                ])
            }
            queries.append([
                kSecClass as String: kSecClassInternetPassword,
                kSecAttrServer as String: provider.server,
                kSecReturnData as String: kCFBooleanTrue as Any,
                kSecReturnAttributes as String: kCFBooleanTrue as Any,
                kSecMatchLimit as String: kSecMatchLimitAll,
                kSecUseDataProtectionKeychain as String: kCFBooleanTrue as Any,
                kSecAttrSynchronizable as String: kSecAttrSynchronizableAny
            ])
            queries.append([
                kSecClass as String: kSecClassInternetPassword,
                kSecAttrServer as String: provider.server,
                kSecReturnData as String: kCFBooleanTrue as Any,
                kSecReturnAttributes as String: kCFBooleanTrue as Any,
                kSecMatchLimit as String: kSecMatchLimitAll,
                kSecUseDataProtectionKeychain as String: kCFBooleanTrue as Any,
                kSecAttrSynchronizable as String: kCFBooleanFalse as Any
            ])
            return queries
        }()

        for query in queryBases {
            if let items = copyMatchingItems(from: query, authenticationContext: authenticationContext),
               let match = bestMatchingPassword(from: items, provider: provider) {
                return match
            }
        }

        return nil
    }

    private static func loadLegacyGenericPassword() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: legacyGenericService,
            kSecAttrAccount as String: legacyGenericAccount,
            kSecReturnData as String: kCFBooleanTrue as Any,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        return copyPasswordData(from: query, authenticationContext: nil)
    }

    private static func bestMatchingPassword(from items: [[String: Any]], provider: Provider) -> String? {
        let providerName = provider.displayName.lowercased()
        let ranked = items.compactMap { item -> (Int, String)? in
            guard let data = item[kSecValueData as String] as? Data,
                  let password = String(data: data, encoding: .utf8),
                  !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                return nil
            }

            let account = (item[kSecAttrAccount as String] as? String ?? "").lowercased()
            let label = (item[kSecAttrLabel as String] as? String ?? "").lowercased()
            let description = (item[kSecAttrDescription as String] as? String ?? "").lowercased()

            var score = 0
            if account.contains("zirn") { score += 4 }
            if label.contains("zirn") { score += 3 }
            if description.contains(providerName) { score += 2 }
            if account.contains(providerName) { score += 2 }
            if label.contains(providerName) { score += 1 }

            return (score, password)
        }
        .sorted { $0.0 > $1.0 }

        return ranked.first?.1
    }

    private static func copyPasswordData(
        from query: [String: Any],
        authenticationContext: LAContext?
    ) -> String? {
        var query = query
        if let authenticationContext {
            query[kSecUseAuthenticationContext as String] = authenticationContext
        }

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let password = String(data: data, encoding: .utf8),
              !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return nil
        }
        return password
    }

    private static func copyMatchingItems(
        from query: [String: Any],
        authenticationContext: LAContext?
    ) -> [[String: Any]]? {
        var query = query
        if let authenticationContext {
            query[kSecUseAuthenticationContext as String] = authenticationContext
        }

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { return nil }

        if let dictionary = item as? [String: Any] {
            return [dictionary]
        }

        if let array = item as? [[String: Any]] {
            return array
        }

        return nil
    }
}
