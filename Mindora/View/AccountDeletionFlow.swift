//
//  AccountDeletionFlow.swift
//  mindora
//
//  账号删除的完整两段式流程（危险确认 → 发验证码 → 输入验证码 → 真正删除）。
//  从 UserProfileViewController 抽出，供个人资料页和邮箱页共用同一套逻辑与文案。
//

import UIKit

final class AccountDeletionFlow {
    private weak var presenter: UIViewController?
    private weak var actionButton: UIControl?

    init(presenter: UIViewController, actionButton: UIControl? = nil) {
        self.presenter = presenter
        self.actionButton = actionButton
    }

    // 第一步：危险确认（App 自定义弹窗）。确认后向后端请求发送注销验证码（阶段 1）。
    func start() {
        guard let presenter else { return }
        let alert = CustomAlertViewController(
            title: L("user_profile.delete_confirm_title"),
            description: deleteConfirmMessage(),
            confirmButtonTitle: L("user_profile.delete_confirm_send"),
            cancelButtonTitle: L("user_profile.cancel"),
            onConfirm: { [weak self] in self?.sendDeleteVerifyCode() }
        )
        presenter.present(alert, animated: true)
    }

    /// 根据绑定联系方式（邮箱/手机，已脱敏）给出更智能的确认文案，无法识别时用通用文案。
    private func deleteConfirmMessage() -> String {
        guard let c = AccountContact.current() else {
            return L("user_profile.delete_confirm_message")
        }
        switch c.kind {
        case .email: return String(format: L("user_profile.delete_confirm_message_email"), c.masked)
        case .phone: return String(format: L("user_profile.delete_confirm_message_phone"), c.masked)
        }
    }

    /// 输入验证码弹窗的智能文案（邮箱/手机，已脱敏）。
    private func deletePromptMessage() -> String {
        guard let c = AccountContact.current() else {
            return L("user_profile.delete_code_prompt_message")
        }
        switch c.kind {
        case .email: return String(format: L("user_profile.delete_code_prompt_message_email"), c.masked)
        case .phone: return String(format: L("user_profile.delete_code_prompt_message_phone"), c.masked)
        }
    }

    // 阶段 1：发送验证码，成功后弹出验证码输入框。
    private func sendDeleteVerifyCode() {
        guard let presenter else { return }
        actionButton?.isEnabled = false
        Task { @MainActor in
            defer { self.actionButton?.isEnabled = true }
            do {
                try await DeleteAccountService.shared.sendDeleteVerifyCode()
                if let window = presenter.view.window {
                    Toast.show(L("user_profile.delete_code_sent"), in: window)
                }
                self.promptForVerifyCode()
            } catch {
                self.showDeleteError(error)
            }
        }
    }

    // 第二步：输入收到的验证码（App 自定义弹窗，带输入框）。
    private func promptForVerifyCode() {
        guard let presenter else { return }
        let alert = DeleteVerifyCodeAlertViewController(
            title: L("user_profile.delete_code_prompt_title"),
            description: deletePromptMessage(),
            placeholder: L("user_profile.delete_code_placeholder"),
            confirmButtonTitle: L("user_profile.delete_submit"),
            cancelButtonTitle: L("user_profile.cancel"),
            onConfirm: { [weak self] code in self?.deleteAccountWithCode(code) }
        )
        presenter.present(alert, animated: true)
    }

    // 阶段 2：携带验证码真正注销账号。
    private func deleteAccountWithCode(_ code: String) {
        guard let presenter else { return }
        guard !code.isEmpty else {
            if let window = presenter.view.window {
                Toast.show(L("user_profile.delete_code_empty"), in: window)
            }
            promptForVerifyCode()
            return
        }
        actionButton?.isEnabled = false
        Task { @MainActor in
            defer { self.actionButton?.isEnabled = true }
            do {
                try await DeleteAccountService.shared.deleteUserWithCode(code)
                // 服务端确认删除后，本地做与退出登录相同的彻底清理，并回到登录页。
                SessionResetter.reset(.deleteAccount)
                if let window = presenter.view.window {
                    Toast.show(L("user_profile.delete_success"), in: window)
                }
                self.navigateToLogin()
            } catch {
                self.showDeleteError(error)
            }
        }
    }

    @MainActor
    private func showDeleteError(_ error: Error) {
        let msg: String
        if case DeleteAccountService.DeleteAccountError.message(let m) = error { msg = m }
        else { msg = L("user_profile.delete_failed") }
        let win = presenter?.view.window ?? UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }.flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })
        if let win { Toast.show(msg, in: win) }
    }

    private func navigateToLogin() {
        let loginVC = StartViewController()
        let nav = UINavigationController(rootViewController: loginVC)
        nav.setNavigationBarHidden(true, animated: false)
        let keyWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })
        if let window = presenter?.view.window ?? keyWindow {
            UIView.transition(with: window, duration: 0.4, options: .transitionCrossDissolve, animations: {
                window.rootViewController = nav
            }, completion: nil)
        }
    }
}
