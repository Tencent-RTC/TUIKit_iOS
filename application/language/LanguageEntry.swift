//
//  LanguageEntry.swift
//  language
//
//  语言切换模块唯一对外接口
//
//  使用方式：
//    LanguageEntry.shared.pushLanguageSelect(from: navigationController) { changed in
//        // changed == true 表示用户切换了语言，外部需要刷新 UI
//    }
//

import UIKit

// MARK: - 语言存储 Key
private let kAppPreferredLanguageKey = "app_preferred_language"
// 默认语言
private let kDefaultLanguageID = "en"

/// 语言切换模块唯一对外接口
public final class LanguageEntry {
    public static let shared = LanguageEntry()
    private init() {}
    
    // MARK: - 对外方法
    
    /// Push 语言选择页面
    ///
    /// - Parameters:
    ///   - navigationController: 承载 push 的导航控制器
    ///   - completion: 语言切换完成回调。`changed == true` 表示用户选择了不同的语言，
    ///                 外部应根据此标志刷新 UI（重建页面栈等）。
    public func pushLanguageSelect(
        from navigationController: UINavigationController,
        completion: ((Bool) -> Void)? = nil
    ) {
        let vc = LanguageSelectViewController()
        vc.onLanguageChanged = { [weak vc] languageID in
            completion?(true)
        }
        navigationController.pushViewController(vc, animated: true)
    }
    
    /// 构建语言选择 ViewController（不执行 push，交给外部展示）
    ///
    /// - Parameter completion: 语言切换完成回调。`languageID` 为用户选中的语言标识
    ///                         （如 `"zh-Hans"`、`"en"`）。
    /// - Returns: 语言选择页面 ViewController
    public func buildLanguageSelectViewController(
        completion: ((String) -> Void)? = nil
    ) -> UIViewController {
        let vc = LanguageSelectViewController()
        vc.onLanguageChanged = { languageID in
            completion?(languageID)
        }
        return vc
    }
    
    // MARK: - 便捷查询
    
    /// 当前语言标识（如 `"zh-Hans"`、`"en"`）
    public var currentLanguageID: String {
        get {
            return UserDefaults.standard.string(forKey: kAppPreferredLanguageKey) ?? kDefaultLanguageID
        }
        set {
            UserDefaults.standard.set(newValue, forKey: kAppPreferredLanguageKey)
        }
    }
    
    /// 当前是否为中文环境
    public var isChinese: Bool {
        return currentLanguageID.hasPrefix("zh")
    }
}
