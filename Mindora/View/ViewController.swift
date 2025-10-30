//
//  ViewController.swift
//  mindora
//
//  Created by gao chao on 2025/9/18.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // 启动页：黑底 + 中央 "MINDORA" 文案
        view.backgroundColor = .black

        let titleLabel = UILabel()
        titleLabel.text = "MINDORA"
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 34, weight: .heavy)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // 短暂展示后进入连接页面
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self else { return }
            let connectVC = ConnectViewController()
            self.navigationController?.setNavigationBarHidden(true, animated: false)
            self.navigationController?.pushViewController(connectVC, animated: true)
        }
    }

}

