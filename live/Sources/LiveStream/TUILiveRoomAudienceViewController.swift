//
//  TUILiveRoomAudienceViewController.swift
//  TUILiveKit
//
//  Created by WesleyLei on 2023/12/11.
//
import UIKit
import AtomicXCore
import AtomicX
import RTCRoomEngine

public class TUILiveRoomAudienceViewController: UIViewController {
    
    private lazy var audienceView: AudienceView = {
        let view = AudienceView(roomId: roomId)
        view.delegate = self
        view.rotateScreenDelegate = self
        return view
    }()
    
    // MARK: - private property.
    var roomId: String
    private var orientation: UIDeviceOrientation = .portrait
    public init(roomId: String) {
        self.roomId = roomId
        super.init(nibName: nil, bundle: nil)
    }
    
    public init(liveInfo: TUILiveInfo) {
        self.roomId = liveInfo.roomInfo.roomId
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        LiveKitLog.info("\(#file)", "\(#line)", "deinit TUILiveRoomAudienceViewController \(self)")
        unregisterApplicationObserver()
    }
    
    public func leaveLive(onSuccess: (() -> Void)?, onError: ((ErrorInfo) -> Void)?) {
        audienceView.leaveLive(onSuccess: onSuccess, onError: onError)
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        constructViewHierarchy()
        activateConstraints()
        registerApplicationObserver()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: true)
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        UIApplication.shared.isIdleTimerDisabled = false
        navigationController?.setNavigationBarHidden(false, animated: true)
    }
    
    public override var shouldAutorotate: Bool {
        return false
    }
    
    public override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        switch orientation {
        case .landscapeRight:
            return .landscapeRight
        case .landscapeLeft:
            return .landscapeLeft
        default:
            return .portrait
        }
    }
    
    public override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        NotificationCenter.default.post(name: Notification.Name.TUILiveKitRotateScreenNotification, object: nil)
    }
        
    public func forceLandscapeMode() {
        orientation = .landscapeRight
        if #available(iOS 16.0, *) {
            setNeedsUpdateOfSupportedInterfaceOrientations()
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
                return
            }
            let preferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .landscapeRight)
            scene.requestGeometryUpdate(preferences) { error in
                debugPrint("forceLandscapeMode: \(error.localizedDescription)")
            }
        } else {
            let orientationValue: UIDeviceOrientation = .landscapeRight
            UIDevice.current.setValue(orientationValue.rawValue, forKey: "orientation")
            UIViewController.attemptRotationToDeviceOrientation()
        }
    }
    
    public func forcePortraitMode() {
        orientation = .portrait
        if #available(iOS 16.0, *) {
            setNeedsUpdateOfSupportedInterfaceOrientations()
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
                return
            }
            let preferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .portrait)
            scene.requestGeometryUpdate(preferences) { error in
                debugPrint("forcePortraitMode: \(error.localizedDescription)")
            }
        } else {
            let orientationValue: UIDeviceOrientation = .portrait
            UIDevice.current.setValue(orientationValue.rawValue, forKey: "orientation")
            UIViewController.attemptRotationToDeviceOrientation()
        }
    }

    @objc private func applicationWillEnterForeground() {
        if orientation == .landscapeRight {
            forceLandscapeMode()
        } else {
            forcePortraitMode()
        }
    }
}

extension TUILiveRoomAudienceViewController {
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
extension TUILiveRoomAudienceViewController: AudienceEndStatisticsViewDelegate {
    public func onCloseButtonClick() {
        if let nav = navigationController {
            nav.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }
}

extension TUILiveRoomAudienceViewController: AudienceViewDelegate {
    public func onLiveEnded(roomId: String, ownerName userName: String, ownerAvatarUrl avatarUrl: String) {
        let audienceEndView = AudienceEndStatisticsView(roomId: roomId, avatarUrl: avatarUrl, userName: userName)
        audienceEndView.delegate = self
        view.addSubview(audienceEndView)
        view.showAtomicToast(text: .liveHasStopText, style: .info)
        audienceEndView.snp.remakeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    public func onClickFloatWindow() {
        forcePortraitMode()
        FloatWindow.shared.showFloatWindow(controller: self, provider: audienceView)
    }
}

extension TUILiveRoomAudienceViewController: RotateScreenDelegate {
    public func rotateScreen(isPortrait: Bool) {
        if isPortrait  {
            forcePortraitMode()
        } else {
            forceLandscapeMode()
        }
    }
}

extension Notification.Name {
    static let TUILiveKitRotateScreenNotification = Notification.Name("TUILiveKitRotateScreenNotification")
}

fileprivate extension String {
    static let liveHasStopText = internalLocalized("common_live_has_stop")
}
