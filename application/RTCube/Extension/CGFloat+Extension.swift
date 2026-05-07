//
//  CGFloat+Extension.swift
//  RTCube
//

import UIKit

let screenWidth = UIScreen.main.bounds.width
let screenHeight = UIScreen.main.bounds.height

extension CGFloat {
    func scale375() -> CGFloat {
        return self * UIScreen.main.bounds.width / 375.0
    }
    func scale375Width() -> CGFloat {
        return scale375()
    }
    func scale375Height() -> CGFloat {
        return self * UIScreen.main.bounds.height / 812.0
    }
}
