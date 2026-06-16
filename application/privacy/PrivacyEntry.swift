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

    public static var dataCollectionURL: String {
        return (privacyInfo["dataCollectionURL"] as? String) ?? ""
    }

    public static var thirdShareURL: String {
        return (privacyInfo["thirdShareURL"] as? String) ?? ""
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
        if let navController = viewController as? UINavigationController {
            navController.pushViewController(vc, animated: true)
        } else if let navigationController = viewController?.navigationController {
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
            return (privacyURL, PrivacyLocalize("privacy_agreement"))
        case .privacySummary:
            return (privacySummaryURL, PrivacyLocalize("privacy_policy_summary"))
        case .agreement:
            return (agreementURL, PrivacyLocalize("privacy_user_agreement"))
        case .dataCollection:
            return (dataCollectionURL, PrivacyLocalize("privacy_data_collection_list"))
        case .thirdShare:
            return (thirdShareURL, PrivacyLocalize("privacy_third_share"))
        }
    }
}

public enum PrivacyPageType {
    case privacy
    case privacySummary
    case agreement
    case dataCollection
    case thirdShare
    case privacyCenter
}
