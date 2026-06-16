//
//  ModuleEnvironment.swift
//  AppAssembly
//
//  模块环境配置 — 壳工程在启动时统一注入，业务模块按需读取
//
//

import Foundation
import Login

/// 模块运行所依赖的外部环境与参数
public struct ModuleEnvironment {
    // === 静态配置 ===
    /// Live 模块的推流 License URL
    public let liveLicenseURL: String
    /// Live 模块的推流 License Key
    public let liveLicenseKey: String
    /// 美颜 / 短视频模块的 License URL
    public let effectLicenseURL: String
    /// 美颜 / 短视频模块的 License Key
    public let effectLicenseKey: String
    /// TCMediaX 播放器 License URL
    public let playerLicenseURL: String
    /// TCMediaX 播放器 License Key
    public let playerLicenseKey: String
    /// 版权曲库 License Key（音速达）
    public let copyrightedMusicLicenseKey: String
    /// 版权曲库 License URL（音速达）
    public let copyrightedMusicLicenseUrl: String

    // === 动态行为/依赖 ===
    /// 动态获取当前的 UserId
    public let getCurrentUserModel: () -> UserModel?
    /// 外部注入的 UserSig 生成算法 (传入 userId，返回 userSig)
    /// 注意：真实业务中这通常是异步的网络请求，如果是同步生成的 demo 逻辑，可以这样写
    public let generateUserSig: (_ userId: String) -> String

    public init(
        liveLicenseURL: String = "",
        liveLicenseKey: String = "",
        effectLicenseURL: String = "",
        effectLicenseKey: String = "",
        playerLicenseURL: String = "",
        playerLicenseKey: String = "",
        copyrightedMusicLicenseKey: String = "",
        copyrightedMusicLicenseUrl: String = "",
        getCurrentUserModel: @escaping () -> UserModel?,
        generateUserSig: @escaping (String) -> String
    ) {
        self.liveLicenseURL = liveLicenseURL
        self.liveLicenseKey = liveLicenseKey
        self.effectLicenseURL = effectLicenseURL
        self.effectLicenseKey = effectLicenseKey
        self.playerLicenseURL = playerLicenseURL
        self.playerLicenseKey = playerLicenseKey
        self.copyrightedMusicLicenseKey = copyrightedMusicLicenseKey
        self.copyrightedMusicLicenseUrl = copyrightedMusicLicenseUrl
        self.getCurrentUserModel = getCurrentUserModel
        self.generateUserSig = generateUserSig
    }
}
