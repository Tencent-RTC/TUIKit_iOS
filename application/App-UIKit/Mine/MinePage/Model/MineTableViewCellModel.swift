//
//  MineTableViewCellModel.swift
//  App-UIKit
//
//  Created by yukiwwwang on 2025/8/12.
//

import Foundation
import Kingfisher

class MineTableViewCellModel: NSObject {
    let title: String
    let image: UIImage?
    let type: MineListType
    init(title: String, image: UIImage?, type: MineListType) {
        self.title = title
        self.image = image
        self.type = type
        super.init()
    }
}
