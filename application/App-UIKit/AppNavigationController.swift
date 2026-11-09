//
//  AppNavigationController.swift
//  App-UIKit
//
//  Created by yukiwwwang on 2025/8/11.
//

import UIKit

class AppNavigationController: UINavigationController {
    override init(rootViewController: UIViewController) {
        super.init(rootViewController: rootViewController)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        guard let supportedInterfaceOrientations =
                topViewController?.supportedInterfaceOrientations as? UIInterfaceOrientationMask
        else { return .portrait }
        return supportedInterfaceOrientations
    }
    override var shouldAutorotate: Bool {
        guard let shouldAutorotate = topViewController?.shouldAutorotate else { return false }
        return shouldAutorotate
    }
}
