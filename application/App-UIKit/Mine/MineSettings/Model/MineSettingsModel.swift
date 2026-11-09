//
//  MineSettingsModel.swift
//  App-UIKit
//
//  Created by yukiwwwang on 2025/8/13.
//
import UIKit

class MineSettingsModel: NSObject {
    let title: String
    init(title: String, value: String = "") {
        self.title = title
        super.init()
    }
}
