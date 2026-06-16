//
//  MineViewModel.swift
//  mine
//

import Foundation
import UIKit
import TUICore

enum MineListType {
    case privacy
    case disclaimer
    case icp
    case about
}

class MineViewModel: NSObject {
    
    private lazy var isRTCApp: Bool = {
        #if RTCUBE_OVERSEAS
        return true
        #else
        return false
        #endif
    }()
    
    lazy var tableDataSource: [MineTableViewCellModel] = {
        var res: [MineTableViewCellModel] = []
        tableTypeSource.forEach { type in
            switch type {
            case .privacy:
                let model = MineTableViewCellModel(title: MineLocalize("mine_info_privacy"),
                                                   image: UIImage(named: "main_mine_privacy"), type: type)
                res.append(model)
            case .disclaimer:
                let model = MineTableViewCellModel(title: MineLocalize("mine_info_statement"),
                                                   image: UIImage(named: "main_mine_disclaimer"), type: type)
                if !isRTCApp {
                    res.append(model)
                }
            case .icp:
                let model = MineTableViewCellModel(title: MineLocalize("mine_info_icp_number"),
                                                   image: UIImage(named: "main_mine_icp"), type: type)
                if !isRTCApp {
                    res.append(model)
                }
            case .about:
                let model = MineTableViewCellModel(title: MineLocalize("mine_info_about"),
                                                   image: UIImage(named: "main_mine_about"), type: type)
                res.append(model)
            }
        }
        return res
    }()
    
    lazy var tableTypeSource: [MineListType] = {
        return [.privacy, .disclaimer, .icp, .about]
    }()
    
    func validate(userName: String) -> Bool {
        let reg = "^[a-z0-9A-Z\\u4e00-\\u9fa5\\_]{2,20}$"
        let predicate = NSPredicate(format: "SELF MATCHES %@", reg)
        return predicate.evaluate(with: userName)
    }
}
