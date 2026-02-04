//
//  CallKitViewController.swift
//  TUICallKit
//
//  Created by vincepzhang on 2022/12/30.
//
import Foundation
import UIKit
import TUICore
import AtomicX
import AtomicXCore
import Combine
import SnapKit
import RTCCommon
class CallMainViewController: UIViewController {
    private var cancellables = Set<AnyCancellable>()
    
    private lazy var mainView: CallView = {
        let view = CallView(frame: .zero)
        if !TUICallKitImpl.shared.globalState.enableAITranscriber {
            view.disableFeatures([.aiTranscriber])
        }
        return view
    }()
    
    private lazy var floatWindowButton: UIButton = {
        let button = UIButton(type: .system)
        if let image = CallKitBundle.getBundleImage(name: "icon_min_window") {
            button.setBackgroundImage(image, for: .normal)
        }
        button.isHidden = !TUICallKitImpl.shared.globalState.enableFloatWindow
        
        return button
    }()
    
    private lazy var inviteUserButton: UIButton = {
        let button = UIButton(type: .system)
        if let image = CallKitBundle.getBundleImage(name: "icon_add_user") {
            button.setBackgroundImage(image, for: .normal)
        }
        button.isHidden = true
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        KeyMetrics.countUV(eventId: .wakeup, callId: CallStore.shared.state.value.activeCall.callId)
        
        view.addSubview(mainView)
        view.addSubview(floatWindowButton)
        view.addSubview(inviteUserButton)
        
        activateConstraints()
        bindInteraction()
        subscribeCallState()
        updateInitialOrientation()
    }
    
    private func activateConstraints() {
        mainView.translatesAutoresizingMaskIntoConstraints = false
        floatWindowButton.translatesAutoresizingMaskIntoConstraints = false
        inviteUserButton.translatesAutoresizingMaskIntoConstraints = false
        
        mainView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        floatWindowButton.snp.makeConstraints { make in
            make.size.equalTo(24.scale375Width())
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(6.scale375Height())
            make.leading.equalToSuperview().offset(12.scale375Width())
        }
        
        inviteUserButton.snp.makeConstraints { make in
            make.size.equalTo(24.scale375Width())
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(12.scale375Height())
            make.trailing.equalToSuperview().offset(-12.scale375Width())
        }
    }
    
    private func bindInteraction() {
        floatWindowButton.addTarget(self, action: #selector(floatWindowTapped), for: .touchUpInside)
        inviteUserButton.addTarget(self, action: #selector(inviteUserTapped), for: .touchUpInside)
    }
    private func updateInitialOrientation() {
        if UIDevice.current.userInterfaceIdiom == .pad {
            switch TUICallKitImpl.shared.globalState.orientation {
            case .portrait:
                forceOrientation(false)
            case .landscape:
                forceOrientation(true)
            case .auto:
                break
            }
        }
    }
    
    override func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
        super.willTransition(to: newCollection, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            self.mainView.updateConstraints()
        }, completion: nil)
    }
    private func forceOrientation(_ isLandscape: Bool) {
        let orientationMask: UIInterfaceOrientationMask = isLandscape ? .landscapeRight : .portrait
        let orientation: UIDeviceOrientation = isLandscape ? .landscapeRight : .portrait
        if #available(iOS 16.0, *) {
            guard let scene = view.window?.windowScene else { return }
            let preferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: orientationMask)
            scene.requestGeometryUpdate(preferences) { error in
                debugPrint("forceOrientation: \(error.localizedDescription)")
            }
        } else {
            let value = isLandscape ? UIInterfaceOrientation.landscapeRight.rawValue : UIInterfaceOrientation.portrait.rawValue
            UIDevice.current.setValue(value, forKey: "orientation")
            UIViewController.attemptRotationToDeviceOrientation()
        }
    }
    
    private func subscribeCallState() {
        CallStore.shared.state
            .subscribe(StatePublisherSelector(keyPath: \.activeCall))
            .removeDuplicates { previous, current in
                return previous.chatGroupId == current.chatGroupId
            }
            .receive(on: RunLoop.main)
            .sink { [weak self] activeCall in
                guard let self = self else { return }
                let isMultiCall = !activeCall.chatGroupId.isEmpty
                self.inviteUserButton.isHidden = !isMultiCall
            }
            .store(in: &cancellables)
    }
    
    @objc private func floatWindowTapped() {
        WindowManager.shared.showFloatingWindow()
    }
    
    @objc private func inviteUserTapped() {
        let selectGroupMemberVC = SelectGroupMemberViewController()
        selectGroupMemberVC.modalPresentationStyle = .fullScreen
        getKeyWindow()?.rootViewController?.present(selectGroupMemberVC, animated: false)
    }
    
    private func getKeyWindow() -> UIWindow? {
        return UIApplication.shared.connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .compactMap { $0 as? UIWindowScene }
            .first?
            .windows
            .first(where: { $0.isKeyWindow })
    }
}

class CallKitNavigationController: UINavigationController {
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setNavigationBarHidden(true, animated: false)
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .pad {
            if TUICallKitImpl.shared.globalState.orientation == .auto {
                return .all
            } else if TUICallKitImpl.shared.globalState.orientation == .landscape {
                return .landscape
            }
        } else {
            return .portrait
        }
        return .portrait
    }
    
    override var shouldAutorotate: Bool {
        if UIDevice.current.userInterfaceIdiom == .pad && TUICallKitImpl.shared.globalState.orientation == .auto {
            return true
        } else {
            return false
        }
    }
}
