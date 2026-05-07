//
//  MineEntry.swift
//  mine
//
//    let mineVC = MineEntry.shared.buildMineViewController(
//        onLogout: { ... },
//        onLanguageChanged: { ... },
//        onExperienceRoomClicked: { ... }
//    )
//    navigationController?.pushViewController(mineVC, animated: true)
//

import UIKit
import Login

public final class MineEntry {
    public static let shared = MineEntry()
    private init() {}
    
    public func buildMineViewController(
        onLogout: @escaping () -> Void,
        onLanguageChanged: ((String) -> Void)? = nil,
        onExperienceRoomClicked: (() -> Void)? = nil
    ) -> UIViewController {
        let vc = MineViewController()
        vc.onLogout = onLogout
        vc.onLanguageChanged = onLanguageChanged
        vc.onExperienceRoomClicked = onExperienceRoomClicked
        return vc
    }
}
