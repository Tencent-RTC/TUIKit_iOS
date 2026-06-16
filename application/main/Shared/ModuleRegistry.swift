//
//  ModuleRegistry.swift
//  main
//
//  模块注册中心 — 管理所有首页入口模块
//

import Foundation
import AppAssembly

/// 模块注册中心
///
/// 管理所有注册的 `ModuleProvider`，按注册顺序排列。
/// 所有注册操作在 `EntranceViewController.viewDidLoad()` 中统一完成。
final class ModuleRegistry {
    static let shared = ModuleRegistry()
    private init() {}

    /// 已注册的 ModuleProvider 列表（按注册顺序排列）
    private(set) var providers: [ModuleProvider] = []

    /// 注册模块
    ///
    /// 根据 `config.identifier` 去重，同一 identifier 不会重复注册。
    /// - Parameter provider: 实现了 `ModuleProvider` 协议的业务模块
    func register(_ provider: ModuleProvider) {
        guard !providers.contains(where: { $0.config.identifier == provider.config.identifier }) else {
            AppLogger.App.warn(" 重复注册被忽略: \(provider.config.identifier)")
            return
        }
        providers.append(provider)
    }

    /// 获取已合并的模块列表
    ///
    /// 将每个 Provider 的 config 转换为 `ResolvedModule`，
    /// 后续由 `EntranceStore` 订阅 Publisher 驱动动态更新。
    func resolvedModules() -> [ResolvedModule] {
        return providers.map { provider in
            ResolvedModule(config: provider.config, provider: provider)
        }
    }

    /// 重置注册中心（测试用）
    func reset() {
        providers.removeAll()
    }
}
