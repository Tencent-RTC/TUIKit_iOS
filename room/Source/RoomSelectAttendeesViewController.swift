//
//  RoomSelectAttendeesViewController.swift
//  TUIRoomKit
//
//  Created by adamsfliu on 2026/7/29.
//  Copyright © 2026 Tencent. All rights reserved.
//
//

import UIKit
import AtomicXCore

public class RoomSelectAttendeesViewController: UIViewController, RouterContext {
    
    // MARK: - Public API
    
    public var onConfirm: (([ContactInfo]) -> Void)? {
        didSet { attendeesView.onConfirm = onConfirm }
    }
    
    // MARK: - Properties
    
    private let initialSelectedUserIDs: [String]
    
    private lazy var attendeesView: RoomSelectAttendeesView = {
        let view = RoomSelectAttendeesView(initialSelectedUserIDs: initialSelectedUserIDs)
        view.routerContext = self
        return view
    }()
    
    // MARK: - Init
    
    public init(initialSelectedUserIDs: [String]) {
        self.initialSelectedUserIDs = initialSelectedUserIDs
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    public override func loadView() {
        view = attendeesView
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
