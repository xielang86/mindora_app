import UIKit

final class DeviceSelectionViewController: UITableViewController {
    private let devices: [String]
    private let onSelect: (String) -> Void

    init(devices: [String], onSelect: @escaping (String) -> Void) {
        self.devices = devices
        self.onSelect = onSelect
        super.init(style: .insetGrouped)
        title = L("device_selection.title")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "关闭", style: .plain, target: self, action: #selector(close))
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")

        let footer = UILabel()
        footer.text = "*请确认蓝牙保持开启状态"
        footer.textAlignment = .center
        footer.textColor = .secondaryLabel
        footer.font = .systemFont(ofSize: 13)
        footer.numberOfLines = 0
        footer.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 44)
        tableView.tableFooterView = footer
    }

    @objc private func close() { dismiss(animated: true) }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { devices.count }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var cfg = cell.defaultContentConfiguration()
        cfg.text = devices[indexPath.row]
        cfg.image = UIImage(systemName: "dot.radiowaves.left.and.right")
        cell.contentConfiguration = cfg
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        onSelect(devices[indexPath.row])
    }
}
