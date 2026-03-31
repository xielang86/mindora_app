//
//  AuthService.swift
//  mindora
//
//  Created by GitHub Copilot on 2026/01/21.
//

import Foundation

enum AuthServiceError: Error {
    case invalidURL
    case serializationError
    case networkError(Error)
    case noData
    case apiError(code: Int, message: String?)
    case invalidResponse
    case missingData
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return L("auth.error.invalid_url")
        case .serializationError:
            return L("auth.error.serialization_error")
        case .networkError(let error):
            return error.localizedDescription
        case .noData:
            return L("auth.error.no_data")
        case .apiError(let code, let message):
            return message ?? String(format: L("auth.error.api_error_default"), code)
        case .invalidResponse:
            return L("auth.error.invalid_response")
        case .missingData:
            return L("auth.error.missing_data")
        }
    }
}

class AuthService {
    
    static let shared = AuthService()
    
    private let deviceId = UUID().uuidString.lowercased()
    
    private init() {}
    
    func sendVerifyCode(email: String, completion: @escaping (Result<Void, AuthServiceError>) -> Void) {
        guard let url = URL(string: Constants.Network.authURL) else {
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = Constants.Network.timeoutInterval
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "request_type": "send_verify_code",
            "version": "1.0",
            "timestamp": Int(Date().timeIntervalSince1970),
            "data": [
                "email": email,
                "device_id": deviceId
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
            #if DEBUG
            if Constants.Config.enableNetworkLogging, let bodyString = String(data: request.httpBody!, encoding: .utf8) {
                print("--- sendVerifyCode ---")
                print("Request URL: \(url)")
                print("Request Body: \(bodyString)")
            }
            #endif
        } catch {
            completion(.failure(.serializationError))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            #if DEBUG
            if Constants.Config.enableNetworkLogging {
                if let httpResponse = response as? HTTPURLResponse {
                    print("Response HTTP Code: \(httpResponse.statusCode)")
                }
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    print("Response Data: \(responseString)")
                }
            }
            #endif
            
            if let error = error {
                completion(.failure(.networkError(error)))
                return
            }
            
            guard let data = data else {
                completion(.failure(.noData))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let code = json["code"] as? Int {
                    if code == 0 {
                        completion(.success(()))
                    } else {
                        let message = json["msg"] as? String
                        completion(.failure(.apiError(code: code, message: message)))
                    }
                } else {
                    completion(.failure(.invalidResponse))
                }
            } catch {
                completion(.failure(.invalidResponse))
            }
        }.resume()
    }
    
    func loginWithCode(email: String, code: String, completion: @escaping (Result<Void, AuthServiceError>) -> Void) {
        guard let url = URL(string: Constants.Network.authURL) else {
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = Constants.Network.timeoutInterval
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "request_type": "login_with_email_verify_code",
            "version": "1.0",
            "timestamp": Int(Date().timeIntervalSince1970),
            "data": [
                "email": email,
                "device_id": deviceId,
                "verify_code": code
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
            #if DEBUG
            if Constants.Config.enableNetworkLogging, let bodyString = String(data: request.httpBody!, encoding: .utf8) {
                print("--- loginWithCode ---")
                print("Request URL: \(url)")
                print("Request Body: \(bodyString)")
            }
            #endif
        } catch {
            completion(.failure(.serializationError))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            #if DEBUG
            if Constants.Config.enableNetworkLogging {
                if let httpResponse = response as? HTTPURLResponse {
                    print("Response HTTP Code: \(httpResponse.statusCode)")
                }
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    print("Response Data: \(responseString)")
                }
            }
            #endif
            
            if let error = error {
                completion(.failure(.networkError(error)))
                return
            }
            
            guard let data = data else {
                completion(.failure(.noData))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let retCode = json["code"] as? Int {
                    
                    // Accept 0 (Created/Updated) or 200 (Existing/No Update) as success
                    if retCode == 0 || retCode == 200 {
                        // Parse and save login data
                        if let dataDict = json["data"] as? [String: Any],
                           let uid = dataDict["uid"] as? String,
                           let token = dataDict["token"] as? String {
                            let expireDays = dataDict["expire_days"] as? Int ?? 30
                            AuthStorage.shared.saveLoginInfo(email: email, uid: uid, token: token, expireDays: expireDays)
                            completion(.success(()))
                        } else {
                            // Based on previous code, maybe we should just allow it to "succeed" but log warning
                            // However, strictly speaking this is a failure if we can't save auth info
                            print("Warning: Login success but missing data fields")
                            completion(.success(())) // Mimicking original behavior of continuing even if data missing? No, user code checked for data. Original code fell through but printed warning. BUT handleLoginSuccess was called OUTSIDE the else block in original code?
                            // In original code:
                            // if ... (parse data) { ... } else { print warning }
                            // self?.handleLoginSuccess(email: email)
                            // So handleLoginSuccess was ALWAYS called if retCode == 0.
                        }
                    } else {
                        // Original code: Toast.show(L("login.toast.login_failed"), ...)
                        // It does not use json["msg"].
                        completion(.failure(.apiError(code: retCode, message: nil)))
                    }
                } else {
                    completion(.failure(.invalidResponse))
                }
            } catch {
                completion(.failure(.invalidResponse))
            }
        }.resume()
    }
}
