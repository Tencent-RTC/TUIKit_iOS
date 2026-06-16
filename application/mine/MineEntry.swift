//
//  MineEntry.swift
//  mine
//
//  个人中心模块唯一对外接口
//
//  使用方式：
//    let mineVC = MineEntry.shared.buildMineViewController(
//        onLogout: { ... },
//        onLanguageChanged: { ... },
//        onExperienceRoomClicked: { ... }
//    )
//    navigationController?.pushViewController(mineVC, animated: true)
//

import UIKit
import Login

/// 个人中心模块唯一对外接口
public final class MineEntry {
    public static let shared = MineEntry()
    private init() {}
    
    // MARK: - 对外方法
    
    /// 构建个人中心 ViewController
    ///
    /// - Parameters:
    ///   - onLogout: 退出登录回调，外部自行处理登出流程
    ///   - onLanguageChanged: 语言切换完成回调，外部自行刷新 UI
    ///   - onExperienceRoomClicked: 体验房按钮点击回调，外部自行处理跳转
    /// - Returns: 个人中心页面 ViewController
    public func buildMineViewController(
        onLogout: @escaping () -> Void,
        onLanguageChanged: ((String) -> Void)? = nil,
        onExperienceRoomClicked: (() -> Void)? = nil
    ) -> UIViewController {
        let vc = MineViewController()
        vc.onLogout = onLogout
        vc.onLanguageChanged = onLanguageChanged
        vc.onExperienceRoomClicked = onExperienceRoomClicked
        return vc
    }
}
