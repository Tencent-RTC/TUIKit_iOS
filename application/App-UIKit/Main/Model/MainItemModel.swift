//
//  MainItemModel.swift
//  App-UIKit
//
//  Created by yukiwwwang on 2025/8/7.
//
import Foundation
import UIKit
import RTCCommon

let imageWidth: CGFloat = 172
let titleFontSize: CGFloat = 17
let contentFontSize: CGFloat = 13

struct MainMenuItemModel {
    let imageName: String
    let title: String
    let content: String
    var unreadCount: UInt64 = 0
    let selectHandle: () -> Void
    let gradientColors: [UIColor]
    let isHotKit: Bool
    var iconImage: UIImage? {
        UIImage(named: imageName)
    }
    
    init(imageName: String,
         title: String,
         content: String,
         isHotKit: Bool = false,
         gradientColors:[UIColor] = [],
         selectHandle: @escaping () -> Void) {
        self.imageName = imageName
        self.title = title
        self.content = content
        self.isHotKit = isHotKit
        self.selectHandle = selectHandle
        self.gradientColors = gradientColors
    }
}
