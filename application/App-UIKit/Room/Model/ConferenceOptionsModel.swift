//
//  ConferenceOptionsModel.swift
//  App-UIKit
//
//  Created by yukiwwwang on 2025/8/20.
//

import Foundation
import Factory

typealias ConferenceItemTapClosure = (UIButton) -> Void

struct ConferenceOptionInfo {
    let normalText: String
    let normalIcon: String
    let backgroundColor: String
    var tapAction: ConferenceItemTapClosure?
    init(normalText: String, normalIcon: String, backgroundColor: String, tapAction: ConferenceItemTapClosure? = nil) {
        self.normalText = normalText
        self.normalIcon = normalIcon
        self.backgroundColor = backgroundColor
    }
}

class ConferenceOptionsModel {
    func generateOptionsData() -> [ConferenceOptionInfo] {
        var options: [ConferenceOptionInfo] = []
        let enterRoom = ConferenceOptionInfo(normalText: .joinRoomText, normalIcon: "enter_conference", backgroundColor: "0x146EFA")
        options.append(enterRoom)
        
        let createRoom = ConferenceOptionInfo(normalText: .createRoomText, normalIcon: "create_conference", backgroundColor: "0x146EFA")
        options.append(createRoom)
        
        
        let scheduleRoom = ConferenceOptionInfo(normalText: .scheduleRoomText, normalIcon: "schedule_conference", backgroundColor: "0x146EFA")
        options.append(scheduleRoom)
        return options
    }
}

private extension String {
    static var joinRoomText: String {
        ("Join Room").localized
    }
    static var createRoomText: String {
        ("Create Room").localized
    }
    static var scheduleRoomText: String {
        ("Schedule Room").localized
    }
}

