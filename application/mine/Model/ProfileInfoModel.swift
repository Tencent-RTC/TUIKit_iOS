//
//  ProfileInfoModel.swift
//  mine
//
//  个人资料数据模型 — 从旧版 iOS/App/RT-Cube/Mine/model/ProfileInfoModel.swift 迁移
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
