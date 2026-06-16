//
//  ModulePermissionService.swift
//  main
//
//  模块权限检查（黑名单 + 高风险用户）
//
//  从旧版 EntranceViewController 中的 getUserBlackList / isModelEnable / showBanedToast 逻辑迁移。
//

import UIKit
import AppAssembly
import Login

/// 模块权限服务
///
/// 负责从服务端获取模块黑名单、检查高风险用户状态，
/// 统一管理模块的可用性判断。
///
/// 业务模块无需关心权限逻辑，由首页在加载模块列表时统一过滤。
final class ModulePermissionService {
    static let shared = ModulePermissionService()
    private init() {}

    /// 被禁用的模块 identifier 集合（从服务端获取）
    private(set) var bannedModuleIds: Set<String> = []

    /// 被禁用的功能ID集合（从服务端获取，使用UserDefaults存储）
    private var bannedFeatureIds: Set<String> {
        get {
            let ids = UserDefaults.standard.stringArray(forKey: "rtcube_module_permission.bannedFeatureIds") ?? []
            return Set(ids)
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: "rtcube_module_permission.bannedFeatureIds")
        }
    }

    /// 当前用户是否为高风险用户
    private(set) var isHighRiskUser: Bool = false

    /// 是否需要人脸核身
    private(set) var isNeedFaceAuth: Bool = false

    // MARK: - 服务端数据加载

    /// 从服务端获取用户模块黑名单
    ///
    /// 对应旧版 `LoginManager.shared.getUserModuleBlackList()`
    func loadUserBlackList() {
        LoginManager.shared.getUserModuleBlackList(success: { [weak self] _ in
            guard let self = self else { return }
            if let modules = LoginManager.shared.currentUser?.bannedModules {
                self.updateBannedModules(modules)
            }
            AppLogger.App.info(" loadUserBlackList success, bannedModuleIds: \(self.bannedModuleIds)")
        }, failed: { errorCode, errorMessage in
            AppLogger.App.error(" loadUserBlackList failed: \(errorCode) \(errorMessage ?? "")")
        })
    }

    /// 检查当前用户是否为高风险用户
    ///
    /// 对应旧版 `checkHighRiskUser()`
    /// - Returns: `true` 表示用户为高风险用户
    func checkHighRiskUser() -> Bool {
        guard let user = LoginManager.shared.getCurrentUser() else { return false }
        let result = user.isHighRiskUser
        if result {
            isHighRiskUser = true
            isNeedFaceAuth = true
        }
        AppLogger.App.info(" checkHighRiskUser called, isHighRisk: \(result)")
        return result
    }

    /// 更新被禁用的模块列表
    func updateBannedModules(_ modules: [String: Bool]) {
        bannedModuleIds = Set(modules.filter { $0.value == true }.map { $0.key })
    }

    /// 更新高风险用户状态
    func updateHighRiskUser(_ isHighRisk: Bool) {
        self.isHighRiskUser = isHighRisk
    }

    /// 更新是否需要人脸核身
    func updateNeedFaceAuth(_ needFaceAuth: Bool) {
        self.isNeedFaceAuth = needFaceAuth
    }

    // MARK: - 权限检查

    /// 检查单个模块是否可用
    ///
    /// - Parameter module: 待检查的模块
    /// - Returns: true 表示模块可用
    func isModuleEnabled(_ module: ResolvedModule) -> Bool {
        // 需要人脸核身时全部禁用
        if isNeedFaceAuth {
            return false
        }

        // 高风险用户全部禁用
        if isHighRiskUser {
            return false
        }

        // banner 类型（行业场景）仅检查高风险，不检查黑名单
        if module.config.cardStyle == .banner {
            return true
        }

        // 黑名单检查
        return !bannedModuleIds.contains(module.config.identifier)
    }

    /// 过滤模块列表
    ///
    /// 注意：此方法不移除被禁用的模块（仍然展示卡片），
    /// 只在点击时通过 `isModuleEnabled` 做拦截。
    /// 如果未来需要直接隐藏某些模块，可在此处过滤。
    func filter(_ modules: [ResolvedModule]) -> [ResolvedModule] {
        // 当前策略：所有模块都展示，点击时再做权限检查
        // 如需过滤不可见模块：
        // return modules.filter { $0.isVisible }
        return modules
    }
}
