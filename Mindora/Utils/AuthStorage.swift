//
//  AuthStorage.swift
//  mindora
//
//  Created by GitHub Copilot.
//

import Foundation
import Security

final class AuthStorage {
    static let shared = AuthStorage()
    
    private let tokenKey = "auth_token"
    private let expirationDateKey = "auth_expiration_date"
    private let uidKey = "auth_uid"
    private let emailKey = "auth_email"
    
    private init() {}
    
    // MARK: - Save
    
    func saveLoginInfo(email: String, uid: String, token: String, expireDays: Int) {
        // Save sensitive data to Keychain
        KeychainHelper.standard.save(email, forKey: emailKey)
        KeychainHelper.standard.save(uid, forKey: uidKey)
        KeychainHelper.standard.save(token, forKey: tokenKey)
        
        // Calculate and save expiration date
        // Default to a reasonably long time if expireDays is 0 or negative for some reason
        let days = expireDays > 0 ? expireDays : 30
        let expirationDate = Date().addingTimeInterval(TimeInterval(days * 24 * 60 * 60))
        let timestamp = expirationDate.timeIntervalSince1970
        KeychainHelper.standard.save(String(timestamp), forKey: expirationDateKey)
        
        // Also save a logged in flag if needed, though existence of token might be enough
        UserDefaults.standard.set(true, forKey: "isLoggedIn")
    }
    
    // MARK: - Read
    
    var email: String? {
        return KeychainHelper.standard.read(forKey: emailKey)
    }
    
    var uid: String? {
        return KeychainHelper.standard.read(forKey: uidKey)
    }

    var preferredUserIdentifier: String? {
        let normalizedEmail = email?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !normalizedEmail.isEmpty {
            return normalizedEmail
        }

        let normalizedUID = uid?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return normalizedUID.isEmpty ? nil : normalizedUID
    }
    
    var token: String? {
        return KeychainHelper.standard.read(forKey: tokenKey)
    }
    
    var expirationDate: Date? {
        if let timestampString = KeychainHelper.standard.read(forKey: expirationDateKey),
           let timestamp = TimeInterval(timestampString) {
            return Date(timeIntervalSince1970: timestamp)
        }
        return nil
    }
    
    var isLoggedIn: Bool {
        // Check keychain for valid session first
        if let token = token, !token.isEmpty,
           let email = email, !email.isEmpty,
           let uid = uid, !uid.isEmpty,
           let expirationDate = expirationDate {
            
            if Date() < expirationDate {
                return true
            }
        }
        
        // Fallback to UserDefaults if needed, but Keychain is source of truth for "valid session"
        return UserDefaults.standard.bool(forKey: "isLoggedIn")
    }
    
    // MARK: - Clear
    
    func clearLoginInfo() {
        KeychainHelper.standard.delete(forKey: emailKey)
        KeychainHelper.standard.delete(forKey: uidKey)
        KeychainHelper.standard.delete(forKey: tokenKey)
        KeychainHelper.standard.delete(forKey: expirationDateKey)
        
        UserDefaults.standard.set(false, forKey: "isLoggedIn")
    }
}

// MARK: - Keychain Helper

private class KeychainHelper {
    static let standard = KeychainHelper()
    private init() {}
    
    func save(_ data: Data, forKey key: String) {
        let deleteQuery = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key
        ] as [String: Any]
        
        SecItemDelete(deleteQuery as CFDictionary)
        
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecValueData: data
        ] as [String: Any]
        
        SecItemAdd(query as CFDictionary, nil)
    }
    
    func save(_ string: String, forKey key: String) {
        if let data = string.data(using: .utf8) {
            save(data, forKey: key)
        }
    }
    
    func readData(forKey key: String) -> Data? {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ] as [String: Any]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess {
            return dataTypeRef as? Data
        }
        return nil
    }
    
    func read(forKey key: String) -> String? {
        if let data = readData(forKey: key) {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
    
    func delete(forKey key: String) {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key
        ] as [String: Any]
        
        SecItemDelete(query as CFDictionary)
    }
}
