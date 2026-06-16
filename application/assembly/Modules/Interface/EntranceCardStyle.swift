//
//  EntranceCardStyle.swift
//  AppAssembly
//
//  卡片样式枚举 — 对应旧版 EntranceType，保持三种样式不变
//

import Foundation

/// 首页入口卡片的展示样式
public enum EntranceCardStyle {
    /// 标准模块卡片（白色背景，图标 + 标题 + 描述）
    case standard

    /// UI 组件卡片（渐变背景，额外显示蓝色"UI组件"标签）
    case uiComponent

    /// 通栏卡片（带箭头和背景图，蓝色标题 + 渐变）
    case banner
}
