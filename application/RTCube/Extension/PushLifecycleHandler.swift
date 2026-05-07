//
//  PushLifecycleHandler.swift
//  RTCube
//

import ImSDK_Plus
import Login

public final class PushLifecycleHandler: NSObject, AppLifecycleHandler {
    public static let shared = PushLifecycleHandler()
    private override init() {}
    
    public var businessID: Int32 = 0
    
    private var deviceToken: Data?
    
    // MARK: - AppLifecycleHandler
    
    public func applicationDidRegisterForRemoteNotifications(deviceToken: Data) {
        self.deviceToken = deviceToken
    }
    
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
