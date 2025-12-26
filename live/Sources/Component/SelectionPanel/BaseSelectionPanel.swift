//
//  BaseSelectionPanel.swift
//  TUILiveKit
//
//  Created by gg on 2025/11/4.
//

import UIKit
import AtomicX

class BaseSelectionPanel: UIView {
    var selectedClosure: ((Int) -> Void)?
    var cancelClosure: (() -> Void)?

    init(dataSource: [String], selectedClosure: ((Int) -> Void)? = nil, cancelClosure: (() -> Void)? = nil) {
        self.dataSource = dataSource
        self.selectedClosure = selectedClosure
        self.cancelClosure = cancelClosure
        super.init(frame: .zero)
    }

    func bindCell() {
        tableView.register(SelectionPanelCell.self, forCellReuseIdentifier: SelectionPanelCell.cellID)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var dataSource: [String]
    private let kCellRowHeight: CGFloat = 56
    private var isViewReady = false

    private lazy var tableView: UITableView = {
        let view = UITableView(frame: .zero, style: .plain)
        view.dataSource = self
        view.delegate = self
        view.backgroundColor = .clear
        view.sectionFooterHeight = 0
        view.sectionHeaderHeight = 0
        view.showsVerticalScrollIndicator = false
        view.isScrollEnabled = false
        return view
    }()

    private lazy var lineView: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = .bgEntrycardColor
        return view
    }()

    private lazy var cancelButton: UIButton = {
        let button = UIButton(type: .custom)
        button.titleLabel?.font = .customFont(ofSize: 16)
        button.setTitle(.cancelText, for: .normal)
        return button
    }()

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else { return }
        isViewReady = true

        backgroundColor = .bgOperateColor
        layer.cornerRadius = 16
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
    }
}

extension BaseSelectionPanel {
    private func constructViewHierarchy() {
        addSubview(tableView)
        addSubview(lineView)
        addSubview(cancelButton)
    }

    private func activateConstraints() {
        let tableViewHeight = CGFloat(dataSource.count) * kCellRowHeight
        tableView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.height.equalTo(tableViewHeight)
            make.leading.trailing.equalToSuperview()
        }
        lineView.snp.makeConstraints { make in
            make.height.equalTo(7)
            make.top.equalTo(tableView.snp.bottom)
            make.leading.trailing.equalToSuperview()
        }
        cancelButton.snp.makeConstraints { make in
            make.top.equalTo(lineView.snp.bottom).offset(20)
            make.bottom.equalToSuperview().offset(-20)
            make.leading.trailing.equalToSuperview()
        }
    }

    private func bindInteraction() {
        cancelButton.addTarget(self, action: #selector(cancelAction), for: .touchUpInside)
        bindCell()
    }

    @objc private func cancelAction() {
        cancelClosure?()
    }
}

extension BaseSelectionPanel: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        dataSource.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: SelectionPanelCell.cellID, for: indexPath)
        let title = dataSource[indexPath.row]
        if let cell = cell as? SelectionPanelCell {
            cell.contentLabel.text = title
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedClosure?(indexPath.row)
    }
}

class SelectionPanelCell: UITableViewCell {
    static let cellID = "kSelectionPanelCellID"

    lazy var contentLabel: AtomicLabel = {
        let label = AtomicLabel("") { theme in
            LabelAppearance(textColor: theme.color.textColorPrimary,
                            font: theme.typography.Regular16)
        }
        return label
    }()

    private var isViewReady = false
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else { return }
        isViewReady = true

        backgroundColor = .clear
        selectionStyle = .none
        contentView.addSubview(contentLabel)
        contentLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }
}

private extension String {
    static let cancelText: String = internalLocalized("Cancel")
}
