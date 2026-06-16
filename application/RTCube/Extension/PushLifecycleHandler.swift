//
//  PushLifecycleHandler.swift
//  RTCube
//
//  负责 deviceToken 的存储与上报：
//    1. 通过 AppLifecycleRegistry 接收系统 deviceToken 回调并缓存
//    2. 在 IM 登录成功后调用 reportDeviceToken() 上报给 IM SDK，恢复离线推送能力
//
//  使用方式：
//    - AppDelegate.registerPushLifecycleHandler() 中注入 businessID 并注册到 AppLifecycleRegistry
//    - SceneDelegate 登录成功回调中调用 PushLifecycleHandler.shared.reportDeviceToken()
//

import ImSDK_Plus
import Login

/// 推送 DeviceToken 生命周期处理器（单例）
///
/// 通过 `AppLifecycleHandler` 协议接收系统 deviceToken 回调，
/// 在 IM 登录成功后将 token 上报给 IM SDK 以启用离线推送。
public final class PushLifecycleHandler: NSObject, AppLifecycleHandler {
    public static let shared = PushLifecycleHandler()
    private override init() {}
    
    // MARK: - 外部注入
    
    /// 推送证书 ID（由壳工程在启动时注入）
    public var businessID: Int32 = 0
    
    // MARK: - 内部状态
    
    /// 系统分配的 deviceToken（收到回调后缓存）
    private var deviceToken: Data?
    
    // MARK: - AppLifecycleHandler
    
    public func applicationDidRegisterForRemoteNotifications(deviceToken: Data) {
        self.deviceToken = deviceToken
    }
    
    // MARK: - 上报
    
    /// 将 deviceToken 上报给 IM SDK
    ///
    /// 在 IM 登录成功后调用。若 deviceToken 尚未获取（系统回调未到达），静默跳过。
    public func reportDeviceToken() {
        guard let deviceToken = deviceToken else { return }
        
        let config = V2TIMAPNSConfig()
        config.token = deviceToken
        config.businessID = businessID
        
        V2TIMManager.sharedInstance().setAPNS(config: config, succ: {
            debugPrint("setAPNS success")
        }, fail: { code, message in
            debugPrint("setAPNS failed, code: \(code), message: \(message ?? "")")
        })
    }
}
