//
//  RoomScheduleMenuItem.swift
//  TUIRoomKit
//
//  Created by adamsfliu on 2026/7/28.
//  Copyright © 2026 Tencent. All rights reserved.
//
//

import UIKit
import AtomicXCore

// MARK: - Card grouping

public enum RoomScheduleCardID: Int {
    case info      // room name / type / start time / duration / time zone / participants
    case security  // encryption toggle (+ optional password row)
    case control   // mute-all + disable-video
}

// MARK: - Menu identifiers

public enum RoomScheduleMenuID: String {
    case roomName
    case roomType
    case startTime
    case duration
    case timeZone
    case participants
    case encryption
    case password
    case muteAll
    case disableVideo
}

// MARK: - Menu kind

public enum RoomScheduleMenuKind {
    case accessory(chevron: RoomScheduleChevronDirection)
    case editableText(placeholder: String, keyboardType: UIKeyboardType)
    case switchToggle
}

// MARK: - Menu item

public struct RoomScheduleMenuItem {
    public let id: RoomScheduleMenuID
    public let card: RoomScheduleCardID
    public let title: String
    public let kind: RoomScheduleMenuKind
    public let value: String?
    public let valuePlaceholder: String?
    public let isOn: Bool
    public let tapAction: (() -> Void)?
    public let switchAction: ((Bool) -> Void)?
    public let commitTextAction: ((String) -> Void)?
    public let shouldAcceptTextChange: ((_ current: String,
                                          _ range: NSRange,
                                          _ replacement: String) -> Bool)?
    
    public init(id: RoomScheduleMenuID,
                card: RoomScheduleCardID,
                title: String,
                kind: RoomScheduleMenuKind,
                value: String? = nil,
                valuePlaceholder: String? = nil,
                isOn: Bool = false,
                tapAction: (() -> Void)? = nil,
                switchAction: ((Bool) -> Void)? = nil,
                commitTextAction: ((String) -> Void)? = nil,
                shouldAcceptTextChange: ((_ current: String,
                                           _ range: NSRange,
                                           _ replacement: String) -> Bool)? = nil) {
        self.id = id
        self.card = card
        self.title = title
        self.kind = kind
        self.value = value
        self.valuePlaceholder = valuePlaceholder
        self.isOn = isOn
        self.tapAction = tapAction
        self.switchAction = switchAction
        self.commitTextAction = commitTextAction
        self.shouldAcceptTextChange = shouldAcceptTextChange
    }
}
