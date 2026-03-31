import Foundation

/// 健康数据时间锚点管理器
/// 负责管理同类健康数据在不同时间段之间的联动
/// 例如：当心率数据的年视图滑动到2024年时，其他时间段（日、周、月、6个月）都应该对应调整
final class HealthTimeAnchorManager {
    
    // MARK: - Singleton
    static let shared = HealthTimeAnchorManager()
    
    private init() {
        // 初始化所有锚点为当前日期
        let now = Date()
        heartRateAnchors = AnchorSet(baseDate: now)
        hrvAnchors = AnchorSet(baseDate: now)
        sleepAnchors = AnchorSet(baseDate: now)
    }
    
    // MARK: - Notification
    /// 当锚点变化时发送的通知
    static let anchorDidChangeNotification = Notification.Name("HealthTimeAnchorManager.anchorDidChange")
    
    /// 通知 userInfo 中用于标识数据类型的 key
    static let metricTypeKey = "metricType"
    /// 通知 userInfo 中用于标识时间周期的 key
    static let periodKey = "period"
    
    // MARK: - Period Definition (与 HealthDetailViewController.HealthPeriod 对应)
    enum Period: Int, CaseIterable {
        case day = 0
        case week = 1
        case month = 2
        case sixMonths = 3
        case year = 4
    }
    
    // MARK: - Metric Type (与 HealthDetailViewController.HealthMetricType 对应)
    enum MetricType {
        case heartRate
        case hrv
        case sleep
    }
    
    // MARK: - Anchor Set
    /// 存储各个时间段的锚点日期
    struct AnchorSet {
        var day: Date
        var week: Date
        var month: Date
        var sixMonths: Date
        var year: Date
        
        init(baseDate: Date) {
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: baseDate)
            self.day = startOfDay
            self.week = startOfDay
            self.month = startOfDay
            self.sixMonths = startOfDay
            self.year = startOfDay
        }
        
