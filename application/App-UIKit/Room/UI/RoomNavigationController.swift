//
//  RoomNavigationController.swift
//  App-UIKit
//
//  Created by yukiwwwang on 2025/8/20.
//

import Foundation
import UIKit

class RoomNavigationController: UINavigationController {
    override init(rootViewController: UIViewController) {
        super.init(rootViewController: rootViewController)
        interactivePopGestureRecognizer?.isEnabled = false
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        guard let supportedInterfaceOrientations = topViewController?.supportedInterfaceOrientations as? UIInterfaceOrientationMask
        else { return .portrait }
        return supportedInterfaceOrientations
    }
    override var shouldAutorotate: Bool {
        guard let shouldAutorotate = topViewController?.shouldAutorotate else { return false }
        return shouldAutorotate
    }
}
