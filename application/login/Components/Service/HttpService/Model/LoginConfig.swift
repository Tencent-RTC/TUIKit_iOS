//
//  LoginConfig.swift
//  login
//

import Foundation

public struct LoginConfig: Equatable {
    public let httpBaseUrl: String
    
    public let isSetupService: Bool
    
    public let sdkAppId: Int
    
    public let apaasAppId: String
    
    public let secretKey: String
    
    public static let `default` = LoginConfig(
        httpBaseUrl: "",
        isSetupService: true,
        sdkAppId: 0,
        apaasAppId: "",
        secretKey: ""
    )
    
    public func withBaseUrl(_ newBaseUrl: String) -> LoginConfig {
        LoginConfig(
            httpBaseUrl: newBaseUrl,
            isSetupService: isSetupService,
            sdkAppId: sdkAppId,
            apaasAppId: apaasAppId,
            secretKey: secretKey
        )
    }
}
