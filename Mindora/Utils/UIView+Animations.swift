//
//  UIView+Animations.swift
//  mindora
//
//  Created by GitHub Copilot.
//

import UIKit

extension UIView {
    /// 执行点击缩放动画
    func animateButtonTap(completion: (() -> Void)? = nil) {
        UIView.animate(withDuration: 0.1,
                       delay: 0,
                       options: [.curveEaseOut],
                       animations: {
            self.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
        }) { _ in
            UIView.animate(withDuration: 0.1,
                           delay: 0,
                           options: [.curveEaseOut],
                           animations: {
                self.transform = .identity
            }) { _ in
                completion?()
            }
        }
    }
}
