//
//  MainItemModel.swift
//  TUILiveKitApp
//
//  Created by jack on 2024/10/8.
//

import Foundation
import UIKit
import RTCCommon

struct LiveMainItemModel {
    let imageName: String
    let title: String
    let content: String
    
    init(imageName: String, title: String, content: String) {
        self.imageName = imageName
        self.title = title
        self.content = content
    }

}
