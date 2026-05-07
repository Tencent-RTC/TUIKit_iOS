//
//  PrivacyConfig.swift
//  Login
//

import Foundation

private let Privacy_PlistPath: String? = {
    return Bundle.main.path(forResource: "Privacy", ofType: "plist")
}()

private let Privacy_Info: NSDictionary = {
    guard let privacyPath = Privacy_PlistPath,
          let privacyInfo = NSDictionary(contentsOfFile: privacyPath) else {
        return NSDictionary()
    }
    return privacyInfo
}()

let WEBURL_Agreement: String = {
    return (Privacy_Info["userProtocolURL"] as? String) ?? ""
}()

let WEBURL_PrivacySummary: String = {
    return (Privacy_Info["privacySummaryURL"] as? String) ?? ""
}()

let WEBURL_Privacy: String = {
    return (Privacy_Info["privacyURL"] as? String) ?? ""
}()
