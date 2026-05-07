//
//  AtomicXCoreLogin.swift
//  RTCube
//
//  Created by gg on 2026/3/13.
//

import AtomicXCore
import Combine
import Login

class AtomicXCoreLogin {
    private var cancellable: AnyCancellable?

    static let shared = AtomicXCoreLogin()
    private init() {}

    func startAutoLogin() {
        guard cancellable == nil else { return }
        cancellable = LoginEntry.shared.$userModel
            .receive(on: RunLoop.main)
            .removeDuplicates(by: { lhs, rhs in
                lhs?.userId == rhs?.userId && lhs?.userSig == rhs?.userSig && lhs?.token == rhs?.token
            })
            .sink { userModel in
                if let userModel = userModel {
                    LoginStore.shared.login(sdkAppID: Int32(LoginEntry.shared.config.sdkAppId),
                                            userID: userModel.userId,
                                            userSig: userModel.userSig,
                                            completion: nil)
                } else {
                    LoginStore.shared.logout(completion: nil)
                }
            }
    }

    func stopAutoLogin() {
        cancellable = nil
    }
}
