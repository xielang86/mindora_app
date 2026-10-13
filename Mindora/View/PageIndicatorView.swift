//
//  PageIndicatorView.swift
//  mindora
//
//  设备连接页分页指示器：当前页为白色长条胶囊，其余为灰色圆点。
//  设计稿尺寸：圆点 4pt、当前页胶囊 12×4pt、间距约 5pt。
//

import UIKit

final class PageIndicatorView: UIView {

    private let stack: UIStackView = {
        let s = UIStackView()
        s.axis = .horizontal
        s.alignment = .center
        s.spacing = 5
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private let dotSize: CGFloat = 4
    private let activeWidth: CGFloat = 12

    private let activeColor = UIColor.white
    private let inactiveColor = UIColor(white: 1.0, alpha: 0.3)

    var numberOfPages: Int = 0 { didSet { rebuild() } }
    var currentPage: Int = 0 { didSet { updateStyles() } }

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func rebuild() {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for _ in 0..<max(0, numberOfPages) {
            let dot = UIView()
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.layer.cornerRadius = dotSize / 2
            let w = dot.widthAnchor.constraint(equalToConstant: dotSize)
            w.priority = .defaultHigh
            NSLayoutConstraint.activate([w, dot.heightAnchor.constraint(equalToConstant: dotSize)])
            stack.addArrangedSubview(dot)
        }
        updateStyles()
    }

    private func updateStyles() {
        for (i, dot) in stack.arrangedSubviews.enumerated() {
            // 移除旧的宽度约束
            dot.constraints.filter { $0.firstAttribute == .width }.forEach { dot.removeConstraint($0) }
            let isActive = (i == currentPage)
            dot.backgroundColor = isActive ? activeColor : inactiveColor
            let wc = dot.widthAnchor.constraint(equalToConstant: isActive ? activeWidth : dotSize)
            wc.isActive = true
        }
    }
}
