//
//  RoomJoinViewController.swift
//  TUIRoomKit
//
//  Created on 2025/11/13.
//  Copyright © 2025 Tencent. All rights reserved.
//

import UIKit

public class RoomJoinViewController: UIViewController, RouterContext {
    
    // MARK: - Properties
    
    private lazy var rootView: RoomJoinView = {
        let view = RoomJoinView()
        view.routerContext = self
        return view
    }()
    
    // MARK: - Lifecycle
    public override func loadView() {
        view = rootView
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
}
