//
//  EntranceState.swift
//  main
//
//  首页 UI 状态定义
//

import Foundation
import AppAssembly

/// 首页 UI 状态
///
/// 包含当前展示的模块列表、举报提示栏可见性、用户头像等 UI 相关状态。
struct EntranceState {
    /// 当前展示的模块列表（已过滤权限和可见性）
    var modules: [ResolvedModule] = []

    /// 举报提示栏是否可见（仅中文环境 + 非 MOA 用户显示）
    var isReportViewVisible: Bool = false

    /// 用户头像 URL
    var userAvatarURL: String = ""

    /// 是否需要人脸核身
    var isNeedFaceAuth: Bool = false
}
