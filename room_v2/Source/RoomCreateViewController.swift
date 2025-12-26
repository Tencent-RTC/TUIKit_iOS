//
//  RoomCreateViewController.swift
//  TUIRoomKit
//
//  Created on 2025/11/12.
//  Copyright © 2025 Tencent. All rights reserved.
//

import UIKit

public class RoomCreateViewController: UIViewController, RouterContext {
    
    // MARK: - Properties
    
    private lazy var createView: RoomCreateView = {
        let view = RoomCreateView()
        view.routerContext = self
        return view
    }()
    
    // MARK: - Lifecycle
    
    public override func loadView() {
        view = createView
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
}
