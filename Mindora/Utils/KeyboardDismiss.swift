//
//  KeyboardDismiss.swift
//  mindora
//
//  统一的「点击空白处收起键盘」能力：任何含输入框的页面在 viewDidLoad 调用
//  `installTapToDismissKeyboard()` 即可，避免键盘弹出后无处可点导致收不回。
//

import UIKit

/// 无状态手势代理：点在输入框 / 控件（UIControl / UITextField / UITextView）自身时不触发收起，
/// 交给它们正常聚焦 / 响应；点在空白处才收起键盘。全 App 共用一个实例即可。
final class KeyboardDismissGestureDelegate: NSObject, UIGestureRecognizerDelegate {
    static let shared = KeyboardDismissGestureDelegate()

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var v = touch.view
        while let cur = v {
            if cur is UIControl || cur is UITextView || cur is UITextField { return false }
            v = cur.superview
        }
        return true
    }
}

extension UIViewController {
    /// 在指定视图（默认根视图）加「点击空白处收起键盘」手势。
    /// `cancelsTouchesInView = false` 保证按钮 / 列表 / 选项等原有点击不受影响。
    func installTapToDismissKeyboard(on target: UIView? = nil) {
        guard let host = target ?? viewIfLoaded else { return }
        let tap = UITapGestureRecognizer(target: self, action: #selector(mindora_dismissKeyboardFromTap))
        tap.cancelsTouchesInView = false
        tap.delegate = KeyboardDismissGestureDelegate.shared
        host.addGestureRecognizer(tap)
    }

    @objc private func mindora_dismissKeyboardFromTap() {
        view.endEditing(true)
    }
}
