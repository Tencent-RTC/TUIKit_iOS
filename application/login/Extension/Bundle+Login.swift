//
//  Bundle+Login.swift
//  Login
//
//  Login Pod 的资源 Bundle 扩展
//

import Foundation
import UIKit

extension Bundle {
    /// Login Pod 的资源 bundle（对应 podspec 中 resource_bundles 的 'LoginResources'）
    static let loginResources: Bundle = {
        // 在 use_frameworks! 模式下，资源 bundle 在 Login.framework 内部
        let frameworkBundle = Bundle(for: LoginBundleToken.self)
        guard let url = frameworkBundle.url(forResource: "LoginResources", withExtension: "bundle"),
              let bundle = Bundle(url: url) else {
            // fallback: 直接使用 framework bundle
            return frameworkBundle
        }
        return bundle
    }()
}

/// 用于定位 Login.framework bundle 的私有标记类
private final class LoginBundleToken {}

// MARK: - 便捷方法

extension UIImage {
    /// 从 LoginResources bundle 中加载图片
    static func loginImage(named name: String) -> UIImage? {
        return UIImage(named: name, in: Bundle.loginResources, compatibleWith: nil)
    }
}
