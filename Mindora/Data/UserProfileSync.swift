//
//  UserProfileSync.swift
//  mindora
//
//  个人资料的「拉取 + 合并落地」。
//
//  这段逻辑原先长在 UserProfileViewController 里，只有用户打开资料页才会跑一次。
//  后果有二：
//    1. 登录后不进资料页，本地就一直是空的 —— 侧栏昵称、头像都显示不出来；
//    2. 更要命的是，资料改动改成自动上传之后，本地空表会被当成「用户的资料」传上去，
//       把服务端已有的手机 / 性别 / 生日覆盖成空串。
//  所以抽出来，让登录那一刻就能把服务端资料拉回本地打底。
//
//  地址与头像不在 draft 里（分别存 UserDefaults 与 Documents），一并放在这里，
//  免得两处各写一份、迟早写歪。
//

import Foundation
import UIKit

enum UserProfileSync {

    private static let logTag = "UserProfileSync"
    static let addressStorageKey = "MindoraSavedAddresses"

    /// 本次进程有没有成功拉到过服务端资料（拿到空资料也算成功 —— 那说明服务端确实没有）。
    ///
    /// 自动上传拿它当护栏：没拉成功过就说明「本地是不是完整的」无从判断，
    /// 这时把本地内容传上去可能拿空值覆盖掉服务端已有的资料。
    private(set) static var didLoadRemote = false

    // MARK: - 拉取

    /// 拉服务端资料并合并进本地。登录后与打开资料页都会调。
    /// - Parameter reason: 仅用于日志。
    static func pull(reason: String) {
        guard let token = AuthStorage.shared.token, !token.isEmpty else {
            Log.info(logTag, "pull(\(reason)) 跳过：未登录")
            return
        }
        // 冷启动和打开资料页可能挨着触发，同一份资料没必要拉两遍。
        guard !isPulling else {
            Log.info(logTag, "pull(\(reason)) 跳过：已有拉取在途")
            return
        }
        isPulling = true
        Task {
            do {
                let snapshot = try await UserProfileService.shared.queryProfile()
                await MainActor.run {
                    isPulling = false
                    // 拿到空资料也算拉成功 —— 说明服务端确实没有，本地内容可以放心上传。
                    didLoadRemote = true
                    if let snapshot {
                        apply(snapshot)
                        Log.info(logTag, "pull(\(reason)) 已合并服务端资料")
                    } else {
                        Log.info(logTag, "pull(\(reason)) 服务端无资料")
                    }
                    // 本地这才算完整：之前被护栏挡下的改动（含地址、头像）现在可以送出去了。
                    scheduleAutoUpload(requireBaseline: true)
                }
            } catch {
                await MainActor.run { isPulling = false }
                Log.error(logTag, "pull(\(reason)) 失败：\(error.localizedDescription)")
            }
        }
    }

    private static var isPulling = false

    static func markRemoteLoaded() {
        didLoadRemote = true
    }

    /// 换账号 / 登出后必须复位，否则新账号会沿用上一账号的「已拉过」结论，
    /// 在还没拉到自己的资料时就允许自动上传。
    static func resetRemoteFlag() {
        didLoadRemote = false
    }

    // MARK: - 合并落地

    @MainActor
    static func apply(_ snapshot: UserProfileSnapshot) {
        let local = UserProfileStore.shared.load(accountEmail: AuthStorage.shared.email)
        UserProfileStore.shared.save(merge(local: local, remote: snapshot.draft))

        // 地址与头像只在本地为空时才用服务端的填 —— 本地有就是用户刚编辑过的，不能被覆盖。
        if loadAddresses().isEmpty, !snapshot.addresses.isEmpty {
            saveAddresses(snapshot.addresses.map {
                AddrModel(id: $0.id, isDefault: $0.isDefault, name: $0.name, phone: $0.phone,
                          countryCode: $0.countryCode, stateCode: $0.stateCode, state: $0.state,
                          city: $0.city, district: $0.district, street1: $0.street1,
                          street2: $0.street2, zip: $0.zip,
                          region: $0.region, detail: $0.detail)
            }, syncsToServer: false)
        }
        if loadAvatarData() == nil, let data = snapshot.avatarJPEGData, let image = UIImage(data: data) {
            saveAvatar(image, syncsToServer: false)
        }

        NotificationCenter.default.post(name: .userProfileDidUpdate, object: nil)
    }

