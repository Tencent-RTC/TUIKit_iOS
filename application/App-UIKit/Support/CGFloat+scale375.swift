//
//  CGFloat+scale375.swift
//  RTCCommon
//
//  Created by krabyu on 2023/10/16.
//  Copyright © 2023 Tencent. All rights reserved.
//

import Foundation
import UIKit

private let shellLayoutWidth = min(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
private let shellLayoutHeight = max(UIScreen.main.bounds.width,UIScreen.main.bounds.height)

extension CGFloat {
    public func scale375Width(exceptPad: Bool = true) -> CGFloat {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return exceptPad ? self * 1.5 : self * (shellLayoutWidth / 375.00)
        }
        return self * (shellLayoutWidth / 375.00)
    }
    
    public func scale375Height(exceptPad: Bool = true) -> CGFloat {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return exceptPad ? self * 1.5 : self * (shellLayoutHeight / 812.00)
        }
        
        return self * (shellLayoutHeight / 812.0)
    }

    func scale375(exceptPad: Bool = true) -> CGFloat {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return exceptPad ? self * 1.5 : self * (shellLayoutWidth / 375.00)
        }
        return self * (shellLayoutWidth / 375.00)
    }
}

extension Int {
    public func scale375Width(exceptPad: Bool = true) -> CGFloat {
        return CGFloat(self).scale375Width()
    }
    
    public func scale375Height(exceptPad: Bool = true) -> CGFloat {
        return CGFloat(self).scale375Height()
    }

    public func scale375(exceptPad: Bool = true) -> CGFloat {
        return CGFloat(self).scale375Width()
    }
}
