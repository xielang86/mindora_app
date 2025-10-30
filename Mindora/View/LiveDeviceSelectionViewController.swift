import UIKit

final class LiveDeviceSelectionViewController: UITableViewController {
    private let discovery: BonjourDiscovery
    private let onSelect: (NetService) -> Void
    private var resolvingService: NetService?
    private var activity: UIActivityIndicatorView = {
        let a = UIActivityIndicatorView(style: .large)
        a.hidesWhenStopped = true
        a.translatesAutoresizingMaskIntoConstraints = false
        return a
    }()

    init(discovery: BonjourDiscovery, onSelect: @escaping (NetService) -> Void) {
        self.discovery = discovery
        self.onSelect = onSelect
        super.init(style: .insetGrouped)
        title = "正在扫描附近的 Mindora 设备"
        discovery.delegate = self
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "停止", style: .plain, target: self, action: #selector(stopScan))
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")

        let footer = UILabel()
        footer.text = "如果未发现设备，请确认手机与 Mindora 设备在同一局域网，并确认设备已开启。"
        footer.textAlignment = .center
        footer.textColor = .secondaryLabel
        footer.font = .systemFont(ofSize: 13)
        footer.numberOfLines = 0
        footer.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 64)
        tableView.tableFooterView = footer

        view.addSubview(activity)
        NSLayoutConstraint.activate([
            activity.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activity.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    @objc private func stopScan() {
        discovery.stop()
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "关闭", style: .plain, target: self, action: #selector(close))
    }

    @objc private func close() { dismiss(animated: true) }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { discovery.services.count }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let service = discovery.services[indexPath.row]
        var cfg = cell.defaultContentConfiguration()
        cfg.text = service.name
        cfg.secondaryText = service.type
        cfg.image = UIImage(systemName: "dot.radiowaves.left.and.right")
        cell.contentConfiguration = cfg
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let service = discovery.services[indexPath.row]
        Log.info("DeviceSelect", "tap service name=\(service.name) type=\(service.type) -> resolve")
        resolve(service)
    }
}

extension LiveDeviceSelectionViewController: BonjourDiscoveryDelegate {
    func discoveryDidUpdate(_ discovery: BonjourDiscovery) {
        Log.info("DeviceSelect", "discovery update services=\(discovery.services.count)")
        tableView.reloadData()
    }
}

extension LiveDeviceSelectionViewController: NetServiceDelegate {
    private func resolve(_ service: NetService) {
        // 防抖：避免重复解析
        if resolvingService != nil { return }
        Log.info("DeviceSelect", "resolving service name=\(service.name)")
        resolvingService = service
        activity.startAnimating()
        navigationItem.rightBarButtonItem?.isEnabled = false

        service.delegate = self
        service.resolve(withTimeout: 5.0)
    }

    func netServiceDidResolveAddress(_ sender: NetService) {
        Log.info("DeviceSelect", "resolve success host=\(sender.hostName ?? "nil") name=\(sender.name)")
        activity.stopAnimating()
        navigationItem.rightBarButtonItem?.isEnabled = true
        resolvingService = nil
        onSelect(sender)
    }

    func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber]) {
        let code = errorDict[NetService.errorCode]?.intValue ?? -1
        Log.error("DeviceSelect", "resolve failed code=\(code) err=\(errorDict)")
    }
}
