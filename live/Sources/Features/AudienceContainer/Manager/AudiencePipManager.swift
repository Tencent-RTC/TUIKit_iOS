//
//  AudiencePipManager.swift
//  Pods
//
//  Created by ssc on 2025/10/21.
//

import Foundation
import AtomicXCore
import RTCRoomEngine
import Combine

final class AudiencePipManager {
    private let selfUserID = TUIRoomEngine.getSelfInfo().userId
    private var cancellableSet = Set<AnyCancellable>()
    private var currentLiveID = ""
    private var lastSentEnable = false
    var liveListStore: LiveListStore {
        return LiveListStore.shared
    }

    var coGuestStore: CoGuestStore {
        return CoGuestStore.create(liveID: liveListStore.state.value.currentLive.liveID)
    }

    init() {
        subscribeState()
    }
}

// MARK: - Private
private extension AudiencePipManager {
    private func subscribeState() {
        liveListStore.state.subscribe(StatePublisherSelector(keyPath: \LiveListState.currentLive))
            .receive(on: RunLoop.main)
            .dropFirst()
            .removeDuplicates()
            .combineLatest(coGuestStore.state.subscribe(StatePublisherSelector(keyPath: \CoGuestState.connected)))
            .sink { [weak self] liveInfo, connected in
                guard let self = self else { return }
                if (liveInfo.isEmpty || connected.contains(where: { $0.userID == self.selfUserID })) && !self.currentLiveID.isEmpty {
                    enablePictureInPicture(enable: false,liveID: currentLiveID)
                    currentLiveID = ""
                } else {
                    self.currentLiveID = liveInfo.liveID
                    enablePictureInPicture(enable: true,liveID: currentLiveID)
                }
            }
            .store(in: &cancellableSet)
    }

    private func enablePictureInPicture(enable: Bool,liveID: String) {
        guard lastSentEnable != enable else { return }
        let jsonObject: [String: Any] = [
            "api": "enablePictureInPicture",
            "params": [
                "enable": enable,
                "room_id": liveID,
                "canvas": [
                    "width": 720,
                    "height": 1280,
                    "backgroundColor": "#0f1014"
                ],
                "regions": [
                    [
                        "userId": "",
                        "userName": "",
                        "backgroundColor": "",
                        "width": 1.0,
                        "height": 1.0,
                        "x": 0.0,
                        "y": 0.0,
                        "fillMode": 1,
                        "streamType": "high",
                        "backgroundImage": ""
                    ]
                ]
            ]
        ]
        if let jsonData = try? JSONSerialization.data(withJSONObject: jsonObject, options: []),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            TUIRoomEngine.sharedInstance().callExperimentalAPI(jsonStr: jsonString, callback: { [weak self] _ in
                guard let self = self else {return}
                self.lastSentEnable = enable

            })
        }
    }
}
