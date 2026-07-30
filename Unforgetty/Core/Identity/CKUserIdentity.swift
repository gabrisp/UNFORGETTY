import Foundation
import Security

enum CKUserIdentity {
    private static let service = "com.gabrisp.Unforgetty.identity"
    private static let account = "ckuser"

    static func resolve() -> String {
        if let existing = read() { return existing }
        let created = UUID().uuidString.lowercased()
        save(created)
        return created
    }

    private static func read() -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account, kSecReturnData as String: true]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func save(_ value: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query.merging([kSecValueData as String: data], uniquingKeysWith: { _, new in new }) as CFDictionary, nil)
    }
}
