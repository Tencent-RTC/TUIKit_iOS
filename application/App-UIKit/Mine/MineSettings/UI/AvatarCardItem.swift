//
//  AvatarCardItem.swift
//  TIMCommon
//
//  Created by AI Assistant on 2025/10/10.
//  Copyright © 2025 Tencent. All rights reserved.
//

import UIKit

class AvatarCardItem: NSObject {
    var posterUrlStr: String?
    var isSelect: Bool = false
    var fullUrlStr: String?
    var isDefaultBackgroundItem: Bool = false
    var isGroupGridAvatar: Bool = false
    var createGroupType: String?
    var cacheGroupGridAvatarImage: UIImage?
    
    override init() {
        super.init()
    }
}