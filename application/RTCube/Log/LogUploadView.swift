//
//  LogUploadView.swift
//  RTCube
//

import UIKit
import AtomicX
import SnapKit

// MARK: - LogUploadViewDataSource

protocol LogUploadViewDataSource: AnyObject {
    func numberOfComponents(in logUploadView: LogUploadView) -> Int
    func logUploadView(_ logUploadView: LogUploadView, numberOfRowsInComponent component: Int) -> Int
}

// MARK: - LogUploadViewDelegate

@objc protocol LogUploadViewDelegate: AnyObject {
    @objc optional func logUploadView(_ logUploadView: LogUploadView, didSelectRow row: Int, inComponent component: Int)
    @objc optional func logUploadView(_ logUploadView: LogUploadView, titleForRow row: Int, forComponent component: Int) -> String?
}

// MARK: - LogUploadView

class LogUploadView: UIView {

    weak var dataSource: LogUploadViewDataSource?
    weak var delegate: LogUploadViewDelegate?

    var shareHandler: (_ row: Int) -> Void = { _ in }
    var cancelHandler: () -> Void = {}

    // MARK: - Subviews

    private let logPickerView: UIPickerView = {
        let pickView = UIPickerView()
        return pickView
    }()

    private let containerView: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = ThemeStore.shared.colorTokens.bgColorOperate
        return view
    }()

    private let shareButton: UIButton = {
        let button = UIButton(type: .system)
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        button.setTitle(NSLocalizedString("LogUpload.Share", comment: "分享"), for: .normal)
        return button
    }()

    private let shareLogTitle: UILabel = {
        let label = UILabel()
        label.text = NSLocalizedString("LogUpload.ShareLog", comment: "分享日志")
        label.font = .systemFont(ofSize: 14, weight: .medium)
        return label
    }()

    private let cancelButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(NSLocalizedString("LogUpload.Cancel", comment: "取消"), for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        return button
    }()

    private let backButton: UIButton = {
        let button = UIButton(type: .system)
        return button
    }()

    // MARK: - Init

    init() {
        super.init(frame: .zero)
        logPickerView.dataSource = self
        logPickerView.delegate = self
        backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.4)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Layout

    private var isViewReady = false

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else { return }
        isViewReady = true
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
    }

    private func constructViewHierarchy() {
        addSubview(containerView)
        addSubview(backButton)
        containerView.addSubview(cancelButton)
        containerView.addSubview(shareLogTitle)
        containerView.addSubview(shareButton)
        containerView.addSubview(logPickerView)
    }

    private func activateConstraints() {
        let containerHeight = ScreenHeight / 2
        containerView.snp.makeConstraints { make in
            make.height.equalTo(containerHeight)
            make.bottom.left.right.equalToSuperview()
        }
        shareLogTitle.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalTo(cancelButton)
        }
        backButton.snp.makeConstraints { make in
            make.top.left.right.equalToSuperview()
            make.bottom.equalTo(containerView.snp.top)
        }
        logPickerView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(44)
            make.bottom.left.right.equalToSuperview()
        }
        cancelButton.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(16)
            make.bottom.equalTo(logPickerView.snp.top)
            make.top.equalToSuperview()
            make.width.equalTo(60)
        }
        shareButton.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-16)
            make.bottom.equalTo(logPickerView.snp.top)
            make.top.equalToSuperview()
            make.width.equalTo(60)
        }
    }

    private func bindInteraction() {
        shareButton.addTarget(self, action: #selector(shareButtonClicked), for: .touchUpInside)
        cancelButton.addTarget(self, action: #selector(cancelButtonClicked), for: .touchUpInside)
        backButton.addTarget(self, action: #selector(cancelButtonClicked), for: .touchUpInside)
    }

    // MARK: - Public

    func reloadAllComponents() {
        logPickerView.reloadAllComponents()
    }

    func reloadComponent(in row: Int) {
        logPickerView.reloadComponent(row)
    }
}

// MARK: - UIPickerViewDataSource

extension LogUploadView: UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return dataSource?.numberOfComponents(in: self) ?? 0
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return dataSource?.logUploadView(self, numberOfRowsInComponent: component) ?? 0
    }
}

// MARK: - UIPickerViewDelegate

extension LogUploadView: UIPickerViewDelegate {
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        delegate?.logUploadView?(self, didSelectRow: row, inComponent: component)
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return delegate?.logUploadView?(self, titleForRow: row, forComponent: component)
    }

    func pickerView(_ pickerView: UIPickerView,
                    viewForRow row: Int,
                    forComponent component: Int,
                    reusing view: UIView?) -> UIView {
        let label = (view as? UILabel) ?? UILabel()
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 16)
        label.textColor = ThemeStore.shared.colorTokens.textColorPrimary
        label.text = delegate?.logUploadView?(self, titleForRow: row, forComponent: component)
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.6
        return label
    }
}

// MARK: - Actions

extension LogUploadView {
    @objc private func shareButtonClicked() {
        shareHandler(logPickerView.selectedRow(inComponent: 0))
    }

    @objc private func cancelButtonClicked() {
        cancelHandler()
    }
}
