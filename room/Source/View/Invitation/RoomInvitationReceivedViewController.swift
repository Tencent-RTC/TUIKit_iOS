//
//  RoomInvitationReceivedViewController.swift
//  TUIRoomKit
//
//  Created by adamsfliu on 2026/8/5.
//  Copyright © 2026 Tencent. All rights reserved.
//

import UIKit
import AtomicXCore

public class RoomInvitationReceivedViewController: UIViewController, RouterContext {

    // MARK: - Properties
    private let roomInfo: RoomInfo
    private let caller: RoomUser

    // MARK: - Init
    public init(roomInfo: RoomInfo, caller: RoomUser) {
        self.roomInfo = roomInfo
        self.caller = caller
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle
    public override func loadView() {
        let view = RoomInvitationReceivedView(roomInfo: roomInfo, caller: caller)
        view.routerContext = self
        self.view = view
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    public override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }

    public override var shouldAutorotate: Bool {
        return false
    }

    public override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .portrait
    }
}
