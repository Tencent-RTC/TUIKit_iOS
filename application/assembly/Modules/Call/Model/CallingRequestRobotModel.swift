//
//  CallingRequestRobotModel.swift
//  main
//
//  通话模块 - Bot 接口返回的解析模型
//

import UIKit

struct CallingRequestRobotModel: Decodable {
    let errorCode: Int
    let errorMessage: String
    var data: CallingVirtualRobotArrayModel
}

struct CallingVirtualRobotArrayModel: Decodable {
    let virtualUsers: [CallingVirtualRobotModel?]?
}

struct CallingVirtualRobotModel: Decodable {
    let name: String?
    let avatar: String?
    let virtualUserId: String
}
