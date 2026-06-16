//
//  AppAssemblyBundle.swift
//  AppAssembly
//
//  Resource Bundle 辅助工具 — 统一管理 AppAssembly Pod 的资源加载
//

import UIKit
import TUICore

// MARK: - AppAssemblyBundle

/// AppAssembly 模块的资源 Bundle 访问入口
///
/// CocoaPods `resource_bundles` 会将资源打包到 `AppAssemblyBundle.bundle` 中。
/// 本类提供统一接口，从该 bundle 加载图片、本地化字符串、JSON 等资源。
enum AppAssemblyBundle {

    /// 资源 Bundle 实例（懒加载单次查找）
    static let bundle: Bundle = {
        // CocoaPods resource_bundles 生成的 bundle 名称与 podspec 中的 key 一致
        let bundleName = "AppAssemblyBundle"

        // 1. 开发 Pod / use_frameworks! 场景：bundle 在 framework 内部
        let frameworkBundle = Bundle(for: BundleToken.self)
        if let url = frameworkBundle.url(forResource: bundleName, withExtension: "bundle"),
           let bundle = Bundle(url: url) {
            return bundle
        }

        // 2. 静态库场景：bundle 在 mainBundle 内
        if let url = Bundle.main.url(forResource: bundleName, withExtension: "bundle"),
           let bundle = Bundle(url: url) {
            return bundle
        }

        // 3. 回退到 mainBundle（开发阶段或未通过 Pod 集成）
        return Bundle.main
    }()

    // MARK: - Image

    /// 从 AppAssemblyBundle 加载图片
    /// - Parameter name: imageset 名称
    /// - Returns: UIImage，若找不到则返回 nil
    static func image(named name: String) -> UIImage? {
        return UIImage(named: name, in: bundle, compatibleWith: nil)
    }

    // MARK: - Localized String

    /// 从 AppAssemblyBundle 中指定 .strings 表加载本地化字符串
    ///
    /// 优先使用 `TUIGlobalization.getPreferredLanguage()` 指定的语言，
    /// 确保与 App 内手动切换语言时行为一致（`Bundle.main` 被 TUICore swizzle，
    /// 而独立 resource bundle 不受影响，需要手动加载对应 lproj）。
    /// - Parameters:
    ///   - key: 本地化 key
    ///   - table: .strings 表名（如 "CallingLocalized"）
    /// - Returns: 本地化后的字符串
    static func localizedString(forKey key: String, table: String) -> String {
        if let language = TUIGlobalization.getPreferredLanguage(),
           !language.isEmpty,
           let path = bundle.path(forResource: language, ofType: "lproj"),
           let languageBundle = Bundle(path: path) {
            return languageBundle.localizedString(forKey: key, value: "", table: table)
        }
        return bundle.localizedString(forKey: key, value: "", table: table)
    }

    // MARK: - JSON

    /// 从 AppAssemblyBundle 加载 JSON 文件路径
    /// - Parameters:
    ///   - name: 文件名（不含扩展名）
    ///   - ext: 扩展名，默认 "json"
    /// - Returns: 文件路径，找不到则返回 nil
    static func path(forResource name: String, ofType ext: String = "json") -> String? {
        return bundle.path(forResource: name, ofType: ext)
    }
}

// MARK: - Private

/// 用于定位 framework bundle 的空类（CocoaPods use_frameworks! 场景）
private final class BundleToken {}
