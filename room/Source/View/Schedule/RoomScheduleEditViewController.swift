//
//  RoomScheduleEditViewController.swift
//  TUIRoomKit
//
//  Created by adamsfliu on 2026/7/30.
//  Copyright © 2026 Tencent. All rights reserved.
//
//

import UIKit
import AtomicXCore

public class RoomScheduleEditViewController: UIViewController, RouterContext {

    // MARK: - Properties
    
    public var onUpdated: (() -> Void)? {
        didSet { scheduleView?.onUpdated = onUpdated }
    }

    private let roomInfo: RoomInfo
    private let timeZone: TimeZone
    private var scheduleView: RoomScheduleView?

    // MARK: - Init

    public init(roomInfo: RoomInfo, timeZone: TimeZone = .current) {
        self.roomInfo = roomInfo
        self.timeZone = timeZone
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    public override func loadView() {
        let view = RoomScheduleView(editing: roomInfo, timeZone: timeZone)
        view.routerContext = self
        view.onUpdated = onUpdated
        scheduleView = view
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
