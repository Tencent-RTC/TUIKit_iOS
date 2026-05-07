//
//  AnchorPrepareViewController.swift
//  TUILiveKit
//
//  Created by gg on 2025/4/17.
//

import AtomicX
import AtomicXCore
import Combine
import TUILiveKit

class AnchorPrepareViewController: UIViewController {
    var willStartLive: ((_ vc: AnchorViewController) -> ())?
    
    private let roomId: String
    init(roomId: String) {
        self.roomId = roomId
        super.init(nibName: nil, bundle: nil)
    }
    
    deinit {
        LiveKitLog.info("\(#file)", "\(#line)", "deinit AnchorPrepareViewController \(self)")
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private lazy var rootView: AnchorPrepareView = {
        let view = AnchorPrepareView(roomId: roomId)
        view.delegate = self
        return view
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func loadView() {
        view = rootView
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        let isPortrait = size.width < size.height
        rootView.updateRootViewOrientation(isPortrait: isPortrait)
    }
}

let transitionWindow: UIWindow = {
    let window = UIWindow(frame: UIScreen.main.bounds)
    window.windowScene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
    window.windowLevel = .statusBar - 1
    window.backgroundColor = .clear
    return window
}()

extension AnchorPrepareViewController: AnchorPrepareViewDelegate {
    func onClickBackButton() {
        if let nav = navigationController {
            nav.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
        AudioEffectStore.shared.reset()
        DeviceStore.shared.reset()
        BaseBeautyStore.shared.reset()
    }
    
    func onClickStartButton(state: PrepareState) {
        guard let rootVC = WindowUtils.getCurrentWindow()?.rootViewController else { return }
        let tmpView: UIView
        if let snapshot = rootView.snapshotView(afterScreenUpdates: true) {
            tmpView = snapshot
        } else {
            tmpView = rootView
        }
        transitionWindow.addSubview(tmpView)
        tmpView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        transitionWindow.alpha = 1
        transitionWindow.isHidden = false
        
        dismiss(animated: false) { [weak self, weak rootVC] in
            guard let self = self, let rootVC = rootVC else { return }
            
            let param = LiveParams(liveID: roomId, prepareState: state)
            let anchorVC = AnchorViewController(liveParams: param, coreView: rootView.getCoreView(), behavior: .createRoom)
            anchorVC.modalPresentationStyle = .fullScreen

            willStartLive?(anchorVC)
            
            rootVC.present(anchorVC, animated: false) {
                UIView.animate(withDuration: 0.3) {
                    transitionWindow.alpha = 0
                } completion: { _ in
                    transitionWindow.subviews.forEach { $0.safeRemoveFromSuperview() }
                    transitionWindow.isHidden = true
                }
            }
        }
    }
}
