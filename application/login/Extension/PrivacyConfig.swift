//
//  PrivacyConfig.swift
//  Login
//
//  隐私合规 URL 配置（Login Pod 内部副本）
//  从 Bundle.main 中读取 Privacy.plist，提供隐私/用户协议链接
//

import Foundation

/// 隐私合规配置路径
private let Privacy_PlistPath: String? = {
    return Bundle.main.path(forResource: "Privacy", ofType: "plist")
}()

/// 隐私合规配置信息
private let Privacy_Info: NSDictionary = {
    guard let privacyPath = Privacy_PlistPath,
          let privacyInfo = NSDictionary(contentsOfFile: privacyPath) else {
        return NSDictionary()
    }
    return privacyInfo
}()

/// 用户协议
let WEBURL_Agreement: String = {
    return (Privacy_Info["userProtocolURL"] as? String) ?? ""
}()

/// 隐私协议摘要
let WEBURL_PrivacySummary: String = {
    return (Privacy_Info["privacySummaryURL"] as? String) ?? ""
}()

/// 隐私协议
let WEBURL_Privacy: String = {
    return (Privacy_Info["privacyURL"] as? String) ?? ""
}()

/// 个人信息收集清单
let WEBURL_DataCollection: String = {
    return (Privacy_Info["dataCollectionURL"] as? String) ?? ""
}()

/// 第三方信息共享清单
let WEBURL_ThirdShare: String = {
    return (Privacy_Info["thirdShareURL"] as? String) ?? ""
}()