    /// 逐字段本地优先：本地非空就用本地，本地空才用服务端的补。
    static func merge(local: UserProfileDraft, remote: UserProfileDraft) -> UserProfileDraft {
        UserProfileDraft(
            nickname: prefer(local.nickname, remote.nickname),
            gender: prefer(local.gender, remote.gender),
            age: prefer(local.age, remote.age),
            birthday: prefer(local.birthday, remote.birthday),
            email: prefer(local.email, remote.email),
            phone: prefer(local.phone, remote.phone),
            address: prefer(local.address, remote.address),
            weight: prefer(local.weight, remote.weight),
            height: prefer(local.height, remote.height)
        )
    }

    private static func prefer(_ current: String, _ fallback: String) -> String {
        let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback.trimmingCharacters(in: .whitespacesAndNewlines) : trimmed
    }

    // MARK: - 地址

    static func loadAddresses() -> [AddrModel] {
        guard let data = UserDefaults.standard.data(forKey: addressStorageKey),
              let list = try? JSONDecoder().decode([AddrModel].self, from: data) else { return [] }
        return list
    }

    /// 地址簿的唯一写入口。
    ///
    /// - Parameter syncsToServer: 用户改的地址传 true（默认），改完立刻排一次上传；
    ///   只有 `apply` 从服务端回填时传 false —— 那份内容本来就是服务端的，再传回去纯属多余。
    static func saveAddresses(_ addresses: [AddrModel], syncsToServer: Bool = true) {
        guard let data = try? JSONEncoder().encode(addresses) else { return }
        UserDefaults.standard.set(data, forKey: addressStorageKey)
        NotificationCenter.default.post(name: .userProfileDidUpdate, object: nil)
        if syncsToServer { scheduleAutoUpload() }
    }

    /// 地址簿的原始字节，用来算摘要（顺序与字段完全一致才算没变）。
    static func addressStorageData() -> Data? {
        UserDefaults.standard.data(forKey: addressStorageKey)
    }

    // MARK: - 头像

