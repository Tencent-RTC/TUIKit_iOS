//
//  EntranceStore.swift
//  main
//
//  首页状态管理（Store）
//
//  职责：
//    1. 从 ModuleRegistry 加载模块列表
//    2. 订阅各 ModuleProvider 的 badge/visibility 动态变化
//    3. 权限过滤（黑名单 + 高风险用户检查）
//    4. 处理模块点击（创建目标 VC + 埋点）
//

import Combine
import UIKit
import AppAssembly

/// 首页 Store — 管理首页数据流
///
/// 外部通过 `$state` 订阅 UI 状态变化，驱动 CollectionView 刷新。
final class EntranceStore {

    /// 当前 UI 状态（使用 @Published 支持 Combine 订阅）
    @Published private(set) var state = EntranceState()

    private var cancellables = Set<AnyCancellable>()

    // MARK: - 加载模块

    /// 从 ModuleRegistry 加载模块，订阅动态变化
    func loadModules() {
        var resolved = ModuleRegistry.shared.resolvedModules()

        // 权限过滤
        resolved = ModulePermissionService.shared.filter(resolved)

        state.modules = resolved

        // 订阅各 Provider 的 badge/visibility 变化
        subscribeDynamicUpdates()
    }

    // MARK: - 模块点击

    /// 处理模块点击
    ///
    /// - Parameter index: 点击的模块索引
    /// - Returns: 如果模块可用，返回目标 VC；否则返回 nil
    func selectModule(at index: Int) -> UIViewController? {
        guard index < state.modules.count else { return nil }
        let module = state.modules[index]

        // 权限检查
        guard ModulePermissionService.shared.isModuleEnabled(module) else {
            return nil
        }

        // 埋点
        if !module.config.analyticsEvent.isEmpty {
            trackAnalytics(event: module.config.analyticsEvent)
        }

        // 创建目标 VC
        return module.config.targetProvider()
    }

    // MARK: - 未读数

    /// 获取指定模块的未读数
    func badgeCount(at index: Int) -> UInt64 {
        guard index < state.modules.count else { return 0 }
        return state.modules[index].badgeCount
    }

    /// 更新指定模块的未读数
    ///
    /// - Parameters:
    ///   - identifier: 模块的 identifier
    ///   - count: 新的未读数
    func updateBadgeCount(for identifier: String, count: UInt64) {
        guard let index = state.modules.firstIndex(where: { $0.config.identifier == identifier }) else { return }
        state.modules[index].badgeCount = count
    }

    // MARK: - Private

    /// 订阅各 Provider 的动态数据变化
    private func subscribeDynamicUpdates() {
        // 清除旧订阅
        cancellables.removeAll()

        for (index, module) in state.modules.enumerated() {
            guard let provider = module.provider else { continue }

            // 订阅未读数变化
            provider.badgeCountPublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] count in
                    guard let self = self, index < self.state.modules.count else { return }
                    self.state.modules[index].badgeCount = count
                }
                .store(in: &cancellables)

            // 订阅可见性变化
            provider.isVisiblePublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] visible in
                    guard let self = self, index < self.state.modules.count else { return }
                    self.state.modules[index].isVisible = visible
                }
                .store(in: &cancellables)
        }
    }

    /// 埋点上报
    private func trackAnalytics(event: String) {
        AppLogger.App.debug(" trackAnalytics: \(event)")
    }
}
