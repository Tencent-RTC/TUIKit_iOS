//
//  ListCellItemModel.swift
//  App-UIKit
//
//  Created by yukiwwwang on 2025/8/20.
//

import Foundation
import UIKit

class ListCellItemModel {
    
    var titleText: String = ""
    var messageText: String = ""
    var fieldPlaceholderText: String = ""
    var fieldText: String = ""
    var fieldEnable: Bool = false
    var isSwitchOn: Bool = false
    var action: ((Any)->Void)?
    var normalIcon: String = ""
    var resourceBundle: Bundle = Bundle.main
    var hasSwitch: Bool = false
    var hasButton: Bool = false
    var hasFieldView: Bool = false
    var hasOverAllAction: Bool = false
    var size: CGSize?
    var backgroundColor: UIColor?
    var hasDownLineView: Bool = true
}