        subscript(period: Period) -> Date {
            get {
                switch period {
                case .day: return day
                case .week: return week
                case .month: return month
                case .sixMonths: return sixMonths
                case .year: return year
                }
            }
            set {
                switch period {
                case .day: day = newValue
                case .week: week = newValue
                case .month: month = newValue
                case .sixMonths: sixMonths = newValue
                case .year: year = newValue
                }
            }
        }
    }
    
    // MARK: - Storage
    private var heartRateAnchors: AnchorSet
    private var hrvAnchors: AnchorSet
    private var sleepAnchors: AnchorSet
    
    // MARK: - Public API
    
    /// 获取指定数据类型和时间段的锚点日期
    func getAnchor(for metricType: MetricType, period: Period) -> Date {
        switch metricType {
        case .heartRate: return heartRateAnchors[period]
        case .hrv: return hrvAnchors[period]
        case .sleep: return sleepAnchors[period]
        }
    }
    
    /// 设置指定数据类型和时间段的锚点日期，并同步其他时间段
    /// - Parameters:
    ///   - date: 新的锚点日期
    ///   - metricType: 数据类型
    ///   - period: 触发变化的时间段
    ///   - shouldSync: 是否同步其他时间段（默认 true）
    func setAnchor(_ date: Date, for metricType: MetricType, period: Period, shouldSync: Bool = true) {
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)
        
        switch metricType {
        case .heartRate:
            heartRateAnchors[period] = normalizedDate
            if shouldSync {
                syncOtherPeriods(from: period, baseDate: normalizedDate, anchors: &heartRateAnchors)
            }
        case .hrv:
            hrvAnchors[period] = normalizedDate
            if shouldSync {
                syncOtherPeriods(from: period, baseDate: normalizedDate, anchors: &hrvAnchors)
            }
        case .sleep:
            sleepAnchors[period] = normalizedDate
            if shouldSync {
                syncOtherPeriods(from: period, baseDate: normalizedDate, anchors: &sleepAnchors)
            }
        }
        
        // 发送通知
        NotificationCenter.default.post(
            name: Self.anchorDidChangeNotification,
            object: self,
            userInfo: [
                Self.metricTypeKey: metricType,
                Self.periodKey: period
            ]
        )
    }
    
    /// 重置指定数据类型的所有锚点到当前日期
    func resetAnchors(for metricType: MetricType) {
        let now = Date()
        let newAnchors = AnchorSet(baseDate: now)
        
        switch metricType {
        case .heartRate: heartRateAnchors = newAnchors
        case .hrv: hrvAnchors = newAnchors
        case .sleep: sleepAnchors = newAnchors
        }
    }
    
    /// 重置所有数据类型的锚点
    func resetAllAnchors() {
        let now = Date()
        heartRateAnchors = AnchorSet(baseDate: now)
        hrvAnchors = AnchorSet(baseDate: now)
        sleepAnchors = AnchorSet(baseDate: now)
    }
    
    /// 检查指定锚点是否为最新（即当前日期）
    func isAtLatest(for metricType: MetricType, period: Period) -> Bool {
        let calendar = Calendar.current
        let anchor = getAnchor(for: metricType, period: period)
        let today = calendar.startOfDay(for: Date())
        
        switch period {
        case .day:
            return calendar.isDate(anchor, inSameDayAs: today)
        case .week:
            // 检查是否在同一周
            return calendar.isDate(anchor, equalTo: today, toGranularity: .weekOfYear)
        case .month:
            // 检查是否在同一月
            return calendar.isDate(anchor, equalTo: today, toGranularity: .month)
        case .sixMonths:
            // 检查是否在最近6个月范围内
            guard let sixMonthsAgo = calendar.date(byAdding: .month, value: -6, to: today) else { return false }
            return anchor >= sixMonthsAgo
        case .year:
            // 检查是否在同一年
            return calendar.isDate(anchor, equalTo: today, toGranularity: .year)
        }
    }
    
    // MARK: - Private Helpers
    
    /// 根据一个时间段的变化同步其他时间段
    /// 核心逻辑：当某个时间段的锚点变化时，需要推算其他时间段应该对应的锚点
    private func syncOtherPeriods(from sourcePeriod: Period, baseDate: Date, anchors: inout AnchorSet) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // 根据变化的源时间段，计算其他时间段的锚点
        switch sourcePeriod {
        case .day:
            // 日视图变化 → 其他时间段锚点调整到包含该日的范围
            anchors.week = baseDate
            anchors.month = baseDate
            anchors.sixMonths = baseDate
            // 年锚点调整到该日所在年的年末（或当前日期，取较小者）
            let yearEnd = getYearEnd(for: baseDate, calendar: calendar) ?? baseDate
            anchors.year = min(yearEnd, today)
            
        case .week:
            // 周视图变化 → 日锚点调整到该周的最后一天
            anchors.day = baseDate
            anchors.month = baseDate
            anchors.sixMonths = baseDate
            let yearEnd = getYearEnd(for: baseDate, calendar: calendar) ?? baseDate
            anchors.year = min(yearEnd, today)
            
        case .month:
            // 月视图变化 → 日/周锚点调整到该月的最后一天
            anchors.day = baseDate
            anchors.week = baseDate
            anchors.sixMonths = baseDate
            let yearEnd = getYearEnd(for: baseDate, calendar: calendar) ?? baseDate
            anchors.year = min(yearEnd, today)
            
        case .sixMonths:
            // 6个月视图变化
            anchors.day = baseDate
            anchors.week = baseDate
            anchors.month = baseDate
            let yearEnd = getYearEnd(for: baseDate, calendar: calendar) ?? baseDate
            anchors.year = min(yearEnd, today)
            
        case .year:
            // 年视图变化 → 其他时间段锚点调整到该年的年末（或当前日期）
            let yearEnd = getYearEnd(for: baseDate, calendar: calendar) ?? baseDate
            let targetDate = min(yearEnd, today)
            anchors.day = targetDate
            anchors.week = targetDate
            anchors.month = targetDate
            anchors.sixMonths = targetDate
        }
    }
    
    /// 获取指定日期所在年的年末日期（12月31日）
    private func getYearEnd(for date: Date, calendar: Calendar) -> Date? {
        let year = calendar.component(.year, from: date)
        var components = DateComponents()
        components.year = year
        components.month = 12
        components.day = 31
        return calendar.date(from: components)
    }
}
