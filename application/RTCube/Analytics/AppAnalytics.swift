//
//  AppAnalytics.swift
//  RTCube (Open Source)
//
//  埋点门面 — 开源版空实现
//
//  与内部版同名同签名，方法体均为空。
//  本文件**不** import SensorsAnalyticsSDK，开源版编译产物中不含任何神策符号。
//
//  发布脚本 `sync_oss_project.rb` 会将 application/opensource/ 目录上移覆盖
//  application/，使开源工程最终打包使用本空实现版本。
//

import AppAssembly
import Foundation
import UIKit

/// 壳工程埋点门面（开源版空实现）
public enum AppAnalytics {

    // MARK: - SDK Lifecycle

    /// 初始化埋点 SDK — 开源版不执行任何操作
    public static func start(launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        // No-op in open source build.
    }

    /// 初始化公共属性并绑定用户 — 开源版不执行任何操作
    public static func initialize(sdkAppId: Int, userId: String, appTarget: String, appVersion: String, loginMode: String) {
        // No-op in open source build.
    }

    /// 处理埋点 SDK 的 URL Scheme 回调 — 开源版始终返回 false
    @discardableResult
    public static func handleSchemeURL(_ url: URL) -> Bool {
        return false
    }

    /// 绑定登录用户身份 — 开源版不执行任何操作
    public static func bindUser(_ userId: String) {
        // No-op in open source build.
    }

    // MARK: - Main Click Event

    /// 上报首页模块点击事件 — 开源版不执行任何操作
    public static func trackMainClick(eventName: AnalyticName, mainEvent: String, loginType: String) {
        // No-op in open source build.
    }

    // MARK: - Module Event

    /// 上报模块级事件 — 开源版不执行任何操作
    public static func trackModuleEvent(moduleId: String, event: AnalyticName, params: [String: Any] = [:]) {
        // No-op in open source build.
    }
}
