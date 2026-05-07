//
//  RoomRiskIPObserver.swift
//  AppAssembly
//

import Foundation
import ImSDK_Plus

// MARK: - RoomRiskIPObserver

final class RoomRiskIPObserver: NSObject {

    static let shared = RoomRiskIPObserver()

    private var isShownRiskIpAlert = false

    private override init() {
        super.init()
    }

    func register() {
        V2TIMManager.sharedInstance()?.addGroupListener(listener: self)
    }

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
