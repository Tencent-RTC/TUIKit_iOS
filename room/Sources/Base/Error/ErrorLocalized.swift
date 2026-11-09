import Foundation

public final class ErrorLocalized {

    public enum Level {
        case silent
        case toast
    }

    public enum Rule: Int {
        case fallback = 0
        case unknown = -1
        case tooFrequent = -2
        case invalidParameter = -1001
        case notLoggedIn = -1002
        case serverError = 100001
        case serverInvalidParameter = 100002
        case ignored = 100100
        case unclassified = 100006
        case packageError = 100007
        case operationTooFrequent = 100012
        case illegalRoomID = -2105
        case illegalRoomName = -2107
        case roomExists = 100003
        case roomNotFound = 100004
        case roomFull = 100008
        case roomAlreadyExists = 100011
        case sensitiveWord = 100026
        case passwordRequired = 100018
        case wrongPassword = 100019
        case cameraStartFailed = -1100
        case cameraNoPermission = -1101
        case cameraOccupied = -1102
        case cameraNoDevice = -1103
        case micStartFailed = -1104
        case micNoPermission = -1105
        case micOccupied = -1106
        case micNoDevice = -1107
        case screenShareSourceUnavailable = -1108
        case screenShareFailed = -1109
        case audioInterrupted = -1110
        case allMicDisabled = -2361
        case allCameraDisabled = -2371
        case screenShareOwnerAdminOnly = -2373
        case screenShareUnsupported = 12061
        case adminLimit = 100020
        case chatMutedAll = -2380
        case chatMuted = 100017
        case packageUnavailable = 101072

        public var level: Level {
            self == .ignored ? .silent : .toast
        }

        var messageKey: String {
            switch self {
            case .tooFrequent, .operationTooFrequent:
                return "roomkit.error.too_frequent"
            case .invalidParameter, .serverInvalidParameter:
                return "roomkit.error.invalid_parameter"
            case .notLoggedIn:
                return "roomkit.error.not_logged_in"
            case .serverError:
                return "roomkit.error.server"
            case .packageError, .packageUnavailable:
                return "roomkit.error.package"
            case .illegalRoomID:
                return "roomkit.entry.failure.illegal_room_id"
            case .illegalRoomName:
                return "roomkit.entry.failure.illegal_room_name"
            case .roomExists, .roomAlreadyExists:
                return "roomkit.entry.failure.room_exists"
            case .roomNotFound:
                return "roomkit.entry.failure.room_not_found"
            case .roomFull:
                return "roomkit.entry.failure.room_full"
            case .sensitiveWord:
                return "roomkit.entry.failure.sensitive_word"
            case .passwordRequired:
                return "roomkit.entry.failure.password_required"
            case .wrongPassword:
                return "roomkit.entry.failure.wrong_password"
            case .cameraStartFailed:
                return "roomkit.device.camera_start_failed"
            case .cameraNoPermission:
                return "roomkit.device.camera_no_permission"
            case .cameraOccupied:
                return "roomkit.device.camera_occupied"
            case .cameraNoDevice:
                return "roomkit.device.camera_no_device"
            case .micStartFailed:
                return "roomkit.device.mic_start_failed"
            case .micNoPermission:
                return "roomkit.device.mic_no_permission"
            case .micOccupied:
                return "roomkit.device.mic_occupied"
            case .micNoDevice:
                return "roomkit.device.mic_no_device"
            case .screenShareSourceUnavailable:
                return "roomkit.screen_share.failure.source_unavailable"
            case .screenShareFailed:
                return "roomkit.screen_share.failure.failed"
            case .audioInterrupted:
                return "roomkit.device.audio_interrupted"
            case .allMicDisabled:
                return "roomkit.device.all_mic_disabled"
            case .allCameraDisabled:
                return "roomkit.device.all_cam_disabled"
            case .screenShareOwnerAdminOnly:
                return "roomkit.screen_share.failure.owner_admin_only"
            case .screenShareUnsupported:
                return "roomkit.screen_share.failure.unsupported"
            case .adminLimit:
                return "roomkit.participants.failure.admin_limit"
            case .chatMutedAll:
                return "roomkit.chat.muted_all"
            case .chatMuted:
                return "roomkit.chat.muted"
            default:
                return ErrorLocalized.fallbackKey
            }
        }
    }

    private static let fallbackKey = "roomkit.error.default"

    public static func rule(code: Int) -> Rule {
        Rule(rawValue: code) ?? .fallback
    }

    public static func message(code: Int) -> String {
        RoomKitResources.localizedString(rule(code: code).messageKey)
    }

    public static func showError(code: Int, message: String) {
        NSLog("[RoomKitError] code=%d message=%@", code, message)
        show(code: code)
    }

    public static func show(code: Int) {
        let rule = rule(code: code)
        switch rule.level {
        case .silent:
            break
        case .toast:
            RoomToast.show(RoomKitResources.localizedString(rule.messageKey))
        }
    }
}
