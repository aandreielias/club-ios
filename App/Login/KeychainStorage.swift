import ClubKit
import Foundation
import Security

/// Keeps the login session in the Keychain, only on this device and only after its first unlock.
struct KeychainStorage: SessionStorage {
    func load() -> Auth.Session? {
        var query = Self.query
        query[kSecReturnData as String] = true
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
        return try? JSONDecoder().decode(Auth.Session.self, from: data)
    }

    func save(_ session: Auth.Session?) {
        SecItemDelete(Self.query as CFDictionary)
        guard let session, let data = try? JSONEncoder().encode(session) else { return }
        var query = Self.query
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(query as CFDictionary, nil)
    }

    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "at.clubserver.app.session"]
    }
}
