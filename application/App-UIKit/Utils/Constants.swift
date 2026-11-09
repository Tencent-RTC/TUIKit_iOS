//
//  Constants.swift
//  App-UIKit
//
//  Created by yukiwwwang on 2025/8/14.
//

import Foundation
import UIKit

// MARK: - 屏幕尺寸和设备常量
public let screenWidth = UIScreen.main.bounds.width
public let screenHeight = UIScreen.main.bounds.height

public let kDeviceIsIphoneX : Bool = {
    if UIDevice.current.userInterfaceIdiom == .pad {
        return false
    }
    let size = UIScreen.main.bounds.size
    let notchValue = Int(size.width/size.height*100)
    if notchValue == 216 || notchValue == 46 {
        return true
    }
    return false
}()

public let kDeviceSafeTopHeight : CGFloat = {
    if kDeviceIsIphoneX {
        return 44
    }
    else {
        return 20
    }
}()

public let kDeviceSafeBottomHeight : CGFloat = {
    if kDeviceIsIphoneX {
        return 34
    }
    else {
        return 0
    }
}()


public let DEFAULT_AVATAR: String = "https://imgcache.qq.com/qcloud/public/static//avatar1_100.20191230.png"
public let DEFAULT_COVER: String = "https://imgcache.qq.com/qcloud/public/static//avatar1_100.20191230.png"
public let PURCHASE_URL = "https://cloud.tencent.com/document/product/1640/79968"
public let ACCESS_URL = "https://cloud.tencent.com/document/product/1640/81131"
public let API_URL = "https://cloud.tencent.com/document/product/1640/79996"
public let PROBLEM_URL = "https://cloud.tencent.com/document/product/1640/81148"
public let IM_GROUP_MANAGER = "https://cloud.tencent.com/document/product/269/75394#.E5.88.9B.E5.BB.BA.E7.BE.A4.E7.BB.84"
public let DEFAULT_AVATAR_REGISTER: String = "https://liteav.sdk.qcloud.com/app/res/picture/voiceroom/avatar/user_avatar1.png"
