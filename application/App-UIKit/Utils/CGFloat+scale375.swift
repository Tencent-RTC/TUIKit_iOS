//
//  CGFloat+scale375.swift
//  App-UIKit
//
//  Created by yukiwwwang on 2025/8/14.
//

import UIKit

extension CGFloat {
    public func scale375Width(exceptPad: Bool = true) -> CGFloat {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return exceptPad ? self * 1.5 : self * (screenWidth / 375.00)
        }
        return self * (screenWidth / 375.00)
    }
    
    public func scale375Height(exceptPad: Bool = true) -> CGFloat {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return exceptPad ? self * 1.5 : self * (screenHeight / 812.00)
        }
        
        return self * (screenHeight / 812.0)
    }
}
