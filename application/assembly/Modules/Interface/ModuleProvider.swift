//
//  ModuleProvider.swift
//  AppAssembly
//
//  模块提供者协议 — 业务模块实现此协议后注册到首页
//

import Combine
import UIKit

/// 模块提供者协议
///
/// 业务模块实现此协议并注册到 `ModuleRegistry`，
/// 首页通过 `config` 获取入口配置，通过 Publisher 订阅动态变化。
///
/// 纯静态场景（无动态未读数/无条件显隐）无需实现 `badgeCountPublisher` 和 `isVisiblePublisher`，
/// 默认实现会返回 `0` 和 `true`。
public protocol ModuleProvider: AnyObject {
    /// 入口配置
    var config: ModuleConfig { get }

    /// 未读数（可选，默认 0）。首页会通过 Combine 订阅此属性的变化
    var badgeCountPublisher: AnyPublisher<UInt64, Never> { get }

    /// 是否显示此模块（可选，默认 true）。用于条件显隐
    var isVisiblePublisher: AnyPublisher<Bool, Never> { get }

    func setup(with environment: ModuleEnvironment)
}

// MARK: - Default Implementations

public extension ModuleProvider {
    var badgeCountPublisher: AnyPublisher<UInt64, Never> {
        Just(0).eraseToAnyPublisher()
    }

    var isVisiblePublisher: AnyPublisher<Bool, Never> {
        Just(true).eraseToAnyPublisher()
    }
    
    func setup(with environment: ModuleEnvironment) {}
}

// MARK: - 公共渐变色

/// UI 组件卡片 / Banner 使用的蓝色渐变
public let stubUIComponentGradient: [UIColor] = [
    UIColor(red: 204 / 255.0, green: 223 / 255.0, blue: 255 / 255.0, alpha: 1),
    UIColor(red: 204 / 255.0, green: 223 / 255.0, blue: 255 / 255.0, alpha: 0.3),
    UIColor(red: 204 / 255.0, green: 223 / 255.0, blue: 255 / 255.0, alpha: 0),
]
