//
//  MineViewModel.swift
//  App-UIKit
//
//  Created by yukiwwwang on 2025/8/12.
//

import Foundation
import UIKit
import TUICore

enum MineListType {
    case settings
    case log
}

class MineViewModel: NSObject {    
    lazy var tableDataSource: [MineTableViewCellModel] = {
        var result: [MineTableViewCellModel] = []
        tableTypeSource.forEach { (type) in
            switch type {
            case .settings:
                let model = MineTableViewCellModel(title: ("Settings").localized,
                                                   image: UIImage(named: "mine_setting"), type: type)
                result.append(model)
            case .log:
                let model = MineTableViewCellModel(title: ("Log").localized,
                                                   image: UIImage(named: "mine_log"), type: type)
                result.append(model)
            }
        }
        return result
    }()
    
    private lazy var tableTypeSource: [MineListType] = {
        return [.settings, .log]
    }()
    
    func validate(userName: String) -> Bool {
        let reg = "^[a-z0-9A-Z\\u4e00-\\u9fa5\\_]{2,20}$"
        let predicate = NSPredicate(format: "SELF MATCHES %@", reg)
        return predicate.evaluate(with: userName)
    }
}
