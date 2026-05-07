//
//  ReportViewController.swift
//  privacy
//
//    - TRTCReportLocalize → PrivacyLocalize
//    - import RTCCommon（UIColor(hex:)、roundedRect、kDeviceSafeBottomHeight）
//

import Foundation
import UIKit
import RTCCommon
import SnapKit

enum ReportType: String {
    case none, politics, porn, attacks, violence, ad, scam, illegal, other

    var title: String {
        switch self {
        case .politics:
            return PrivacyLocalize("Privacy.Report.type.politics")
        case .porn:
            return PrivacyLocalize("Privacy.Report.type.porn")
        case .attacks:
            return PrivacyLocalize("Privacy.Report.type.personalAttacks")
        case .violence:
            return PrivacyLocalize("Privacy.Report.type.violence")
        case .ad:
            return PrivacyLocalize("Privacy.Report.type.ad")
        case .scam:
            return PrivacyLocalize("Privacy.Report.type.scam")
        case .illegal:
            return PrivacyLocalize("Privacy.Report.type.illegal")
        case .other:
            return PrivacyLocalize("Privacy.Report.type.other")
        default:
            return rawValue
        }
    }
}

extension UIViewController {
    @objc
    dynamic func showReportAlert(roomId: String, ownerId: String = "") {
        let alert = ReportViewController(roomId: roomId, ownerId: ownerId)
        present(alert, animated: true)
    }
}

extension UIView {
    @objc
    dynamic func showReportAlert(roomId: String, ownerId: String = "") {
        var currentController: UIViewController?
        var nextResponder = next
        while nextResponder != nil {
            nextResponder = nextResponder?.next
            if let vc = nextResponder as? UIViewController {
                currentController = vc
                break
            }
        }
        let alert = ReportViewController(roomId: roomId, ownerId: ownerId)
        currentController?.present(alert, animated: true)
    }
}

// MARK: - ReportViewController

class ReportViewController: UIViewController {

    convenience init(roomId: String, ownerId: String) {
        self.init()
        self.targetRoomId = roomId
        self.targetUserId = ownerId
    }

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        self.modalPresentationStyle = .custom
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    private var targetRoomId: String = ""
    private var targetUserId: String = ""

    // MARK: - UI Components

    private lazy var contentView: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = .white
        return view
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.text = PrivacyLocalize("Privacy.Report.title")
        label.font = UIFont.systemFont(ofSize: 24, weight: .medium)
        label.textColor = .black
        return label
    }()

    private lazy var submitBtn: UIButton = {
        let btn = UIButton(frame: .zero)
        btn.setTitle(PrivacyLocalize("Privacy.Report.submit"), for: .normal)
        btn.setTitleColor(UIColor(hex: "006EFF"), for: .normal)
        btn.setTitleColor(UIColor(hex: "AACFFF"), for: .disabled)
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        btn.isEnabled = false
        return btn
    }()

    private lazy var reportTypeView: ReportTypeView = {
        let view = ReportTypeView(types: reportTypes)
        return view
    }()

    private lazy var reportDescriptionView: ReportDescView = {
        let view = ReportDescView(frame: .zero)
        return view
    }()

    private lazy var reportTypes: [ReportType] = {
        return [.politics, .porn, .attacks, .violence, .ad, .scam, .illegal, .other]
    }()

    private lazy var loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.hidesWhenStopped = true
        return indicator
    }()

    private var currentSelectType: ReportType {
        return reportTypeView.currentSelectType
    }

    private var currentDescription: String {
        return reportDescriptionView.textView.text
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.25)
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let roundingCorners: UIRectCorner = [.topLeft, .topRight]
        let cornerRadii = CGSize(width: 20, height: 20)
        contentView.roundedRect(rect: contentView.bounds, byRoundingCorners: roundingCorners, cornerRadii: cornerRadii)
    }
}

// MARK: - UI Layout & Event

extension ReportViewController {

    private func constructViewHierarchy() {
        view.addSubview(contentView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(submitBtn)
        contentView.addSubview(reportTypeView)
        contentView.addSubview(reportDescriptionView)
        contentView.addSubview(loadingIndicator)
    }

    private func activateConstraints() {
        contentView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
        }
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(32)
            make.leading.equalTo(20)
            make.height.equalTo(36)
        }
        submitBtn.snp.makeConstraints { make in
            make.trailing.equalTo(-20)
            make.centerY.equalTo(titleLabel)
            make.height.equalTo(28)
        }
        reportTypeView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(titleLabel.snp.bottom).offset(20)
        }
        reportDescriptionView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(reportTypeView.snp.bottom).offset(20)
            make.bottom.equalTo(-(24 + kDeviceSafeBottomHeight))
        }
        loadingIndicator.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }

    private func bindInteraction() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapDismiss))
        tap.delegate = self
        view.isUserInteractionEnabled = true
        view.addGestureRecognizer(tap)
        submitBtn.addTarget(self, action: #selector(submitAction), for: .touchUpInside)

        reportTypeView.selectTypeBlock = { [weak self] _ in
            guard let self else { return }
            self.submitBtn.isEnabled = true
        }
    }

    @objc
    private func tapDismiss() {
        view.endEditing(true)
        dismiss(animated: true)
    }

    @objc
    private func submitAction() {
        loadingIndicator.startAnimating()
        submitBtn.isEnabled = false

        ReportNetworkService.reportRoom(
            targetRoomId: targetRoomId,
            ownerId: targetUserId,
            reason: currentSelectType.title,
            description: currentDescription
        ) { [weak self] in
            guard let self else { return }
            self.loadingIndicator.stopAnimating()
            self.showToast(PrivacyLocalize("Privacy.Report.submitSuccess")) { [weak self] in
                guard let self else { return }
                self.tapDismiss()
            }
        } failed: { [weak self] _, errorMessage in
            guard let self else { return }
            self.loadingIndicator.stopAnimating()
            self.submitBtn.isEnabled = true
            self.showToast(errorMessage)
        }
    }

    // MARK: - Toast

    private func showToast(_ message: String, completion: (() -> Void)? = nil) {
        let toastLabel = UILabel()
        toastLabel.text = message
        toastLabel.textColor = .white
        toastLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        toastLabel.font = UIFont.systemFont(ofSize: 14)
        toastLabel.textAlignment = .center
        toastLabel.numberOfLines = 0
        toastLabel.layer.cornerRadius = 8
        toastLabel.clipsToBounds = true

        let maxWidth = contentView.bounds.width - 80
        let size = toastLabel.sizeThatFits(CGSize(width: maxWidth, height: .greatestFiniteMagnitude))
        toastLabel.frame = CGRect(x: 0, y: 0, width: size.width + 32, height: size.height + 16)
        toastLabel.center = contentView.center
        contentView.addSubview(toastLabel)

        UIView.animate(withDuration: 0.3, delay: 1.0, options: .curveEaseOut) {
            toastLabel.alpha = 0
        } completion: { _ in
            toastLabel.removeFromSuperview()
            completion?()
        }
    }
}

// MARK: - UIGestureRecognizerDelegate

extension ReportViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard touch.location(in: contentView).y >= 0 else {
            return true
        }
        contentView.endEditing(true)
        return false
    }
}
