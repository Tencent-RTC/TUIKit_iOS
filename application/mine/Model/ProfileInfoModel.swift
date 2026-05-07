//
//  ProfileInfoModel.swift
//  mine
//

import UIKit

class ProfileInfoModel: NSObject {
    var title: String?
    var detail: String?
    var imageName: String?
    var selectHandler: (() -> Void)?
    var cellHeight: CGFloat
    
    init(title: String? = nil,
         detail: String? = nil,
         imageName: String? = nil,
         cellHeight: CGFloat,
         selectHandler: (() -> Void)? = nil) {
        self.title = title
        self.detail = detail
        self.imageName = imageName
        self.selectHandler = selectHandler
        self.cellHeight = cellHeight
    }
}
