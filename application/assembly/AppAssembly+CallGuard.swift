//
//  AppAssembly+CallGuard.swift
//  AppAssembly
//

import AtomicXCore
import Toast_Swift
import UIKit

extension AppAssembly {

    // MARK: - Call Status Guard

    var canStartNewRoom: Bool {
        CallStore.shared.state.value.selfInfo.status == .none
    }

    func showCannotStartRoomToast() {
        guard let window = Self.keyWindow else { return }
        window.makeToast(AssemblyLocalize("Demo.TRTC.Common.cannotStartRoomDuringCall"))
    }

    private static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}
