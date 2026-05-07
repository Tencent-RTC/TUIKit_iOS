//
//  ContactUsService.swift
//  main
//

import UIKit
import SafariServices
import SnapKit
import TUICore

// MARK: - ContactUsService

class ContactUsService: NSObject, TUIServiceProtocol {

    static let shared = ContactUsService()
    private override init() {}

    static func registerService() {
        TUICore.registerService(TUICore_ContactUsService, object: ContactUsService.shared)
    }

    // MARK: - Entrance Button

    private lazy var contactEntranceView: ContactUsButtonView = {
        let view = ContactUsButtonView(frame: .zero)
        view.isHidden = true
        view.contactBtnClickClosure = { [weak self] in
            self?.goToContactUs()
        }
        return view
    }()

    private var isViewAdded = false

    private func ensureViewAdded() {
        guard !isViewAdded else { return }
        guard let window = Self.getCurrentWindow() else { return }
        window.clipsToBounds = false
        window.addSubview(contactEntranceView)
        contactEntranceView.snp.makeConstraints { make in
            make.trailing.equalToSuperview()
            make.bottom.equalToSuperview().offset(-(61 + kDeviceSafeBottomHeight))
        }
        isViewAdded = true
    }

    // MARK: - TUIServiceProtocol

    func onCall(_ method: String, param: [AnyHashable: Any]?) -> Any? {
        ensureViewAdded()
        if method == TUICore_ContactService_ShowContactEntrance {
            showContactEntrance()
            return true
        }
        if method == TUICore_ContactService_HideContactEntrance {
            hideContactEntrance()
            return true
        }
        if method == TUICore_ContactService_gotoContactUS {
            goToContactUs()
            return true
        }
        return false
    }

    func onCall(_ method: String, param: [AnyHashable: Any]?, resultCallback: @escaping TUICallServiceResultCallback) -> Any? {
        return false
    }

    // MARK: - Actions

    private func showContactEntrance() {
        let bundleID = Bundle.main.bundleIdentifier
        if bundleID == "com.tencent.rtc.app" {
            contactEntranceView.isHidden = false
        }
    }

    private func hideContactEntrance() {
        contactEntranceView.isHidden = true
    }

    private func goToContactUs() {
        if !contactEntranceView.isHidden {
            contactEntranceView.isHidden = true
        }

        guard let url = URL(string: "https://trtc.io/contact") else { return }
        let safariVC = SFSafariViewController(url: url)
        safariVC.preferredControlTintColor = .systemBlue

        guard let topVC = Self.topViewController() else { return }
        topVC.present(safariVC, animated: true, completion: nil)
    }

    private static func topViewController() -> UIViewController? {
        guard let rootVC = getCurrentWindow()?.rootViewController else { return nil }
        return findTopViewController(from: rootVC)
    }

    private static func findTopViewController(from vc: UIViewController) -> UIViewController {
        if let nav = vc as? UINavigationController, let visible = nav.visibleViewController {
            return findTopViewController(from: visible)
        }
        if let tab = vc as? UITabBarController, let selected = tab.selectedViewController {
            return findTopViewController(from: selected)
        }
        if let presented = vc.presentedViewController {
            return findTopViewController(from: presented)
        }
        return vc
    }

    // MARK: - Window Utilities

    private static func getCurrentWindow() -> UIWindow? {
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}
