//
//  GuideModel.swift
//  main
//

import UIKit

enum AvartarType: Int, Codable {
    case right = 1
    case left = 2
}

class GuideModel: NSObject, Codable {
    let avartarType: AvartarType
    let text: String
    let name: String
    let leftContextImageName: String
    let rightContextImageName: String
    let hasCopyButton: Bool
    let avatarImageName: String
    init(avartarType: AvartarType,
         avatarImageName: String,
         name: String,
         hasCopyButton: Bool = false, text: String,
         contextImageName: String = "",
         rightContextImageName: String = "")
    {
        self.avartarType = avartarType
        self.avatarImageName = avatarImageName
        self.name = name
        self.text = text
        self.hasCopyButton = hasCopyButton
        self.leftContextImageName = contextImageName
        self.rightContextImageName = rightContextImageName
    }
}
