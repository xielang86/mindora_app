//
//  HomeService.swift
//  mindora
//
//  Created by GitHub Copilot.
//

import Foundation

struct HomeData {
    // Metrics (from HealthKit)
    let heartRate: String?
    let totalSleep: String?
    let sleepOnset: String?
    let deepSleep: String?
    
    // Cards (from API)
    let comfortAudioName: String?
    let usedTimes: Int?
    let comfortAudioScore: Int?
    let overallScore: Int?
    let insightTitle: String?
    let insightDescription: String?
}

class HomeService {
    static let shared = HomeService()
    private let logTag = "HomeService"
    
    private init() {}

    private struct LocalMetricsSnapshot {
        let heartRate: String?
        let totalSleep: String?
        let sleepOnset: String?
        let deepSleep: String?
    }

    private struct AnalysisOverviewRequest: Encodable {
        let requestType = "analysis_overview"
        let version = "1.0"
        let timestamp: Int
        let data: Payload

        struct Payload: Encodable {
            let uid: String
            let jwtToken: String
            let language: String
            let date: String
            let timezone: String
            let modules: [String]

            enum CodingKeys: String, CodingKey {
                case uid
                case jwtToken = "jwt_token"
                case language
                case date
                case timezone
                case modules
            }
        }

        enum CodingKeys: String, CodingKey {
            case requestType = "request_type"
            case version
            case timestamp
            case data
        }
    }

    private struct HomeDashboardResponse: Decodable {
        let code: Int
        let msg: String?
        let data: DashboardData?
    }

    private struct DashboardData: Decodable {
        let overallScore: OverallScorePayload?
        let weeklyBest: WeeklyBestPayload?
        let sleepInsight: SleepInsightPayload?

        enum CodingKeys: String, CodingKey {
            case overallScore = "overall_score"
            case weeklyBest = "weekly_best"
            case sleepInsight = "sleep_insight"
        }
    }

    private struct OverallScorePayload: Decodable {
        let score: Int?
    }

    private struct WeeklyBestPayload: Decodable {
        let audioName: String?
        let usedTimes: Int?
        let score: Int?

        enum CodingKeys: String, CodingKey {
            case audioName = "audio_name"
            case usedTimes = "used_times"
            case score
        }
    }

    private struct SleepInsightPayload: Decodable {
        let title: String?
        let description: String?
    }

    private enum HomeServiceError: Error {
        case invalidURL
        case invalidResponse
        case apiError(code: Int, message: String?)
    }
    
    func fetchHomeData(completion: @escaping (Result<HomeData, Error>) -> Void) {
        if Constants.Config.showMockData {
            // Mock data for UI preview (DEBUG only)
            DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
                let mockData = HomeData(
                    heartRate: "80",
                    totalSleep: "8h",
                    sleepOnset: "5min",
                    deepSleep: "5h",
                    comfortAudioName: "Sedona Red Rocks",
                    usedTimes: 5,
                    comfortAudioScore: 92,
                    overallScore: 88,
                    insightTitle: "Excellent Deep Sleep Performance",
                    insightDescription: "Your deep sleep accounts for 29.8% of your total sleep, above the standard level. Keep maintaining a regular sleep schedule."
                )
                DispatchQueue.main.async {
                    completion(.success(mockData))
                }
            }
            return
        }
        
