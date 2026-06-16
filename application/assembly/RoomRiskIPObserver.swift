//
//  RoomRiskIPObserver.swift
//  AppAssembly
//
//  房间内高风险 IP 用户 IM 消息监听
//
//  职责：
//    - 全局单例，监听 V2TIMGroupListener.onReceiveRESTCustomData
//    - 解析 isHighRiskUserInRoom 字段
//    - 通过 AppAssembly.shared.privacyActionHandler 触发高风险 IP 弹窗
//    - 每个房间会话仅提示一次（isShownRiskIpAlert 标记）
//
//  迁移自旧版 PrivacyRoomStateObserver.m 中的 IM 消息监听逻辑。
//  由 LiveModule / CallModule 初始化时调用 register()。
//

import Foundation
import ImSDK_Plus

// MARK: - RoomRiskIPObserver

/// 房间内高风险 IP 用户 IM 消息监听器
///
/// 全局单例，监听 IM 群组自定义消息，检测 `isHighRiskUserInRoom` 字段。
/// 每个房间会话仅弹窗一次，房间结束时重置标记。
final class RoomRiskIPObserver: NSObject {

    static let shared = RoomRiskIPObserver()

    /// 当前房间会话是否已弹过高风险 IP 提示
    private var isShownRiskIpAlert = false

    private override init() {
        super.init()
    }

    /// 注册 IM 群组消息监听
    ///
    /// 由 LiveModule 或 CallModule 初始化时调用。
    /// 内部保证多次调用幂等（V2TIMManager 会自动去重同一个 listener）。
    func register() {
        V2TIMManager.sharedInstance()?.addGroupListener(listener: self)
    }

    /// 房间结束时重置标记
    ///
    /// 由房间退出逻辑调用，确保下次进入新房间时可以再次弹窗。
    func resetForNewRoom() {
        isShownRiskIpAlert = false
    }
}

// MARK: - V2TIMGroupListener

extension RoomRiskIPObserver: V2TIMGroupListener {

    func onReceiveRESTCustomData(groupID: String?, data: Data?) {
        guard !isShownRiskIpAlert else { return }

        guard let data = data, let dict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            return
        }

        let isHighRiskUserInRoom = (dict["isHighRiskUserInRoom"] as? Bool) ?? false
        if isHighRiskUserInRoom {
            isShownRiskIpAlert = true
            DispatchQueue.main.async {
                AppAssembly.shared.privacyActionHandler?(.showHighRiskIPAlert)
            }
        }
    }
}
