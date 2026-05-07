//
//  TUIGlobalization+Extension.swift
//  RTCube
//

import UIKit
import TUICore

extension TUIGlobalization {

    public class func isChineseAppLocale() -> Bool {
        if let lang = self.getPreferredLanguage(), lang.hasPrefix("zh") {
            return true
        } else {
            return false
        }
    }

}
