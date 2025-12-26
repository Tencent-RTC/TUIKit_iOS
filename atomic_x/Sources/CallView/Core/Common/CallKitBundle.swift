//
//  Bundle.swift
//  Pods
//
//  Created by yukiwwwang on 2025/9/4.
//

import UIKit

class CallKitBundle: NSObject {
    static func getTUICallKitBundle() -> Bundle? {
        guard let url = Bundle.main.url(forResource: "AtomicXBundle", withExtension: "bundle") else { return nil }
        return Bundle(url: url)
    }
    static func getBundleImage(name: String) -> UIImage? {
        return UIImage(named: name, in: getTUICallKitBundle(), compatibleWith: nil)
    }
    static func localizedString(forKey key: String, table: String = "CallKitLocalizable") -> String {
        guard let bundle = getTUICallKitBundle() else {
            return key
        }
        var localizedString = bundle.localizedString(forKey: key, value: nil, table: table)
        if localizedString == key {
            localizedString = Bundle.main.localizedString(forKey: key, value: nil, table: table)
        }
        return localizedString
    }
}

class CallKitLocalization {
    static func localized(_ key: String) -> String {
        return CallKitBundle.localizedString(forKey: key)
    }
}
