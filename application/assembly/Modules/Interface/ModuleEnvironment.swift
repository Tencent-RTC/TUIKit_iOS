//
//  ModuleEnvironment.swift
//  AppAssembly
//

import Foundation
import Login

public struct ModuleEnvironment {
    public let liveLicenseURL: String
    public let liveLicenseKey: String
    public let effectLicenseURL: String
    public let effectLicenseKey: String
    public let playerLicenseURL: String
    public let playerLicenseKey: String
    public let copyrightedMusicLicenseKey: String
    public let copyrightedMusicLicenseUrl: String

    public let getCurrentUserModel: () -> UserModel?
    public let generateUserSig: (_ userId: String) -> String

    public init(
        liveLicenseURL: String = "",
        liveLicenseKey: String = "",
        effectLicenseURL: String = "",
        effectLicenseKey: String = "",
        playerLicenseURL: String = "",
        playerLicenseKey: String = "",
        copyrightedMusicLicenseKey: String = "",
        copyrightedMusicLicenseUrl: String = "",
        getCurrentUserModel: @escaping () -> UserModel?,
        generateUserSig: @escaping (String) -> String
    ) {
        self.liveLicenseURL = liveLicenseURL
        self.liveLicenseKey = liveLicenseKey
        self.effectLicenseURL = effectLicenseURL
        self.effectLicenseKey = effectLicenseKey
        self.playerLicenseURL = playerLicenseURL
        self.playerLicenseKey = playerLicenseKey
        self.copyrightedMusicLicenseKey = copyrightedMusicLicenseKey
        self.copyrightedMusicLicenseUrl = copyrightedMusicLicenseUrl
        self.getCurrentUserModel = getCurrentUserModel
        self.generateUserSig = generateUserSig
    }
}
