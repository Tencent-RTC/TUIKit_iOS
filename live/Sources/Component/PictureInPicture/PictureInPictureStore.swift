//
//  PictureInPictureStore.swift
//  TUILiveKit
//
//  Created by gg on 2025/12/9.
//

import AtomicXCore
import Combine
import RTCRoomEngine
import RTCCommon

class PictureInPictureStore {
    static let shared = PictureInPictureStore()
    private init() {
        LiveListStore.shared.state.subscribe(StatePublisherSelector(keyPath: \LiveListState.currentLive))
            .removeDuplicates()
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] currentLive in
                guard let self = self else { return }
                if currentLive.isEmpty {
                    reset()
                }
            }
            .store(in: &cancellableSet)
    }

    private var cancellableSet: Set<AnyCancellable> = []

    let state = ObservableState(initialState: PictureInPictureState())

    func enablePictureInPicture(enable: Bool, liveID: String) {
        if liveID != state.state.liveID {
            callEnablePictureInPicture(enable: false, liveID: state.state.liveID)
        }
        state.update {
            $0.enablePictureInPictureToggle = enable
            $0.liveID = liveID
        }
        callEnablePictureInPicture(enable: enable, liveID: liveID)
    }

    private func reset() {
        if !state.state.liveID.isEmpty {
            callEnablePictureInPicture(enable: false, liveID: state.state.liveID)
        }
        state.update {
            $0.liveID = ""
            $0.enablePictureInPictureToggle = false
        }
    }

    private func callEnablePictureInPicture(enable: Bool, liveID: String) {
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
           let jsonString = String(data: jsonData, encoding: .utf8)
        {
            TUIRoomEngine.sharedInstance().callExperimentalAPI(jsonStr: jsonString) { _ in
            }
        }
    }
}
