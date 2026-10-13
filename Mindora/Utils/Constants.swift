//
//  Constants.swift
//  mindora
//
//  Created by GitHub Copilot on 2026/01/09.
//

import Foundation

struct Constants {
    struct Network {
        static let userServerBaseURL = "https://api.mindora316.com"
        static let authURL = userServerBaseURL + "/auth"
        static let userServerURL = userServerBaseURL +  "/user_server"
        /// 用户资料读写 + 健康数据同步共用同一端点，靠请求体 request_type / payload 区分
        static let profileURL = userServerURL + "/user_profile"
        static let analysisURL = userServerURL + "/analysis"
        /// 首页弹窗下发（活动/广告/调研邀请），详见 Tools/doc/弹窗与调查问卷接口.md
        static let popupURL = userServerURL + "/popup"
        /// 调查问卷拉题 / 提交，详见 Tools/doc/弹窗与调查问卷接口.md
        static let surveyURL = userServerURL + "/survey"
        /// 陪伴足迹上传 / 查询，详见 Tools/doc/陪伴足迹接口.md
        static let companionFootprintURL = userServerURL + "/companion_footprint"

        /// 睡眠计划同步（Tools/doc/睡眠计划同步接口.md）
        static let sleepPlanURL = userServerURL + "/sleep_plan"
        static let healthSyncInterval: HealthSyncInterval = .fifteenMinutes
        /// 健康同步窗口：新用户首次拉这么多天；长时间断联回来也最多补这么多天
        /// 与月视图一致：30 天覆盖月图并给 AI 足够上下文
        static let healthSyncInitialWindowHours = 24 * 30
        /// 增量窗口在 lastTs 基础上多拉的缓冲小时数（避免临界点丢数据）
        static let healthSyncIncrementalBufferHours = 2
        /// 每次切片上传的跨度（小时）：按天切片，便于分批上传控制 payload 大小
        static let healthSyncSliceHours = 24
        /// 每种指标单次拉取的样本上限：24h 切片范围内足够高密度采样
        static let healthSyncMaxSamplesPerMetric = 5000

        /// 健康数据的**口径版本**。改动含义（字段增删改名、裁剪口径、聚合方式）时必须 +1。
        /// 客户端发现本地记录的版本落后就清空上传记录，把窗口内历史全部按新口径重传；
        /// 请求里也带上它，服务端据此判断某条数据是哪一版语义，并让新版覆盖旧版。
        ///
        /// v1：初版。heart_rate 为全天序列；HRV/呼吸/体温未裁剪到睡眠期间；
        ///     sleep_stage_light 混入 asleepUnspecified；无 awake / inBed。
        /// v2：全部数据收敛到睡眠口径。heart_rate 移除，改为 sleep_heart_rate_min/max；
        ///     HRV/呼吸/体温裁剪到睡眠期间并加 sleep_ 前缀；拆出 sleep_stage_unspecified；
        ///     新增 sleep_stage_awake、sleep_in_bed。
        static let healthDataSchemaVersion = 2
        /// 连续切片上传之间的间隔（毫秒），避免在短时间内反复冲击服务端
        static let healthSyncSliceIntervalMillis = 1000
        /// 「我还没有设备」/「还没有 Mindora」/ 订阅页 Community 三处对外入口。
        ///
        /// 原值 mindora316.com 至今没有解析到可用服务，点开就是打不开 —— 而启动页那颗
        /// 「我还没有设备」是最显眼的次要按钮，审核员几乎必点，打不开即按链接失效拒绝。
        /// 暂时指向已在运行的网页商城（和商店 Tab 同一个地址）：这三处的意图本来就是
        /// 「去了解/购买设备」，语义对得上。品牌官网建好后再换回来。
        static let mindoraWebURL = "https://csj.mfcool.com/shop"
        /// App 审核演示账号。审核员在境外用自己的设备，收不到我们发出的验证码邮件，
        /// 所以后端对这个邮箱写死了验证码；客户端这边则据此自动构造健康数据，
        /// 否则审核员登进去看到的是空首页，会判定 App 不工作。
        ///
        /// ⚠️ 必须与后端 auth_server.py 的 DEMO_ACCOUNT_EMAIL 完全一致，改动要两边同步。
        static let appReviewDemoEmail = "appreview@mindora316.com"
        static let termsOfUseURL = "https://app.mindora316.com/terms-of-use"
        static let privacyPolicyURL = "https://app.mindora316.com/privacy-policy"
        /// 帮助中心（FAQ 底部「帮助中心」入口）。
        /// 原先指向 help.mindora316.com —— 那个子域至今没有解析到可用服务，点开就是打不开，
        /// 审核员点到即触发「链接失效」类拒绝。app.mindora316.com 的支持页本身就是 FAQ + 联系方式，
        /// 正好是帮助中心该有的内容。
        static let helpCenterURL = "https://app.mindora316.com/"
        /// 商店 Tab 载入的网页商城
        static let shopURL = "https://csj.mfcool.com/shop"
        /// 通用请求超时（auth / profile 等用户交互类）：用户需要同步等待，不宜过长
        static let timeoutInterval: TimeInterval = 15.0
        /// 健康数据后台同步超时：在后台执行，不阻塞用户，给长一点
        static let healthSyncTimeoutInterval: TimeInterval = 120.0
        /// 长耗时请求（如 AI 分析）专用超时：后端 LLM 生成可能较慢，这里给足 10 分钟
        static let analysisTimeoutInterval: TimeInterval = 600.0
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
        /// 注意：跳过后写入的是假 token（RegisterP2Controller 里的 "debug_token"），
        /// 只能进主界面看本地数据，任何需要鉴权的服务端请求都会 401。
        #if DEBUG
        static var skipEmailVerification = false
        #else
        static let skipEmailVerification = false
        #endif

