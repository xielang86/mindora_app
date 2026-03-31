//
//  Constants.swift
//  mindora
//
//  Created by GitHub Copilot on 2026/01/09.
//

import Foundation

struct Constants {
    struct Network {
        static let userServerBaseURL = "http://192.168.0.116:9001"
        static let authURL = "http://192.168.0.116:9103/auth"
        static let healthSyncURL = userServerBaseURL + "/user_profile"
        static let profileURL = userServerBaseURL + "/user_profile"
        static let analysisURL = userServerBaseURL + "/analysis"
        static let healthSyncInterval: HealthSyncInterval = .fifteenMinutes
        static let mindoraWebURL = "https://mindora316.com"
        static let termsOfUseURL = "https://mindora316.com/terms-of-service"
        static let privacyPolicyURL = "https://mindora316.com/privacy-policy"
        static let timeoutInterval: TimeInterval = 8.0
    }
    
    struct Config {
        /// Switch to enable detailed network logging (headers, body, response)
        static let enableNetworkLogging = true
        
        /// Unified switch for health-data-driven screens in Debug mode.
        /// true: show mock data
        /// false: prefer real data from Health app / HealthKit
        #if DEBUG
        static var showMockData = false
        #else
        static let showMockData = false
        #endif
        
        /// Skip email verification flow in Debug mode (bypass server requests)
        #if DEBUG
        static var skipEmailVerification = false
        #else
        static let skipEmailVerification = false
        #endif
    }
    
    struct Strings {
        static let splashTagline = "Personal insights\nto empower your\neveryday."
    }
    
    struct Contact {
        static let supportEmail = "support@mindora316.com"
    }
    
    struct Subscription {
        static let monthlyPrice = "$2.99"
        static let yearlyPrice = "$29.99"
        static let monthlyProductID = "com.mindora316.monthly"
        static let yearlyProductID = "com.mindora316.yearly"
    }
}
