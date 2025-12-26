//
//  TUILiveRoomAnchorPrepareViewController.swift
//  TUILiveKit
//
//  Created by gg on 2025/4/17.
//

import AtomicXCore
import Combine
import RTCCommon
import RTCRoomEngine
import TUICore

public class TUILiveRoomAnchorPrepareViewController: UIViewController {
    private let roomId: String
    public init(roomId: String) {
        self.roomId = roomId
        super.init(nibName: nil, bundle: nil)
    }
    
    deinit {
        LiveKitLog.info("\(#file)", "\(#line)", "deinit TUILiveRoomAnchorPrepareViewController \(self)")
        
#if DEV_MODE
        TestTool.shared.unregisterCaseFrom(self)
#endif
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private let coreView: LiveCoreView = {
        let jsonObject: [String: Any] = [
            "api": "component",
            "component": 21
        ]
        if let jsonData = try? JSONSerialization.data(withJSONObject: jsonObject, options: []),
           let jsonString = String(data: jsonData, encoding: .utf8)
        {
            LiveCoreView.callExperimentalAPI(jsonString)
        }
        return LiveCoreView(viewType: .pushView)
    }()
    
    private lazy var rootView: AnchorPrepareView = {
        let view = AnchorPrepareView(roomId: roomId, coreView: coreView)
        view.delegate = self
        return view
    }()
    
    var willStartLive: ((_ vc: TUILiveRoomAnchorViewController) -> ())?
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
#if DEV_MODE
        let feature = TestCaseItemModel(title: "禁用所有按钮", view: rootView, sel: #selector(AnchorPrepareView.disableFeatureMenuForTest(_:)))
        let switchCamera = TestCaseItemModel(title: "禁用切换摄像头按钮", view: rootView, sel: #selector(AnchorPrepareView.disableMenuSwitchCameraBtnForTest(_:)))
        let beauty = TestCaseItemModel(title: "禁用美颜按钮", view: rootView, sel: #selector(AnchorPrepareView.disableMenuBeautyBtnForTest(_:)))
        let audioEffect = TestCaseItemModel(title: "禁用音效按钮", view: rootView, sel: #selector(AnchorPrepareView.disableMenuAudioEffectBtnForTest(_:)))
        let model = TestCaseModel(list: [feature, switchCamera, beauty, audioEffect], obj: self)
        TestTool.shared.registerCase(model)
#endif
    }
    
    override public func loadView() {
        view = rootView
    }
    
    override public func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        let isPortrait = size.width < size.height
        rootView.updateRootViewOrientation(isPortrait: isPortrait)
    }
}

extension TUILiveRoomAnchorPrepareViewController: AnchorPrepareViewDelegate {
    public func onClickBackButton() {
        if let nav = navigationController {
            nav.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
        StateCache.shared.clear()
        AudioEffectStore.shared.reset()
        DeviceStore.shared.reset()
        BaseBeautyStore.shared.reset()
    }
    
    public func onClickStartButton(state: PrepareState) {
        guard let rootVC = TUITool.applicationKeywindow().rootViewController else { return }
        let tmpView: UIView
        if let snapshot = rootView.snapshotView(afterScreenUpdates: true) {
            tmpView = snapshot
        } else {
            tmpView = rootView
        }
        rootVC.view.addSubview(tmpView)
        tmpView.frame = rootView.bounds
        
        dismiss(animated: false) { [weak self, weak tmpView, weak rootVC] in
            guard let self = self, let tmpView = tmpView, let rootVC = rootVC else { return }
            
            let param = LiveParams(liveID: roomId, prepareState: state)
            let anchorVC = TUILiveRoomAnchorViewController(liveParams: param, coreView: coreView, behavior: .createRoom)
            anchorVC.modalPresentationStyle = .fullScreen

            willStartLive?(anchorVC)
            
            rootVC.present(anchorVC, animated: false) { [weak tmpView, weak rootVC] in
                guard let tmpView = tmpView, let rootVC = rootVC else { return }
                rootVC.view.bringSubviewToFront(tmpView)
                UIView.animate(withDuration: 0.3) {
                    tmpView.alpha = 0
                } completion: { _ in
                    tmpView.safeRemoveFromSuperview()
                }
            }
        }
    }
}
