//
//  ResolvedModule.swift
//  main
//
//  合并后的最终模块数据（供 Cell 渲染）
//

import Foundation
import AppAssembly

/// 合并后的模块数据
///
/// 将 `ModuleConfig`（静态配置）与动态数据（未读数、可见性）合并，
/// 作为 CollectionView 的最终数据源。
struct ResolvedModule {
    /// 静态配置
    let config: ModuleConfig

    /// 动态未读数（初始 0，由 badgeCountPublisher 驱动更新）
    var badgeCount: UInt64 = 0

    /// 动态可见性（初始 true，由 isVisiblePublisher 驱动更新）
    var isVisible: Bool = true

    /// 对应的 ModuleProvider 弱引用（用于保持订阅关系）
    weak var provider: ModuleProvider?
}
