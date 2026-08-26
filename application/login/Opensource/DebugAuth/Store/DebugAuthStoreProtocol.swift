//
//  DebugAuthStoreProtocol.swift
//  login
//

import Combine
import Foundation

public struct HiddenConfigCredentials {
    public let sdkAppId: String
    public let userId: String
    public let userSig: String

    public init(sdkAppId: String, userId: String, userSig: String) {
        self.sdkAppId = sdkAppId
        self.userId = userId
        self.userSig = userSig
    }
}

protocol DebugAuthStoreProtocol: LoginSubStore {
    var state: DebugAuthState { get }
    var statePublisher: Published<DebugAuthState>.Publisher { get }
    var toastPublisher: AnyPublisher<String, Never> { get }
    var onNeedsRegister: (() -> Void)? { get set }

    func updateUserName(_ name: String)
    func login()
    func loginWithCredentials(_ credentials: HiddenConfigCredentials)
    func register(nickName: String)
    func updateAvatar(_ url: String)
}
