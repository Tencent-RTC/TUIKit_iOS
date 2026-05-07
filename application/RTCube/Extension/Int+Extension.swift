//
//  Int+Extension.swift
//  RTCube
//

import UIKit

extension Int {
    func scale375() -> CGFloat {
        return CGFloat(self).scale375()
    }
    func scale375Width() -> CGFloat {
        return CGFloat(self).scale375Width()
    }
    func scale375Height() -> CGFloat {
        return CGFloat(self).scale375Height()
    }
}
