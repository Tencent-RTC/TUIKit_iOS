//
//  ModulePermissionService.swift
//  main
//

import UIKit
import AppAssembly
import Login

final class ModulePermissionService {
    static let shared = ModulePermissionService()
    private init() {}

    private(set) var bannedModuleIds: Set<String> = []

    private(set) var isHighRiskUser: Bool = false

    private(set) var isNeedFaceAuth: Bool = false

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

    func updateBannedModules(_ modules: [String: Bool]) {
        bannedModuleIds = Set(modules.filter { $0.value == true }.map { $0.key })
    }

    func updateHighRiskUser(_ isHighRisk: Bool) {
        self.isHighRiskUser = isHighRisk
    }

    func updateNeedFaceAuth(_ needFaceAuth: Bool) {
        self.isNeedFaceAuth = needFaceAuth
    }

    func isModuleEnabled(_ module: ResolvedModule) -> Bool {
        if isNeedFaceAuth {
            return false
        }

        if isHighRiskUser {
            return false
        }

        if module.config.cardStyle == .banner {
            return true
        }

        return !bannedModuleIds.contains(module.config.identifier)
    }

    func filter(_ modules: [ResolvedModule]) -> [ResolvedModule] {
        // return modules.filter { $0.isVisible }
        return modules
    }
}
