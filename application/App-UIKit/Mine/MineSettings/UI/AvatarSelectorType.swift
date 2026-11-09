//
//  AvatarSelectorType.swift
//  TIMCommon
//
//  Created by AI Assistant on 2025/10/10.
//  Copyright © 2025 Tencent. All rights reserved.
//

import Foundation

/// 头像选择类型枚举
enum AvatarSelectorType: Int {
    case userAvatar = 0                    // 用户头像
    case groupAvatar = 1                   // 群组头像
    case cover = 2                         // 封面
    case conversationBackgroundCover = 3   // 会话背景封面
}