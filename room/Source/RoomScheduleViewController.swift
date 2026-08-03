//
//  RoomScheduleViewController.swift
//  TUIRoomKit
//
//  Created by adamsfliu on 2026/7/28.
//  Copyright © 2026 Tencent. All rights reserved.
//

import UIKit
import AtomicXCore

public class RoomScheduleViewController: UIViewController, RouterContext {
    
    // MARK: - Properties

    public var onScheduled: ((RoomScheduleInfo) -> Void)? {
        didSet { scheduleView?.onScheduled = onScheduled }
    }
    
    private var scheduleView: RoomScheduleView?
    
    // MARK: - Lifecycle
    
    public override func loadView() {
        let view = RoomScheduleView()
        view.routerContext = self
        view.onScheduled = onScheduled
        scheduleView = view
        self.view = view
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
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
