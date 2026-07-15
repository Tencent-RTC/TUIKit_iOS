//
//  RoomMainViewController.swift
//  TUIRoomKit
//
//  Created on 2025/11/21.
//  Copyright © 2025 Tencent. All rights reserved.
//

import UIKit
import SnapKit

public class RoomMainViewController: UIViewController, RouterContext {
    // MARK: - Properties
    private let rootView: RoomMainView

    /// When `true`, the controller only allows landscape orientations;
    /// when `false` (default) only portrait is allowed.
    public var isLandscapeMode: Bool = false {
        didSet {
            if #available(iOS 16.0, *) {
                setNeedsUpdateOfSupportedInterfaceOrientations()
            } else {
                UIViewController.attemptRotationToDeviceOrientation()
            }
        }
    }
    
    // MARK: - Lifecycle
    
    public init(roomID: String, behavior: RoomBehavior, config: ConnectConfig) {
        rootView = RoomMainView(roomID: roomID, behavior: behavior, config: config)
        super.init(nibName: nil, bundle: nil)
        rootView.routerContext = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func loadView() {
        view = rootView
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        UIApplication.shared.isIdleTimerDisabled = false

        // Reset to portrait when leaving the room
        isLandscapeMode = false
        if #available(iOS 16.0, *) {
            setNeedsUpdateOfSupportedInterfaceOrientations()
            if let windowScene = view.window?.windowScene {
                let geometry = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .portrait)
                windowScene.requestGeometryUpdate(geometry)
            }
        } else {
            UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
            UIViewController.attemptRotationToDeviceOrientation()
        }
    }
    
    public override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return isLandscapeMode ? .landscape : .portrait
    }

    public override var shouldAutorotate: Bool {
        return false
    }

    public override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return isLandscapeMode ? .landscapeRight : .portrait
    }
}
