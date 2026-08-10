//
//  RoomGlobalConfig.swift
//  TUIRoomKit
//
//  Created by adamsfliu on 2026/8/5.
//  Copyright © 2026 Tencent. All rights reserved.
//

import Foundation

// MARK: - Constants

private let TUI_ROOM_CALLING_BELL_KEY = "RoomCallingBell"
private let TUI_ROOM_ENABLE_MUTE_MODE_KEY = "RoomEnableMuteMode"
private let TUI_ROOM_ENABLE_VIBRATION_MODE_KEY = "RoomEnableVibrationMode"

public class RoomGlobalConfig {

    public static let shared = RoomGlobalConfig()

    // MARK: - Configuration (persisted via UserDefaults)

    private(set) var callingBellPath: String? = {
        UserDefaults.standard.object(forKey: TUI_ROOM_CALLING_BELL_KEY) as? String
    }()

    private(set) var enableMuteMode: Bool = {
        UserDefaults.standard.object(forKey: TUI_ROOM_ENABLE_MUTE_MODE_KEY) as? Bool ?? false
    }()

    private(set) var enableVibrationMode: Bool = {
        UserDefaults.standard.object(forKey: TUI_ROOM_ENABLE_VIBRATION_MODE_KEY) as? Bool ?? true
    }()

    private init() {}

    // MARK: - Configuration Setters

    public func setCallingBell(filePath: String) {
        UserDefaults.standard.set(filePath, forKey: TUI_ROOM_CALLING_BELL_KEY)
        UserDefaults.standard.synchronize()
        callingBellPath = filePath
    }

    public func enableMuteMode(_ enable: Bool) {
        UserDefaults.standard.set(enable, forKey: TUI_ROOM_ENABLE_MUTE_MODE_KEY)
        UserDefaults.standard.synchronize()
        enableMuteMode = enable
    }

    public func enableVibrationMode(_ enable: Bool) {
        UserDefaults.standard.set(enable, forKey: TUI_ROOM_ENABLE_VIBRATION_MODE_KEY)
        UserDefaults.standard.synchronize()
        enableVibrationMode = enable
    }
}