        /// 短路 401 处理：命中 token 失效时**不再**软登出、不切回欢迎页。
        ///
        /// 专门配合 `skipEmailVerification` 用：那条路写的是假 token，一发请求就 401，
        /// 不短路的话会立刻被踢回欢迎页，连「请求有没有发出去」都看不到。
        /// 打开后 App 会留在主界面持续发请求，可以在日志/抓包里观察上行内容 ——
        /// 但服务端**仍然会拒绝**，这个开关不会让上传真的成功。
        #if DEBUG
        static var ignoreSessionExpiration = false
        #else
        static let ignoreSessionExpiration = false
        #endif
    }
    
    struct Strings {
        static let splashTagline = "Personal insights\nto empower your\neveryday."
    }
    
    struct Contact {
        static let supportEmail = "support@mindora316.com"
    }

    struct Storage {
        struct Keychain {
            static let keyVersionSuffix = "_v1"
            static let authToken = "auth_token" + keyVersionSuffix
            static let authExpirationDate = "auth_expiration_date" + keyVersionSuffix
            static let authUID = "auth_uid" + keyVersionSuffix
            static let authEmail = "auth_email" + keyVersionSuffix
        }

        struct UserDefaults {
            static let isLoggedIn = "isLoggedIn"
        }
    }
    
    struct Subscription {
        // 普通会员（Basic）—— 复用原有单一订阅产品 ID，改价为 $4.99/$49.99（睡眠计划分级会员上线）。
        // ⚠️ 需要在 App Store Connect 把这两个已上线产品的价格改为 $4.99/月、$49.99/年。
        static let monthlyPrice = "$4.99"
        static let yearlyPrice = "$49.99"
        static let monthlyProductID = "com.mindora316.monthly"
        static let yearlyProductID = "com.mindora316.yearly"

        // 高级会员（Premium）—— 新增订阅产品，需与上面两个产品加入同一订阅组（App Store Connect
        // Subscription Group），保证升降级走「更换订阅」而不是同时持有两份订阅。
        // ⚠️ 需要在 App Store Connect 新建这两个产品 ID，定价 $6.99/月、$69.99/年。
        static let premiumMonthlyPrice = "$6.99"
        static let premiumYearlyPrice = "$69.99"
        static let premiumMonthlyProductID = "com.mindora316.premium.monthly"
        static let premiumYearlyProductID = "com.mindora316.premium.yearly"
    }
}