        // Real mode: fetch data from HealthKit + API
        fetchRealData(completion: completion)
    }
    
    private func fetchRealData(completion: @escaping (Result<HomeData, Error>) -> Void) {
        Task {
            async let localMetricsTask = fetchLocalMetrics()
            async let dashboardTask = fetchDashboardData()

            let localMetrics: LocalMetricsSnapshot
            do {
                localMetrics = try await localMetricsTask
            } catch {
                Log.error(logTag, "Failed to fetch HealthKit metrics: \(error)")
                localMetrics = LocalMetricsSnapshot(
                    heartRate: nil,
                    totalSleep: nil,
                    sleepOnset: nil,
                    deepSleep: nil
                )
            }

            let dashboardData: DashboardData?
            do {
                dashboardData = try await dashboardTask
            } catch {
                Log.error(logTag, "Failed to fetch analysis overview data: \(error)")
                dashboardData = nil
            }

            let data = HomeData(
                heartRate: localMetrics.heartRate,
                totalSleep: localMetrics.totalSleep,
                sleepOnset: localMetrics.sleepOnset,
                deepSleep: localMetrics.deepSleep,
                comfortAudioName: dashboardData?.weeklyBest?.audioName,
                usedTimes: dashboardData?.weeklyBest?.usedTimes,
                comfortAudioScore: dashboardData?.weeklyBest?.score,
                overallScore: dashboardData?.overallScore?.score,
                insightTitle: dashboardData?.sleepInsight?.title,
                insightDescription: dashboardData?.sleepInsight?.description
            )
            
            DispatchQueue.main.async {
                completion(.success(data))
            }
        }
    }

    private func fetchLocalMetrics() async throws -> LocalMetricsSnapshot {
        var heartRate: String?
        var totalSleep: String?
        var sleepOnset: String?
        var deepSleep: String?

        let metrics = try await HealthDataManager.shared.fetchLatestMetrics(forceLive: true)

        if let hr = metrics.heartRate {
            heartRate = "\(Int(hr.value))"
        }

        if let sleep = metrics.sleepSummary {
            totalSleep = formatHoursAndMinutes(sleep.totalSleepHours)

            if let deep = sleep.deepSleepHours {
                deepSleep = formatHoursAndMinutes(deep)
            }
        }

        if let dailySleep = try await HealthDataManager.shared.fetchSleepDailyAggregates(days: 1).last,
           let onsetMinutes = dailySleep.sleepOnsetMinutes {
            let roundedOnset = Int(onsetMinutes.rounded())
            sleepOnset = "\(roundedOnset)min"
        }

        return LocalMetricsSnapshot(
            heartRate: heartRate,
            totalSleep: totalSleep,
            sleepOnset: sleepOnset,
            deepSleep: deepSleep
        )
    }

    private func fetchDashboardData() async throws -> DashboardData? {
        guard let uid = AuthStorage.shared.preferredUserIdentifier, !uid.isEmpty,
              let jwtToken = AuthStorage.shared.token, !jwtToken.isEmpty else {
            return nil
        }

        guard let url = URL(string: Constants.Network.analysisURL) else {
            throw HomeServiceError.invalidURL
        }

        let payload = AnalysisOverviewRequest(
            timestamp: Int(Date().timeIntervalSince1970),
            data: .init(
                uid: uid,
                jwtToken: jwtToken,
                language: LocalizationManager.shared.currentLanguage.rawValue,
                date: currentLocalDateString(),
                timezone: TimeZone.current.identifier,
                modules: ["overall_score", "weekly_best", "sleep_insight"]
            )
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = Constants.Network.timeoutInterval
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = AuthStorage.shared.token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let body = try JSONEncoder().encode(payload)
        request.httpBody = body

        if Constants.Config.enableNetworkLogging {
            Log.info(logTag, "analysis_overview request url=\(url.absoluteString)")
            Log.info(logTag, "analysis_overview request body=\(Log.prettyJSON(body))")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            if let httpResponse = response as? HTTPURLResponse {
                Log.error(logTag, "analysis_overview invalid HTTP status=\(httpResponse.statusCode)")
            } else {
                Log.error(logTag, "analysis_overview invalid HTTP response")
            }
            throw HomeServiceError.invalidResponse
        }

        if Constants.Config.enableNetworkLogging {
            Log.info(logTag, "analysis_overview response status=\(httpResponse.statusCode)")
            Log.info(logTag, "analysis_overview response body=\(Log.prettyJSON(data))")
        }

        let decoded = try JSONDecoder().decode(HomeDashboardResponse.self, from: data)
        guard decoded.code == 0 else {
            Log.error(logTag, "analysis_overview business error code=\(decoded.code), msg=\(decoded.msg ?? "")")
            throw HomeServiceError.apiError(code: decoded.code, message: decoded.msg)
        }

        Log.info(logTag, "analysis_overview completed successfully")

        return decoded.data
    }

    private func formatHoursAndMinutes(_ hoursValue: Double) -> String {
        let hours = Int(hoursValue)
        let minutes = Int((hoursValue - Double(hours)) * 60)

        if minutes > 0 {
            return "\(hours)h\(minutes)min"
        }
        return "\(hours)h"
    }

    private func currentLocalDateString() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
