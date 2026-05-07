//
//  CallingRequestRobotModel.swift
//  main
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
