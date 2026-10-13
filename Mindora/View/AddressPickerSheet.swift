//
//  AddressPickerSheet.swift
//  mindora
//
//  国家 / 州省选择器。国家有 245 个，滚轮翻不动，所以做成带搜索的列表。
//

import UIKit

final class AddressPickerSheet: FootprintBottomSheet, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate {

    struct Item {
        let code: String
        let name: String
    }

    private var allItems: [Item] = []
    private var visibleItems: [Item] = []
    private var selectedCode: String = ""
    private var onSelect: ((Item) -> Void)?

    private let tableView = UITableView()
    private let searchBar = UISearchBar()

    static func present(title: String,
                        items: [Item],
                        selectedCode: String,
                        onSelect: @escaping (Item) -> Void) {
        let sheet = AddressPickerSheet(frame: .zero)
        sheet.allItems = items
        sheet.visibleItems = items
        sheet.selectedCode = selectedCode
        sheet.onSelect = onSelect
        sheet.build(title: title)
        sheet.presentInWindow()
    }

    private func build(title: String) {
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont(name: "PingFangSC-Semibold", size: 16) ?? .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        sheet.addSubview(titleLabel)

        let closeButton = UIButton(type: .system)
        closeButton.setTitle(L("common.cancel"), for: .normal)
        closeButton.setTitleColor(UIColor(white: 1, alpha: 0.6), for: .normal)
        closeButton.titleLabel?.font = UIFont(name: "PingFangSC-Regular", size: 14) ?? .systemFont(ofSize: 14)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(handleClose), for: .touchUpInside)
        sheet.addSubview(closeButton)

        searchBar.delegate = self
        searchBar.placeholder = L("address.picker_search")
        searchBar.searchBarStyle = .minimal
        searchBar.tintColor = .white
        searchBar.searchTextField.textColor = .white
        searchBar.searchTextField.backgroundColor = UIColor(white: 1, alpha: 0.08)
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        sheet.addSubview(searchBar)

        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.keyboardDismissMode = .onDrag
        tableView.rowHeight = 48
        tableView.translatesAutoresizingMaskIntoConstraints = false
        sheet.addSubview(tableView)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: sheet.topAnchor, constant: 22),
            titleLabel.leadingAnchor.constraint(equalTo: sheet.leadingAnchor, constant: 22),
            closeButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            closeButton.trailingAnchor.constraint(equalTo: sheet.trailingAnchor, constant: -20),

            searchBar.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            searchBar.leadingAnchor.constraint(equalTo: sheet.leadingAnchor, constant: 14),
            searchBar.trailingAnchor.constraint(equalTo: sheet.trailingAnchor, constant: -14),

            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 6),
            tableView.leadingAnchor.constraint(equalTo: sheet.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: sheet.trailingAnchor),
            // 高度固定成屏幕的一半多一点：列表长度差别很大（美国 59 个州 vs 加拿大 13 个），
            // 让弹层高度跟着内容跳来跳去反而难用。
            tableView.heightAnchor.constraint(equalToConstant: UIScreen.main.bounds.height * 0.5),
            tableView.bottomAnchor.constraint(equalTo: sheet.safeAreaLayoutGuide.bottomAnchor, constant: -10)
        ])
    }

    @objc private func handleClose() {
        dismissSheet()
    }

    // MARK: - Search

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        let keyword = searchText.trimmingCharacters(in: .whitespaces)
        if keyword.isEmpty {
            visibleItems = allItems
        } else {
            visibleItems = allItems.filter {
                $0.name.localizedCaseInsensitiveContains(keyword) || $0.code.localizedCaseInsensitiveContains(keyword)
            }
        }
        tableView.reloadData()
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }

    // MARK: - Table

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return visibleItems.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell") ?? UITableViewCell(style: .default, reuseIdentifier: "cell")
        let item = visibleItems[indexPath.row]
        cell.backgroundColor = .clear
        cell.textLabel?.text = item.name
        cell.textLabel?.textColor = .white
        cell.textLabel?.font = UIFont(name: "PingFangSC-Regular", size: 16) ?? .systemFont(ofSize: 16)
        cell.accessoryType = item.code == selectedCode ? .checkmark : .none
        cell.tintColor = UIColor(red: 172/255, green: 143/255, blue: 255/255, alpha: 1)
        let selected = UIView()
        selected.backgroundColor = UIColor(white: 1, alpha: 0.06)
        cell.selectedBackgroundView = selected
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item = visibleItems[indexPath.row]
        endEditing(true)
        dismissSheet { [weak self] in
            self?.onSelect?(item)
        }
    }
}
