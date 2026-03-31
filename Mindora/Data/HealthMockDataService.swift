import Foundation
import UIKit

final class HealthMockDataService {
    static let shared = HealthMockDataService()

    typealias StageStatRow = (String, String, String)

    struct DayLocalData {
        let durationText: String
        let dateText: String
        let timeInBedText: String
        let restingHeartRateText: String
        let respiratoryRateText: String
        let bodyTemperatureText: String
        let scenarioOnsetText: String
        let stageValues: [Int: String]
        let stageStats: [Int: [StageStatRow]]
        let graphSegments: [(Int, Double)]
    }

    struct WeekLocalData {
        let dateText: String
        let chartValues: [CGFloat]
        let heartRateText: String
        let respiratoryRangeText: String
        let averageHeartRateRangeText: String
        let skinTemperatureDeltaText: String
        let totalSleepText: String
        let averageAwakeText: String
        let averageRemText: String
        let averageCoreText: String
        let averageDeepText: String
        let timeInBedText: String
        let trackedDaysText: String
        let averageTotalText: String
        let averageOnsetText: String
    }

    struct MonthLocalData {
        let dateText: String
        let chartValues: [CGFloat]
        let heartRateText: String
        let respiratoryRangeText: String
        let averageHeartRateRangeText: String
        let skinTemperatureDeltaText: String
        let totalSleepText: String
        let averageAwakeText: String
        let averageRemText: String
        let averageCoreText: String
        let averageDeepText: String
        let timeInBedText: String
        let trackedDaysText: String
        let averageTotalText: String
        let averageOnsetText: String
    }

    private init() {}

    func dayLocalData() -> DayLocalData {
        DayLocalData(
            durationText: "8h 12min",
            dateText: dayDateText(),
            timeInBedText: "8h 12min",
            restingHeartRateText: "80bpm",
            respiratoryRateText: "20bpm",
            bodyTemperatureText: "36°C",
            scenarioOnsetText: "5min",
            stageValues: [0: "10min", 1: "1h 30min", 2: "4h 15min", 3: "1h 45min"],
            stageStats: [
                0: [("Avg. heart rate", "80bpm", "sleep_day_heart_rate"), ("Respiratory rate", "20bpm", "sleep_day_respiratory_rate"), ("Body temperature", "36°C", "sleep_day_body_temperature")],
                1: [("Avg. heart rate", "72bpm", "sleep_day_heart_rate"), ("Respiratory rate", "18bpm", "sleep_day_respiratory_rate"), ("Body temperature", "36.4°C", "sleep_day_body_temperature")],
                2: [("Avg. heart rate", "65bpm", "sleep_day_heart_rate"), ("Respiratory rate", "16bpm", "sleep_day_respiratory_rate"), ("Body temperature", "36.2°C", "sleep_day_body_temperature")],
                3: [("Avg. heart rate", "58bpm", "sleep_day_heart_rate"), ("Respiratory rate", "15bpm", "sleep_day_respiratory_rate"), ("Body temperature", "36.0°C", "sleep_day_body_temperature")]
            ],
            graphSegments: [(0, 15), (2, 20), (3, 45), (2, 10), (1, 15), (2, 30), (3, 30), (2, 15), (1, 25), (0, 5), (2, 25), (3, 20), (1, 30), (2, 40), (1, 35), (2, 20), (0, 5), (2, 20), (1, 40), (2, 25), (0, 5)]
        )
    }

    func weekLocalData() -> WeekLocalData {
        WeekLocalData(
            dateText: weekDateText(),
            chartValues: [7.2, 9.0, 5.2, 3.8, 7.5, 7.2, 0.0],
            heartRateText: "80bpm",
            respiratoryRangeText: "9-27bpm",
            averageHeartRateRangeText: "49-84bpm",
            skinTemperatureDeltaText: "+0.08°C",
            totalSleepText: "50hrs 8mins",
            averageAwakeText: "23min",
            averageRemText: "1hr 37min",
            averageCoreText: "4hr 3min",
            averageDeepText: "44min",
            timeInBedText: "45min",
            trackedDaysText: "6/7days",
            averageTotalText: "6hr",
            averageOnsetText: "5-10min"
        )
    }

    func monthLocalData() -> MonthLocalData {
        MonthLocalData(
            dateText: monthDateText(),
            chartValues: [7.8, 6.2, 5.3, 4.4, 6.7, 3.2, 7.2, 3.5, 4.2, 7.8, 5.2, 7.1, 5.5, 2.7, 4.0, 6.2, 7.5, 8.0, 6.5, 5.5, 4.8, 6.0, 7.2, 8.5, 7.0, 6.2, 5.8, 4.5, 6.8, 7.4],
            heartRateText: "92bpm",
            respiratoryRangeText: "9-27bpm",
            averageHeartRateRangeText: "49-84bpm",
            skinTemperatureDeltaText: "+0.06°C",
            totalSleepText: "240hrs",
            averageAwakeText: "18min",
            averageRemText: "1hr 50min",
            averageCoreText: "4hr 3min",
            averageDeepText: "51min",
            timeInBedText: "7hr 45min",
            trackedDaysText: "15/30days",
            averageTotalText: "7hr 2min",
            averageOnsetText: "5-10min"
        )
    }

    private func dayDateText() -> String {
        let now = Date()
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "d"
        let dayBefore = formatter.string(from: yesterday)
        formatter.dateFormat = "d MMM yyyy"
        let dayAfter = formatter.string(from: now)
        return "\(dayBefore) - \(dayAfter)"
    }

    private func weekDateText() -> String {
        let now = Date()
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: now)
        let daysToMonday = (weekday == 1) ? -6 : (2 - weekday)
        let monday = calendar.date(byAdding: .day, value: daysToMonday, to: now) ?? now
        let sunday = calendar.date(byAdding: .day, value: 6, to: monday) ?? now
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "d"
        let startDay = formatter.string(from: monday)
        formatter.dateFormat = "d MMM yyyy"
        let endString = formatter.string(from: sunday)
        return "\(startDay) - \(endString)"
    }

    private func monthDateText() -> String {
        let now = Date()
        let calendar = Calendar.current
        let monthAgo = calendar.date(byAdding: .month, value: -1, to: now) ?? now
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "MMM d, yyyy"
        return "\(formatter.string(from: monthAgo)) – \(formatter.string(from: now))"
    }
}