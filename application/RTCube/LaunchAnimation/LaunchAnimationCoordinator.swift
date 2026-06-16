//
//  LaunchAnimationCoordinator.swift
//  RTCube / TencentRTC / RTCubeLab
//
//  开屏动画"展示时机"决策入口。
//
//  播放规则（语义层面，三种"应播放"场景）：
//  1. 应用全新安装后第一次登录成功进入首页
//  2. 应用升级到新版本后第一次登录成功进入首页
//  3. token / userSig 过期后重新登录成功进入首页
//
//  实现策略：
//  - 唯一触发入口：SceneDelegate 的 LoginEntry.launch 登录成功回调
//    （无论自动登录还是手动登录，都在此回调中统一决策）
//  - 持久化层负责「资源是否就绪 + 当前版本是否已播放过」的确定性检查
//  - 进程内通过 `tryAcquirePlaybackForCurrentLaunch()` 提供一次性"播放权"抢占，防止重复触发
//  - 重置入口（`resetForReLogin`）由壳工程在 `LoginEntry.onTokenExpired` 中调用，
//    清除持久化记录与进程内闸门，让"过期重登"满足"应播放"语义
//

import Foundation
import UIKit

enum LaunchAnimationCoordinator {
    /// 开屏视频文件名（不含扩展名）。资源已加入主 bundle。
    private static let videoBaseName = "69babfea7b12a1a7d89502bc918f480b"
    private static let videoExtension = "mov"

    /// 进程内"本次启动是否已经播放过"的闸门，防止同一次冷启动内重复触发。
    private static var isScheduledForCurrentLaunch = false

    /// 是否需要播放开屏动画（只读判定，不抢占锁）。
    ///
    /// 决策条件（同时满足才返回 true）：
    /// 1. 视频资源存在于主 bundle
    /// 2. 当前版本号未被记录为「已播放过」
    ///
    /// 例外：RTCubeLab（开发与测试 target，定义了 `RTCUBE_LAB` 编译宏）
    /// 不展示开屏动画，便于快速进入业务调试。所有触发路径
    /// （SceneDelegate 登录页 dismiss / 首页 viewWillAppear）共享此决策入口，
    /// 因此在此一处短路即可生效，无需修改各调用点。
    static func shouldPlayOnEnterHome() -> Bool {
        #if RTCUBE_LAB
        return false
        #else
        return videoURL() != nil && !LaunchAnimationPlaybackRecord.hasPlayedForCurrentVersion
        #endif
    }

    /// 抢占本次启动的"开屏动画播放权"。
    ///
    /// 返回 true 表示抢到，调用方应立即播放；
    /// 返回 false 表示不该播（资源缺失 / 已播过本版本 / 本次启动已播放过）。
    static func tryAcquirePlaybackForCurrentLaunch() -> Bool {
        guard shouldPlayOnEnterHome() else { return false }
        guard !isScheduledForCurrentLaunch else { return false }
        isScheduledForCurrentLaunch = true
        return true
    }

    /// 获取开屏视频在主 bundle 中的本地 URL。
    static func videoURL() -> URL? {
        return Bundle.main.url(forResource: videoBaseName, withExtension: videoExtension)
    }

    /// 标记当前版本已成功播放完开屏动画。
    static func markPlayedForCurrentVersion() {
        LaunchAnimationPlaybackRecord.markPlayedForCurrentVersion()
    }

    /// 重置播放记录，让下一次登录成功重新播放。
    /// 调用时机：token / userSig 过期事件（`LoginEntry.onTokenExpired`）。
    static func resetForReLogin() {
        LaunchAnimationPlaybackRecord.clear()
        isScheduledForCurrentLaunch = false
    }
}
