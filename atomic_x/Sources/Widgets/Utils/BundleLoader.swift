//
//  BundleLoader.swift
//  AtomicX
//
//  Created by CY zhao on 2026/1/12.
//

import Foundation

// MARK: - Bundle Loader

public class BundleLoader {
    
    /// 通用的模块 Bundle 查找方法
    /// - Parameters:
    ///   - bundleName: 资源包名称，如 "TUILiveKitBundle"
    ///   - moduleName: 框架名称，如 "TUILiveKit"
    ///   - aClass: 用于定位的类
    /// - Returns: 找到的 Bundle，失败返回 nil
    public static func moduleBundle(named bundleName: String,
                                    moduleName: String,
                                    for aClass: AnyClass) -> Bundle? {
        if let url = Bundle(for: aClass).url(forResource: bundleName, withExtension: "bundle") {
            return Bundle(url: url)
        }
        
        if let url = Bundle.main.url(forResource: bundleName, withExtension: "bundle") {
            return Bundle(url: url)
        }
        
        var url = Bundle.main.url(forResource: "Frameworks", withExtension: nil)
        url = url?.appendingPathComponent(moduleName)
        url = url?.appendingPathComponent("framework")
        if let frameworkURL = url,
           let bundle = Bundle(url: frameworkURL),
           let resourceURL = bundle.url(forResource: bundleName, withExtension: "bundle") {
            return Bundle(url: resourceURL)
        }
        
        return nil
    }
    
    
    private static let placeholders = ["xxx", "yyy", "zzz", "mmm", "nnn"]
    /// 字段未覆盖时，走内置兜底
    private static let notFoundValue = "com.atomicx.localized.key.notfound"
    /// 统一的国际化核心方法，支持主 bundle 同名表覆盖文案
        /// - Parameters:
        ///   - key: Localizable.strings 中的 Key
        ///   - bundle: 所在模块的 Bundle
        ///   - tableName: .strings 文件名
        ///   - arguments: 动态参数 (可选)
        /// - Returns: 翻译后的字符串
    ///
    public static func moduleLocalized(key: String,
                                       in bundle: Bundle,
                                       tableName: String,
                                       arguments: [CVarArg] = []) -> String {
        let localizedString = mainBundleOverride(key: key, tableName: tableName)
            ?? sdkBundleLocalized(key: key, in: bundle, tableName: tableName)

        if arguments.isEmpty {
            return localizedString
        }

        if localizedString.contains("xxx") {
            return applyReplacement(origin: localizedString, args: arguments)
        } else {
            return String(format: localizedString, arguments: arguments)
        }
    }

    private static func mainBundleOverride(key: String, tableName: String) -> String? {
        let mainBundle = Bundle.main
        if let path = mainBundle.path(forResource: getPreferredLanguage(), ofType: "lproj"),
           let langBundle = Bundle(path: path) {
            let value = langBundle.localizedString(forKey: key, value: notFoundValue, table: tableName)
            if value != notFoundValue && !value.isEmpty {
                return value
            }
        }
        let value = mainBundle.localizedString(forKey: key, value: notFoundValue, table: tableName)
        return (value != notFoundValue && !value.isEmpty) ? value : nil
    }

    private static func sdkBundleLocalized(key: String, in bundle: Bundle, tableName: String) -> String {
        if let path = bundle.path(forResource: getPreferredLanguage(), ofType: "lproj"),
           let langBundle = Bundle(path: path) {
            return langBundle.localizedString(forKey: key, value: nil, table: tableName)
        }
        return bundle.localizedString(forKey: key, value: nil, table: tableName)
    }
    
    private static func applyReplacement(origin: String, args: [CVarArg]) -> String {
        var result = origin
        
        for (index, arg) in args.enumerated() {
            guard index < placeholders.count else { break }
            
            let placeholder = placeholders[index]
            
            let stringValue = String(describing: arg)
            
            result = result.replacingOccurrences(of: placeholder, with: stringValue)
        }
        
        return result
    }
}
