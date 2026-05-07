//
//  CallingRobotModel.swift
//  main
//

import UIKit

class CallingRobotModel: NSObject {
    let imageName: String
    let title: String
    let buttonIconImage: String
    let hasTopBorder: Bool
    let hasBotBorder: Bool
    let callType: CallBotType

    init(imageName: String, title: String,
         buttonIconImage: String,
         hasTopBorder: Bool,
         hasBotBorder: Bool,
         botCallType: CallBotType)
    {
        self.imageName = imageName
        self.title = title
        self.buttonIconImage = buttonIconImage
        self.hasTopBorder = hasTopBorder
        self.hasBotBorder = hasBotBorder
        self.callType = botCallType
    }
}
