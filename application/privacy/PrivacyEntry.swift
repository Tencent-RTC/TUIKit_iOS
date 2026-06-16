//
//  PrivacyEntry.swift
//  privacy
//
//  隐私模块唯一对外接口
//
//  职责：
//    1. 从 Bundle.main 读取 Privacy.plist，提供隐私/用户协议 URL
//    2. 提供隐私协议 WebView 页面（PrivacyWebViewController）
//
//  壳工程直接编译，不需要额外 pod
//

import AppAssembly
import UIKit

/// 是否为 TencentRTC App（海外版），海外版不显示反诈提示
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

/// 隐私模块唯一对外接口
public final class PrivacyEntry {
    private init() {}

    // MARK: - 全局配置

    /// 是否启用实名认证（身份证校验），默认 YES
    private static var _enableIdCardVerification = true
    public static var enableIdCardVerification: Bool {
        get { _enableIdCardVerification }
        set { _enableIdCardVerification = newValue }
    }

    // MARK: - 隐私协议 URL（从 Privacy.plist 读取）

    private static let privacyInfo: NSDictionary = {
        guard let path = Bundle.main.path(forResource: "Privacy", ofType: "plist"),
              let info = NSDictionary(contentsOfFile: path)
        else {
            return NSDictionary()
        }
        return info
    }()

    /// 用户协议 URL
    public static var agreementURL: String {
        return (privacyInfo["userProtocolURL"] as? String) ?? ""
    }

    /// 隐私协议摘要 URL
    public static var privacySummaryURL: String {
        return (privacyInfo["privacySummaryURL"] as? String) ?? ""
    }

    /// 隐私协议 URL
    public static var privacyURL: String {
        return (privacyInfo["privacyURL"] as? String) ?? ""
    }

    /// 个人信息收集清单 URL
    public static var dataCollectionURL: String {
        return (privacyInfo["dataCollectionURL"] as? String) ?? ""
    }

    /// 第三方信息共享清单 URL
    public static var thirdShareURL: String {
        return (privacyInfo["thirdShareURL"] as? String) ?? ""
    }

    // MARK: - 页面跳转

    /// 创建隐私协议 WebView 页面
    ///
    /// - Parameters:
    ///   - url: 协议网址
    ///   - title: 导航栏标题
    /// - Returns: 配置好的 ViewController，由调用方 push
    public static func makeWebViewController(url: URL, title: String) -> UIViewController {
        return PrivacyWebViewController(url: url, title: title)
    }

    /// 便捷方法：打开隐私协议页面
    ///
    /// 优先使用 `viewController.navigationController` push；
    /// 如果没有 navigationController，则 present（自动包装 UINavigationController）。
    ///
    /// - Parameters:
    ///   - type: 协议类型
    ///   - viewController: 当前页面控制器
    public static func pushPrivacyPage(_ type: PrivacyPageType, from viewController: UIViewController?) {
        let vc: UIViewController

        if type == .privacyCenter {
            // 隐私管理中心 — 完整列表页面（个人中心入口）
            let config = PrivacyConfig.makeWithCurrentUser()
            vc = PrivacyCenterViewController(config: config)
        } else {
            // 隐私协议 / 摘要 / 用户协议 — WebView
            let (urlString, title) = urlAndTitle(for: type)
            guard let url = URL(string: urlString), !urlString.isEmpty else { return }
            vc = makeWebViewController(url: url, title: title)
        }

        vc.hidesBottomBarWhenPushed = true
        if let navController = viewController as? UINavigationController {
            // viewController 本身是 UINavigationController（如从 PrivacyAlertView 传入的 LoginNavigator.navigationController）
            navController.pushViewController(vc, animated: true)
        } else if let navigationController = viewController?.navigationController {
            navigationController.pushViewController(vc, animated: true)
        } else {
            let nav = UINavigationController(rootViewController: vc)
            nav.modalPresentationStyle = .fullScreen
            viewController?.present(nav, animated: true)
        }
    }

    /// 根据协议类型获取 URL 和标题
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

// MARK: - 协议页面类型

/// 隐私协议页面类型
public enum PrivacyPageType {
    /// 隐私协议（WebView，用于登录页等场景）
    case privacy
    /// 隐私协议摘要
    case privacySummary
    /// 用户协议
    case agreement
    /// 个人信息收集清单
    case dataCollection
    /// 第三方信息共享清单
    case thirdShare
    /// 隐私管理中心（完整列表页面，用于个人中心）
    case privacyCenter
}