    static var avatarURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("user_avatar.jpg")
    }

    static func loadAvatarData() -> Data? {
        guard let url = avatarURL else { return nil }
        return try? Data(contentsOf: url)
    }

    /// - Parameter syncsToServer: 同 `saveAddresses`，服务端回填时传 false。
    static func saveAvatar(_ image: UIImage, syncsToServer: Bool = true) {
        guard let url = avatarURL, let data = image.jpegData(compressionQuality: 0.8) else { return }
        try? data.write(to: url)
        NotificationCenter.default.post(name: NSNotification.Name("UserProfileAvatarUpdated"), object: nil)
        if syncsToServer { scheduleAutoUpload() }
    }

    // MARK: - 自动上传

    /// 改完就传，不用等用户点「更新资料」（那个按钮已按设计稿去掉）。
    ///
    /// 这段原先长在 UserProfileViewController 里，于是「上传」只有资料页那一条路径：
    /// 地址在独立页面改、问卷领奖也会写地址簿，这些改动都要等用户下次打开资料页才补传。
    /// 挪到这里之后，任何一处写入（资料字段 / 地址 / 头像）都在写入那一刻排上传。
    private static let autoUploadDebounce: TimeInterval = 1.0
    private static var autoUploadWorkItem: DispatchWorkItem?

    static func currentAvatarDigest() -> String {
        UserProfileStore.digest(loadAvatarData())
    }

    static func currentAddressDigest() -> String {
        UserProfileStore.digest(addressStorageData())
    }

    /// 当前本地内容与「最近一次成功上传的」是否一致。一致就什么都不用做。
    static func hasUnsyncedChanges() -> Bool {
        let draft = UserProfileStore.shared.load(accountEmail: AuthStorage.shared.email)
        guard let uploaded = UserProfileStore.shared.loadUploadedSnapshot() else {
            // 从没成功传过：只要不是一张空表就算有改动，免得刚登录的空资料也去传一次。
            return draft != UserProfileDraft.empty
                || !currentAvatarDigest().isEmpty
                || !loadAddresses().isEmpty
        }
        return draft != uploaded
            || currentAvatarDigest() != UserProfileStore.shared.uploadedAvatarDigest
            || currentAddressDigest() != UserProfileStore.shared.uploadedAddressDigest
    }

    /// - Parameter requireBaseline: 用于「进页面重试」这类没有明确用户意图的路径。
    ///   本次进程既没拉到过服务端资料、本地又没有上传基准时，无法区分
    ///   「用户改了没传上去」和「本地是旧数据、服务端才是新的」，后者上传会拿旧值覆盖服务端。
    ///   用户明确改了某项则传 false，那是毫无歧义的意图。
    static func scheduleAutoUpload(requireBaseline: Bool = false) {
        autoUploadWorkItem?.cancel()
        if requireBaseline, !didLoadRemote, UserProfileStore.shared.loadUploadedSnapshot() == nil { return }
        guard hasUnsyncedChanges() else { return }
        let item = DispatchWorkItem { performAutoUpload() }
        autoUploadWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + autoUploadDebounce, execute: item)
    }

    private static func performAutoUpload() {
        guard let token = AuthStorage.shared.token, !token.isEmpty else {
            // 未登录就先攒着。登录后与下次进资料页都会再判一次，不会丢改动。
            Log.info(logTag, "自动上传跳过：未登录，改动留在本地")
            return
        }
        // 护栏：本次进程还没成功拉过服务端资料，就不知道本地这份是不是完整的。
        // 这时上传等于拿一份可能残缺的本地数据去覆盖服务端 —— 登出重登后本地被清空，
        // 若拉取又恰好失败，一次改昵称就能把服务端的手机/性别/生日全抹成空串。
        // 有上传基准（说明这台机器成功传过、本地是权威的）则不受此限。
        guard didLoadRemote || UserProfileStore.shared.loadUploadedSnapshot() != nil else {
            Log.info(logTag, "自动上传推迟：尚未拉到服务端资料，避免用残缺数据覆盖")
            return
        }
        guard hasUnsyncedChanges() else { return }

        let draft = UserProfileStore.shared.load(accountEmail: AuthStorage.shared.email)
        let avatarDigest = currentAvatarDigest()
        let addressDigest = currentAddressDigest()
        // 头像只在真的换过时才带上：一张 JPEG 的 base64 有几百 KB，
        // 每改一次昵称都捎带一份纯属浪费，协议里也允许不传就是不改。
        let avatarData = avatarDigest == UserProfileStore.shared.uploadedAvatarDigest ? nil : loadAvatarData()
        Log.info(logTag, "自动上传资料改动 avatar=\(avatarData != nil)")

        Task {
            do {
                let updated = try await UserProfileService.shared.updateProfile(
                    draft: draft,
                    baseline: UserProfileStore.shared.loadUploadedSnapshot(),
                    avatarJPEGData: avatarData)
                await MainActor.run {
                    UserProfileStore.shared.save(updated)
                    UserProfileStore.shared.saveUploadedSnapshot(updated,
                                                                 avatarDigest: avatarDigest,
                                                                 addressDigest: addressDigest)
                    NotificationCenter.default.post(name: .userProfileDidUpdate, object: nil)
                }
            } catch {
                // 不弹错误提示：这是后台行为，用户没有主动发起，弹窗只会让人莫名其妙。
                // 快照没更新，改动仍是脏的，下次改动或下次进页面会自动重试。
                Log.error(logTag, "自动上传失败：\(error.localizedDescription)，改动保留待重试")
            }
        }
    }
}
