//
//  RoomScheduleDetailViewController.swift
//  TUIRoomKit
//
//  Created by adamsfliu on 2026/7/30.
//  Copyright © 2026 Tencent. All rights reserved.
//
//

import UIKit
import AtomicXCore

public class RoomScheduleDetailViewController: UIViewController, RouterContext {

    // MARK: - Properties

    private let roomInfo: RoomInfo
    private let timeZone: TimeZone
    private var detailView: RoomScheduleDetailView?

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
        let view = RoomScheduleDetailView(roomInfo: roomInfo, timeZone: timeZone)
        view.routerContext = self
        view.onEnterRoom = { [weak self] info in
            self?.enterRoom(info)
        }
        view.onModify = { [weak self] info in
            self?.editRoom(info)
        }
        detailView = view
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

    // MARK: - Private

    private func enterRoom(_ info: RoomInfo) {
        let config = ConnectConfig(autoEnableCamera: false)
        let mainViewController = RoomMainViewController(roomID: info.roomID,
                                                        behavior: .join,
                                                        config: config)
        push(mainViewController, animated: true)
    }

    private func editRoom(_ info: RoomInfo) {
        let editViewController = RoomScheduleEditViewController(roomInfo: info, timeZone: timeZone)
        editViewController.onUpdated = { [weak self] in
            self?.detailView?.refreshAttendees()
        }
        push(editViewController, animated: true)
    }
}
