import Foundation

///
///
public enum ErrorLocalized {

    public enum Level {
        case silent
        case toast
    }

    public struct Rule {
        public let level: Level
        let messageKey: String
    }

    private static let fallbackKey = "roomkit.error.default"

    private static let rules: [Int: Rule] = [
        -1: Rule(level: .toast, messageKey: "roomkit.error.default"),
        -2: Rule(level: .toast, messageKey: "roomkit.error.too_frequent"),
        -1001: Rule(level: .toast, messageKey: "roomkit.error.invalid_parameter"),
        -1002: Rule(level: .toast, messageKey: "roomkit.error.not_logged_in"),
        100001: Rule(level: .toast, messageKey: "roomkit.error.server"),
        100002: Rule(level: .silent, messageKey: fallbackKey),
        100006: Rule(level: .toast, messageKey: fallbackKey),
        100007: Rule(level: .toast, messageKey: "roomkit.error.package"),
        100012: Rule(level: .toast, messageKey: "roomkit.error.too_frequent"),

        -2105: Rule(level: .toast, messageKey: "roomkit.entry.failure.illegal_room_id"),
        -2107: Rule(level: .toast, messageKey: "roomkit.entry.failure.illegal_room_name"),
        100003: Rule(level: .toast, messageKey: "roomkit.entry.failure.room_exists"),
        100004: Rule(level: .toast, messageKey: "roomkit.entry.failure.room_not_found"),
        100008: Rule(level: .toast, messageKey: "roomkit.entry.failure.room_full"),
        100011: Rule(level: .toast, messageKey: "roomkit.entry.failure.room_exists"),
        100026: Rule(level: .toast, messageKey: "roomkit.entry.failure.sensitive_word"),

        -1109: Rule(level: .toast, messageKey: "roomkit.screen_share.failure.failed"),
        -2361: Rule(level: .toast, messageKey: "roomkit.device.all_mic_disabled"),
        -2371: Rule(level: .toast, messageKey: "roomkit.device.all_cam_disabled"),
        -2373: Rule(level: .toast, messageKey: "roomkit.screen_share.failure.owner_admin_only"),
        12061: Rule(level: .toast, messageKey: "roomkit.screen_share.failure.unsupported"),

        100020: Rule(level: .toast, messageKey: "roomkit.participants.failure.admin_limit"),

        101072: Rule(level: .toast, messageKey: "roomkit.recording.failure.not_enabled"),
    ]

    public static func rule(code: Int) -> Rule {
        rules[code] ?? Rule(level: .toast, messageKey: fallbackKey)
    }

    public static func message(code: Int) -> String {
        RoomKitResources.localizedString(rule(code: code).messageKey)
    }

    ///
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
