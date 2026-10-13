//
//  SleepPlanTierGuardTests.swift
//  mindoraTests
//
//  盯住「已是高级会员却被拦、之前建的计划还消失」那个线上问题。
//
//  复现条件是本地 StoreKit 有 premium 凭证、服务端却仍是 free（订阅只在
//  App 与 Apple 之间发生，report_subscription 没落库、ASSN 也没接）。服务端按
//  free 算额度下发一份「少了用户计划」的全量，客户端照单全收就把计划删了。
//
//  这几条测的就是那条删除路径：allowDrops=false 时一条都不许删，且不许留下
//  缓刑记账——否则服务端恢复正常那一轮会直接凑满「连续两次」把计划删掉。
//

import Testing
import Foundation
@testable import Mindora

@MainActor
struct SleepPlanTierGuardTests {

    /// 造一条已同步干净（不脏）的本地计划，模拟「用户之前建好、已经躺在列表里」的那条。
    private func makeSyncedPlan(name: String) -> SleepPlan {
        let saved = SleepPlanStore.shared.save(
            SleepPlan(kind: .custom, customName: name,
                      targetMinutes: 480, sleepTime: 22 * 60, wakeTime: 6 * 60,
                      cycle: .weekdays(days: [1, 2, 3], repeatsWeekly: true))
        )
        // save 会标脏；标记成已同步，才能走到 applyServerPlans 里的「服务端在删我们的东西」分支
        SleepPlanStore.shared.markSynced(ids: [saved.id])
        return saved
    }

    /// 服务端说 free、本地是 premium 时，服务端下发的空全量**不能**删掉本地计划。
    /// 这是用户那句「之前建的计划看不到了」的直接成因。
    @Test func 服务端等级偏低时不删本地计划() async throws {
        SleepPlanStore.shared.clear()
        let plan = makeSyncedPlan(name: "计划A")

        // 服务端按 free 算额度，下发的全量里一条都没有
        SleepPlanStore.shared.applyServerPlans([], allowDrops: false)
        #expect(SleepPlanStore.shared.all.contains { $0.id == plan.id },
                "服务端等级不可信时下发空全量，本地计划必须原地不动")

        // 再来一轮同样的响应。原有的「连续两轮确认才删」在这条路径上根本不该起算，
        // 否则用户进两次 Tab 计划就没了。
        SleepPlanStore.shared.applyServerPlans([], allowDrops: false)
        #expect(SleepPlanStore.shared.all.contains { $0.id == plan.id },
                "连续两轮都判定服务端不可信，本地计划仍不能被删")

        SleepPlanStore.shared.clear()
    }

    /// 不许留下缓刑记账：这一轮判定不可信、下一轮服务端恢复正常（allowDrops=true），
    /// 不能因为上一轮攒了一次记账就直接凑满两次把计划删了。
    @Test func 不可信的那一轮不留缓刑记账() async throws {
        SleepPlanStore.shared.clear()
        let plan = makeSyncedPlan(name: "计划B")

        SleepPlanStore.shared.applyServerPlans([], allowDrops: false)
        // 服务端恢复正常，但这条计划它确实还没有 —— 这才是这条计划的「第一次」缺失
        SleepPlanStore.shared.applyServerPlans([], allowDrops: true)
        #expect(SleepPlanStore.shared.all.contains { $0.id == plan.id },
                "恢复正常后的第一轮只该记账，不该删")

        SleepPlanStore.shared.clear()
    }

    /// 反向保护：allowDrops=true 时原有行为不能被改坏 —— 别的设备上删掉的计划，
    /// 连续两轮确认后仍然要删，并且删之前存档。
    @Test func 正常路径下连续两轮仍然删除并存档() async throws {
        SleepPlanStore.shared.clear()
        let plan = makeSyncedPlan(name: "计划C")

        SleepPlanStore.shared.applyServerPlans([], allowDrops: true)
        #expect(SleepPlanStore.shared.all.contains { $0.id == plan.id }, "第一轮只记账不删")

        SleepPlanStore.shared.applyServerPlans([], allowDrops: true)
        #expect(!SleepPlanStore.shared.all.contains { $0.id == plan.id }, "第二轮确认后删除")
        #expect(SleepPlanStore.shared.archivedPlans().contains { $0.id == plan.id },
                "删除前必须存档，否则服务端一出错用户的计划就找不回来了")

        SleepPlanStore.shared.clear()
    }

    /// 被误删的计划能从存档里捞回来（服务端等级偏低时同步层会调这个）。
    @Test func 存档可恢复被误删的计划() async throws {
        SleepPlanStore.shared.clear()
        let plan = makeSyncedPlan(name: "计划D")

        SleepPlanStore.shared.applyServerPlans([], allowDrops: true)
        SleepPlanStore.shared.applyServerPlans([], allowDrops: true)
        #expect(!SleepPlanStore.shared.all.contains { $0.id == plan.id })

        let restored = SleepPlanStore.shared.restoreArchivedPlans()
        #expect(restored == 1)
        #expect(SleepPlanStore.shared.all.contains { $0.id == plan.id }, "恢复后计划要重新出现在列表里")

        SleepPlanStore.shared.clear()
    }

    /// 本地会员等级决定能建几条：premium 5 条。服务端说 free 也不该改变这个上限，
    /// 「新建计划」走的是这张表，不是服务端的 quota。
    @Test func 本地额度表按等级给到5条() async throws {
        #expect(SleepPlanQuota.slots(for: .free) == 0)
        #expect(SleepPlanQuota.slots(for: .basic) == 1)
        #expect(SleepPlanQuota.slots(for: .premium) == 5)
    }
}
