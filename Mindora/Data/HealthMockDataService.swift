import Foundation
import UIKit

final class HealthMockDataService {
    static let shared = HealthMockDataService()

    typealias StageStatRow = (String, String, String)

    struct DayLocalData {
        let durationText: String
        let dateText: String
        let timeInBedText: String
        let sleepHeartRateText: String
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
        /// 呼吸频率（单值，次/分钟）。与真机口径一致——周/月是周期平均，不是区间
        let respiratoryRateText: String
        /// 静息心率（单值）。睡眠心率的平均值走 heartRateText，两者都是单值，与真机口径一致
        let restingHeartRateText: String
        /// 手腕温度（绝对值，摄氏度）。与真机路径一致，不是相对基线的偏差
        let wristTemperatureText: String
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
        /// 呼吸频率（单值，次/分钟）。与真机口径一致——周/月是周期平均，不是区间
        let respiratoryRateText: String
        /// 静息心率（单值）。睡眠心率的平均值走 heartRateText，两者都是单值，与真机口径一致
        let restingHeartRateText: String
        /// 手腕温度（绝对值，摄氏度）。与真机路径一致，不是相对基线的偏差
        let wristTemperatureText: String
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
            sleepHeartRateText: "56-79bpm",
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
            respiratoryRateText: "14bpm",
            restingHeartRateText: "58bpm",
            wristTemperatureText: "34.2°C",
            totalSleepText: "50hrs 8mins",
            averageAwakeText: "23min",
            averageRemText: "1hr 37min",
            averageCoreText: "4hr 3min",
            averageDeepText: "44min",
            timeInBedText: "45min",
            trackedDaysText: "6/7days",
            averageTotalText: "6hr",
            averageOnsetText: "8min"
        )
    }

    func monthLocalData() -> MonthLocalData {
        MonthLocalData(
            dateText: monthDateText(),
            chartValues: [7.8, 6.2, 5.3, 4.4, 6.7, 3.2, 7.2, 3.5, 4.2, 7.8, 5.2, 7.1, 5.5, 2.7, 4.0, 6.2, 7.5, 8.0, 6.5, 5.5, 4.8, 6.0, 7.2, 8.5, 7.0, 6.2, 5.8, 4.5, 6.8, 7.4],
            heartRateText: "92bpm",
            respiratoryRateText: "14bpm",
            restingHeartRateText: "58bpm",
            wristTemperatureText: "34.1°C",
            totalSleepText: "240hrs",
            averageAwakeText: "18min",
            averageRemText: "1hr 50min",
            averageCoreText: "4hr 3min",
            averageDeepText: "51min",
            timeInBedText: "7hr 45min",
            trackedDaysText: "15/30days",
            averageTotalText: "7hr 2min",
            averageOnsetText: "8min"
        )
    }

    private func dayDateText() -> String {
        let now = Date()
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        return DateDisplay.dateRange(from: yesterday, to: now)
    }

    // 假数据的区间也走 HealthChartWindow：真假两条路径同一套定义，
    // 免得改了窗口规则只改到真实那一边。
    private func weekDateText() -> String { HealthChartWindow.week(anchor: Date()).displayText }

    private func monthDateText() -> String { HealthChartWindow.month(anchor: Date()).displayText }
}