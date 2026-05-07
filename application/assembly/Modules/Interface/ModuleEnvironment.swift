//
//  ModuleEnvironment.swift
//  AppAssembly
//

import Foundation
import Login

public struct ModuleEnvironment {
    public let beautyLicenseURL: String
    public let beautyLicenseKey: String
    
    public let getCurrentUserModel: () -> UserModel?
    public let generateUserSig: (_ userId: String) -> String
    
    public init(
        beautyLicenseURL: String = "",
        beautyLicenseKey: String = "",
        getCurrentUserModel: @escaping () -> UserModel?,
        generateUserSig: @escaping (String) -> String
    ) {
        self.beautyLicenseURL = beautyLicenseURL
        self.beautyLicenseKey = beautyLicenseKey
        self.getCurrentUserModel = getCurrentUserModel
        self.generateUserSig = generateUserSig
    }
}
