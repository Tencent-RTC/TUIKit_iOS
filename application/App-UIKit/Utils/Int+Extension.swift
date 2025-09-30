//
//  Int+Extension.swift
//  App-UIKit
//
//  Created by yukiwwwang on 2025/8/14.
//

import UIKit

extension Int {
    public func scale375Width(exceptPad: Bool = true) -> CGFloat {
        return CGFloat(self).scale375Width()
    }
    
    public func scale375Height(exceptPad: Bool = true) -> CGFloat {
        return CGFloat(self).scale375Height()
    }
}

