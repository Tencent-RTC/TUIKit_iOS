//
//  PictureInPictureStore.swift
//  TUILiveKit
//
//  Created by gg on 2025/12/9.
//

import AtomicXCore
import Combine
import RTCRoomEngine
import AtomicX

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

    func enablePictureInPicture(enable: Bool, liveID: String, isLandscape: Bool = false) {
        state.update {
            $0.enablePictureInPictureToggle = enable
            $0.liveID = liveID
        }
        callEnablePictureInPicture(enable: enable, liveID: liveID, isLandscape: isLandscape)
    }

    private func reset() {
        state.update {
            $0.liveID = ""
            $0.enablePictureInPictureToggle = false
        }
    }

    private func callEnablePictureInPicture(enable: Bool, liveID: String, isLandscape: Bool = false) {
        let canvasWidth: CGFloat = 720
        let canvasHeight: CGFloat = 1280
        
        let w: CGFloat = 1.0
        let h: CGFloat = isLandscape ? (9.0 / 16.0 * canvasWidth / canvasHeight) : 1.0
        let x: CGFloat = 0.0
        let y: CGFloat = isLandscape ? ((1.0 - h) / 2.0) : 0.0
        
        let jsonObject: [String: Any] = [
            "api": "enablePictureInPicture",
            "params": [
                "enable": enable,
                "room_id": liveID,
                "camBackgroundCapture": true,
                "canvas": [
                    "width": canvasWidth,
                    "height": canvasHeight,
                    "backgroundColor": "#000000"
                ],
                "regions": [
                    [
                        "userId": "",
                        "userName": "",
                        "backgroundColor": "#000000",
                        "width": w,
                        "height": h,
                        "x": x,
                        "y": y,
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
