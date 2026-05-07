//
//  PrivacyEntry.swift
//  privacy
//

import AppAssembly
import UIKit

var isTencentRTCApp: Bool {
    return Bundle.main.bundleIdentifier == "com.tencent.rtc.app"
}

var isRTCubeLab: Bool {
    #if RTCUBE_LAB
    return true
    #else
    return false
    #endif
}

public final class PrivacyEntry {
    private init() {}

    private static var _enableIdCardVerification = true
    public static var enableIdCardVerification: Bool {
        get { _enableIdCardVerification }
        set { _enableIdCardVerification = newValue }
    }

    private static let privacyInfo: NSDictionary = {
        guard let path = Bundle.main.path(forResource: "Privacy", ofType: "plist"),
              let info = NSDictionary(contentsOfFile: path)
        else {
            return NSDictionary()
        }
        return info
    }()

    public static var agreementURL: String {
        return (privacyInfo["userProtocolURL"] as? String) ?? ""
    }

    public static var privacySummaryURL: String {
        return (privacyInfo["privacySummaryURL"] as? String) ?? ""
    }

    public static var privacyURL: String {
        return (privacyInfo["privacyURL"] as? String) ?? ""
    }

    public static func makeWebViewController(url: URL, title: String) -> UIViewController {
        return PrivacyWebViewController(url: url, title: title)
    }

    public static func pushPrivacyPage(_ type: PrivacyPageType, from viewController: UIViewController?) {
        let vc: UIViewController

        if type == .privacyCenter {
            let config = PrivacyConfig.makeWithCurrentUser()
            vc = PrivacyCenterViewController(config: config)
        } else {
            let (urlString, title) = urlAndTitle(for: type)
            guard let url = URL(string: urlString), !urlString.isEmpty else { return }
            vc = makeWebViewController(url: url, title: title)
        }

        vc.hidesBottomBarWhenPushed = true
        if let navigationController = viewController?.navigationController {
            navigationController.pushViewController(vc, animated: true)
        } else {
            let nav = UINavigationController(rootViewController: vc)
            nav.modalPresentationStyle = .fullScreen
            viewController?.present(nav, animated: true)
        }
    }

    private static func urlAndTitle(for type: PrivacyPageType) -> (String, String) {
        switch type {
        case .privacy, .privacyCenter:
            return (privacyURL, PrivacyLocalize("Demo.TRTC.Portal.private"))
        case .privacySummary:
            return (privacySummaryURL, PrivacyLocalize("Demo.TRTC.Portal.privacysummary"))
        case .agreement:
            return (agreementURL, PrivacyLocalize("Demo.TRTC.Portal.agreement"))
        }
    }
}

public enum PrivacyPageType {
    case privacy
    case privacySummary
    case agreement
    case privacyCenter
}
