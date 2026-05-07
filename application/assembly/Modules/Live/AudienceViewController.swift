//
//  AudienceViewController.swift
//  TUILiveKit
//
//  Created by WesleyLei on 2023/12/11.
//
import AtomicX
import AtomicXCore
import RTCRoomEngine
import TUILiveKit
import UIKit

class AudienceViewController: UIViewController {
    private lazy var audienceView: AudienceView = {
        let view = AudienceView(roomId: roomId)
        view.delegate = self
        view.rotateScreenDelegate = self
        return view
    }()
    
    // MARK: - private property.

    var roomId: String
    private var orientation: UIDeviceOrientation = .portrait
    init(roomId: String) {
        self.roomId = roomId
        super.init(nibName: nil, bundle: nil)
    }
    
    init(liveInfo: TUILiveInfo) {
        self.roomId = liveInfo.roomInfo.roomId
        super.init(nibName: nil, bundle: nil)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        LiveKitLog.info("\(#file)", "\(#line)", "deinit AudienceViewController \(self)")
        unregisterApplicationObserver()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        constructViewHierarchy()
        activateConstraints()
        registerApplicationObserver()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: true)
        UIApplication.shared.isIdleTimerDisabled = true
        ThemeStore.shared.setMode(.dark)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        UIApplication.shared.isIdleTimerDisabled = false
        navigationController?.setNavigationBarHidden(false, animated: true)
    }
    
    override var shouldAutorotate: Bool {
        return false
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return [.portrait, .landscapeRight, .landscapeLeft]
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        NotificationCenter.default.post(name: Notification.Name.TUILiveKitRotateScreenNotification, object: nil)
    }
        
    func forceLandscapeMode() {
        if #available(iOS 16.0, *) {
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
                return
            }
            let preferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .landscape)
            scene.requestGeometryUpdate(preferences) { error in
                debugPrint("forceLandscapeMode: \(error.localizedDescription)")
            }
        } else {
            let orientation: UIDeviceOrientation = .landscapeRight
            UIDevice.current.setValue(orientation.rawValue, forKey: "orientation")
            UIViewController.attemptRotationToDeviceOrientation()
        }
        
        orientation = .landscapeRight
    }
    
    func forcePortraitMode() {
        if #available(iOS 16.0, *) {
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
                return
            }
            let preferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .portrait)
            scene.requestGeometryUpdate(preferences) { error in
                debugPrint("forcePortraitMode: \(error.localizedDescription)")
            }
        } else {
            let orientation: UIDeviceOrientation = .portrait
            UIDevice.current.setValue(orientation.rawValue, forKey: "orientation")
            UIViewController.attemptRotationToDeviceOrientation()
        }
        
        orientation = .portrait
    }

    @objc private func applicationWillEnterForeground() {
        if orientation == .landscapeRight {
            forceLandscapeMode()
        } else {
            forcePortraitMode()
        }
    }
}

extension AudienceViewController {
    private func constructViewHierarchy() {
        view.addSubview(audienceView)
    }
    
    private func activateConstraints() {
        audienceView.snp.remakeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    private func registerApplicationObserver() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applicationWillEnterForeground),
                                               name: UIApplication.willEnterForegroundNotification,
                                               object: nil)
    }
    
    private func unregisterApplicationObserver() {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - AudienceEndStatisticsViewDelegate

extension AudienceViewController: AudienceEndStatisticsViewDelegate {
    func onCloseButtonClick() {
        if let nav = navigationController {
            nav.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }
}

extension AudienceViewController: AudienceViewDelegate {
    func onLiveEnded(roomId: String, ownerName: String, ownerAvatarUrl: String) {
        let audienceEndView = AudienceEndStatisticsView(roomId: roomId, avatarUrl: ownerAvatarUrl, userName: ownerName)
        audienceEndView.delegate = self
        view.addSubview(audienceEndView)
        view.showAtomicToast(text: .liveHasStopText, style: .info)
        audienceEndView.snp.remakeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    func onClickFloatWindow() {
        ThemeStore.shared.setMode(.light)
        FloatWindow.shared.showFloatWindow(controller: self, provider: audienceView)
    }
}

extension AudienceViewController: RotateScreenDelegate {
    func rotateScreen(isPortrait: Bool) {
        if isPortrait {
            forcePortraitMode()
        } else {
            forceLandscapeMode()
        }
    }
}

extension Notification.Name {
    static let TUILiveKitRotateScreenNotification = Notification.Name("TUILiveKitRotateScreenNotification")
}

private extension String {
    static let liveHasStopText = AssemblyLocalize("Demo.TRTC.LiveRoom.liveHasStop")
}
