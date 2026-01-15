//
//  ErrorLocalized.swift
//  TUILiveKit
//
//  Created by aby on 2024/3/11.
//

import Foundation
import RTCRoomEngine
import Combine
import ImSDK_Plus
import RTCCommon
import AtomicXCore

public protocol LocalizedError: Error {
    var description: String { get }
}

public typealias InternalError = ErrorLocalized.OperateError

public class ErrorLocalized {
    public static let generalErrorCode = -1
    
    deinit {
        debugPrint("deinit \(type(of: self))")
    }
    
    /// OperateError
    /// - property:
    ///     - error: TUIError, RoomEngine throw.
    ///     - message: RoomEngine throw
    ///     - localizedMessage: covert to localized string.
    ///     - actions: if you want to dispatch actions after receive error, append action to this property.
    ///     store will filter error action and dispath others.
    public struct OperateError: Error {
        let error: LocalizedError?
        let message: String
        var code: Int = 0
        public var localizedMessage: String {
            if let error = error {
                return error.description
            }
            return "\(internalLocalized("common_client_error_failed")):\(code)"
        }
        
        public init(error: LocalizedError, message: String) {
            self.error = error
            self.message = message
        }
        
        public init(code: Int, message: String) {
            if let err = LiveError(rawValue: code) {
                self.error = err
            } else {
                self.error = nil
                self.code = code
            }
            self.message = message
        }
        
        public init(errorInfo: ErrorInfo) {
            self.init(code: errorInfo.code, message: errorInfo.message)
        }
    }
}

public class UnknownError: Error {
    let rawValue: Int
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

extension UnknownError: LocalizedError {
    public var description: String {
        "\(internalLocalized("common_client_error_failed")):\(rawValue)"
    }
}

public enum TIMError: Int, Error {
    case success = 0
    case failed = -1
    case invalidUserId = 7_002
    case ERR_SDK_COMM_API_CALL_FREQUENCY_LIMIT = 7008
    case ERR_SVR_GROUP_SHUTUP_DENY = 10017
    case ERR_SDK_BLOCKED_BY_SENSITIVE_WORD = 7015
    case ERR_SDK_NET_PKG_SIZE_LIMIT = 9522
    case ERR_SDK_NET_DISCONNECT = 9508
    case ERR_SDK_NET_WAIT_ACK_TIMEOUT = 9520
    case ERR_SDK_NET_ALLREADY_CONN = 9509
    case ERR_SDK_NET_CONN_TIMEOUT = 9510
    case ERR_SDK_NET_CONN_REFUSE = 9511
    case ERR_SDK_NET_NET_UNREACH = 9512
    case ERR_SDK_NET_WAIT_INQUEUE_TIMEOUT = 9518
    case ERR_SDK_NET_WAIT_SEND_TIMEOUT = 9519
    case ERR_SDK_NET_WAIT_SEND_REMAINING_TIMEOUT = 9521
    case ERR_SDK_NET_WAIT_SEND_TIMEOUT_NO_NETWORK = 9523
    case ERR_SDK_NET_WAIT_ACK_TIMEOUT_NO_NETWORK = 9524
    case ERR_SDK_NET_SEND_REMAINING_TIMEOUT_NO_NETWORK = 9525
}

extension TIMError: LocalizedError {
    public var description: String {
        switch self {
        case .success:
            return internalLocalized("common_client_error_success")
        case .failed:
            return "\(internalLocalized("common_client_error_failed")):\(rawValue)"
        case .invalidUserId:
            return internalLocalized("live.error.invalid.userId")
        case .ERR_SDK_COMM_API_CALL_FREQUENCY_LIMIT:
            return internalLocalized("common_client_error_freq_limit")
        case .ERR_SVR_GROUP_SHUTUP_DENY:
            return internalLocalized("common_client_error_send_message_disabled_for_current")
        case .ERR_SDK_BLOCKED_BY_SENSITIVE_WORD:
            return internalLocalized("live_barrage_error_sensitive_word")
        case .ERR_SDK_NET_PKG_SIZE_LIMIT:
            return internalLocalized("live_barrage_error_content_is_long")
        case .ERR_SDK_NET_DISCONNECT,
                .ERR_SDK_NET_WAIT_ACK_TIMEOUT,
                .ERR_SDK_NET_ALLREADY_CONN,
                .ERR_SDK_NET_CONN_TIMEOUT,
                .ERR_SDK_NET_CONN_REFUSE,
                .ERR_SDK_NET_NET_UNREACH,
                .ERR_SDK_NET_WAIT_INQUEUE_TIMEOUT,
                .ERR_SDK_NET_WAIT_SEND_TIMEOUT,
                .ERR_SDK_NET_WAIT_SEND_REMAINING_TIMEOUT,
                .ERR_SDK_NET_WAIT_SEND_TIMEOUT_NO_NETWORK,
                .ERR_SDK_NET_WAIT_ACK_TIMEOUT_NO_NETWORK,
                .ERR_SDK_NET_SEND_REMAINING_TIMEOUT_NO_NETWORK:
            return internalLocalized("live_barrage_error_network")
        }
    }
}

extension TUIBattleCode: LocalizedError {
    public var description: String {
        switch self {
            case .unknown:
                return internalLocalized("common_client_error_failed")
            case .success:
                return internalLocalized("common_client_error_success")
            case .battlingOtherRoom:
                return internalLocalized("livestreamcore_battle_error_conflict")
            default:
                return internalLocalized("livestreamcore_battle_error_other")
        }
    }
}

extension TUIConnectionCode: LocalizedError {
    public var description: String {
        switch self {
        case .success:
            return internalLocalized("common_client_error_success")
        case .roomNotExist:
            return internalLocalized("live_error_connection_notexit")
        case .connecting:
            return internalLocalized("common_client_error_connection_connecting")
        case .connectingOtherRoom:
            return internalLocalized("common_connect_conflict")
        case .full:
            return internalLocalized("common_connection_room_full")
        case .retry:
            return internalLocalized("live_error_connection_retry")
        case .roomMismatch:
            return internalLocalized("live_error_room_mismatch")
        default:
            return internalLocalized("common_client_error_failed")
        }
    }
}

public enum LiveError: Int, Error {
    case success = 0
    case freqLimit = -2
    case repeatOperation = -3
    case roomMismatch = -4
    case sdkAppIDNotFound = -1000
    case invalidParameter = -1001
    case sdkNotInitialized = -1002
    case permissionDenied = -1003
    case requirePayment = -1004
    case cameraStartFail = -1100
    case cameraNotAuthorized = -1101
    case cameraOccupied = -1102
    case cameraDeviceEmpty = -1103
    case microphoneStartFail = -1104
    case microphoneNotAuthorized = -1105
    case microphoneOccupied = -1106
    case microphoneDeviceEmpty = -1107
    case getScreenSharingTargetFailed = -1108
    case startScreenSharingFailed = -1109
    case operationInvalidBeforeEnterRoom = -2101
    case exitNotSupportedForRoomOwner = -2102
    case operationNotSupportedInCurrentRoomType = -2103
    case roomIdInvalid = -2105
    case roomNameInvalid = -2107
    case alreadyInOtherRoom = -2108
    case userNotExist = -2200
    case userNeedOwnerPermission = -2300
    case userNeedAdminPermission = -2301
    case requestNoPermission = -2310
    case requestIdInvalid = -2311
    case requestIdRepeat = -2312
    case maxSeatCountLimit = -2340
    case seatIndexNotExist = -2344
    case openMicrophoneNeedSeatUnlock = -2360
    case openMicrophoneNeedPermissionFromAdmin = -2361
    case openCameraNeedSeatUnlock = -2370
    case openCameraNeedPermissionFromAdmin = -2371
    case openScreenShareNeedSeatUnlock = -2372
    case openScreenShareNeedPermissionFromAdmin = -2373
    case sendMessageDisabledForAll = -2380
    case sendMessageDisabledForCurrent = -2381
    case roomNotSupportPreloading = -4001
    case callInProgress = -6001
    case systemInternalError = 100001
    case paramIllegal = 100002
    case roomIdOccupied = 100003
    case roomIdNotExist = 100004
    case userNotEntered = 100005
    case insufficientOperationPermissions = 100006
    case noPaymentInformation = 100007
    case roomIsFull = 100008
    case tagQuantityExceedsUpperLimit = 100009
    case roomIdHasBeenUsed = 100010
    case roomIdHasBeenOccupiedByChat = 100011
    case creatingRoomsExceedsTheFrequencyLimit = 100012
    case exceedsTheUpperLimit = 100013
    case invalidRoomType = 100015
    case memberHasBeenBanned = 100016
    case memberHasBeenMuted = 100017
    case requiresPassword = 100018
    case roomEntryPasswordError = 100019
    case roomAdminQuantityExceedsTheUpperLimit = 100020
    case requestIdConflict = 100102
    case seatLocked = 100200
    case seatOccupied = 100201
    case alreadyOnTheSeatQueue = 100202
    case alreadyInSeat = 100203
    case notOnTheSeatQueue = 100204
    case allSeatOccupied = 100205
    case userNotInSeat = 100206
    case userAlreadyOnSeat = 100210
    case seatNotSupportLinkMic = 100211
    case emptySeatList = 100251
    case connectionNotExist = 100400
    case roomInConnection = 100401
    case pendingConnectionRequest = 100402
    case roomConnectedInOther = 100403
    case connectionOrBattleLimitExceeded = 100404
    case creatingConnectionTooFrequent = 100405
    case battleNotExistOrEnded = 100411
    case noRoomsInBattleIsValid = 100412
    case creatingBattleTooFrequently = 100413
    case roomNotInBattle = 100414
    case inOtherBattle = 100415
    case pendingBattleRequest = 100416
    case notAllowedCancelBattleForRoomInBattle = 100419
    case battleNotStart = 100420
    case battleHasEnded = 100421
    case metadataKeyExceedsLimit = 100500
    case metadataValueSizeExceedsByteLimit = 100501
    case metadataTotalValueSizeExceedsByteLimit = 100502
    case metadataNoValidKey = 100503
    case metadataKeySizeExceedsByteLimit = 100504
    case giftAbilityNotEnabled = 102001
    case giftNotExist = 102002
    case giftServerPreVerificationFailed = 102004
    
    // TIMError
    case ERR_SDK_COMM_TINYID_EMPTY = 7002
    case ERR_SDK_COMM_API_CALL_FREQUENCY_LIMIT = 7008
    case ERR_SVR_GROUP_SHUTUP_DENY = 10017
    case ERR_SDK_BLOCKED_BY_SENSITIVE_WORD = 7015
    case ERR_SDK_NET_PKG_SIZE_LIMIT = 9522
    case ERR_SDK_NET_DISCONNECT = 9508
    case ERR_SDK_NET_WAIT_ACK_TIMEOUT = 9520
    case ERR_SDK_NET_ALLREADY_CONN = 9509
    case ERR_SDK_NET_CONN_TIMEOUT = 9510
    case ERR_SDK_NET_CONN_REFUSE = 9511
    case ERR_SDK_NET_NET_UNREACH = 9512
    case ERR_SDK_NET_WAIT_INQUEUE_TIMEOUT = 9518
    case ERR_SDK_NET_WAIT_SEND_TIMEOUT = 9519
    case ERR_SDK_NET_WAIT_SEND_REMAINING_TIMEOUT = 9521
    case ERR_SDK_NET_WAIT_SEND_TIMEOUT_NO_NETWORK = 9523
    case ERR_SDK_NET_WAIT_ACK_TIMEOUT_NO_NETWORK = 9524
    case ERR_SDK_NET_SEND_REMAINING_TIMEOUT_NO_NETWORK = 9525
    case ERR_SVR_GROUP_NOT_FOUND = 10010
    case ERR_INVALID_PARAMETERS = 6017

}

extension LiveError: LocalizedError {
    public var description: String {
        switch self {
        case .success:
            return internalLocalized("common_client_error_success")
        case .freqLimit:
            return internalLocalized("common_client_error_freq_limit")
        case .repeatOperation:
            return internalLocalized("common_client_error_repeat_operation")
        case .sdkAppIDNotFound:
            return internalLocalized("common_client_error_sdk_app_id_not_found")
        case .invalidParameter:
            return internalLocalized("common_client_error_invalid_parameter")
        case .sdkNotInitialized:
            return internalLocalized("common_client_error_sdk_not_initialized")
        case .permissionDenied:
            return internalLocalized("common_client_error_permission_denied")
        case .requirePayment:
            return internalLocalized("common_client_error_require_payment")
        case .cameraStartFail:
            return internalLocalized("common_client_error_camera_start_fail")
        case .cameraNotAuthorized:
            return internalLocalized("common_client_error_camera_not_authorized")
        case .cameraOccupied:
            return internalLocalized("common_client_error_camera_occupied")
        case .cameraDeviceEmpty:
            return internalLocalized("common_client_error_camera_device_empty")
        case .microphoneStartFail:
            return internalLocalized("common_client_error_microphone_start_fail")
        case .microphoneNotAuthorized:
            return internalLocalized("common_client_error_microphone_not_authorized")
        case .microphoneOccupied:
            return internalLocalized("common_client_error_microphone_occupied")
        case .microphoneDeviceEmpty:
            return internalLocalized("common_client_error_microphone_device_empty")
        case .getScreenSharingTargetFailed:
            return internalLocalized("common_client_error_get_screen_sharing_target_failed")
        case .startScreenSharingFailed:
            return internalLocalized("common_client_error_start_screen_sharing_failed")
        case .operationInvalidBeforeEnterRoom:
            return internalLocalized("common_client_error_operation_invalid_before_enter_room")
        case .exitNotSupportedForRoomOwner:
            return internalLocalized("common_client_error_exit_not_supported_for_room_owner")
        case .operationNotSupportedInCurrentRoomType:
            return internalLocalized("common_client_error_operation_not_supported_in_current_room_type")
        case .roomIdInvalid:
            return internalLocalized("common_client_error_room_id_invalid")
        case .roomNameInvalid:
            return internalLocalized("common_client_error_room_name_invalid")
        case .alreadyInOtherRoom:
            return internalLocalized("common_client_error_already_in_other_room")
        case .userNotExist:
            return internalLocalized("common_client_error_user_not_exist")
        case .userNeedOwnerPermission:
            return internalLocalized("common_client_error_user_need_owner_permission")
        case .userNeedAdminPermission:
            return internalLocalized("common_client_error_user_need_admin_permission")
        case .requestNoPermission:
            return internalLocalized("common_client_error_request_no_permission")
        case .requestIdInvalid:
            return internalLocalized("common_client_error_request_id_invalid")
        case .requestIdRepeat:
            return internalLocalized("common_client_error_request_id_repeat")
        case .maxSeatCountLimit:
            return internalLocalized("common_client_error_max_seat_count_limit")
        case .seatIndexNotExist:
            return internalLocalized("common_client_error_seat_index_not_exist")
        case .openMicrophoneNeedSeatUnlock:
            return internalLocalized("common_client_error_open_microphone_need_seat_unlock")
        case .openMicrophoneNeedPermissionFromAdmin:
            return internalLocalized("common_client_error_open_microphone_need_permission_from_admin")
        case .openCameraNeedSeatUnlock:
            return internalLocalized("common_client_error_open_camera_need_seat_unlock")
        case .openCameraNeedPermissionFromAdmin:
            return internalLocalized("common_client_error_open_camera_need_permission_from_admin")
        case .openScreenShareNeedSeatUnlock:
            return internalLocalized("common_client_error_open_screen_share_need_seat_unlock")
        case .openScreenShareNeedPermissionFromAdmin:
            return internalLocalized("common_client_error_open_screen_share_need_permission_from_admin")
        case .sendMessageDisabledForAll:
            return internalLocalized("common_client_error_send_message_disabled_for_all")
        case .sendMessageDisabledForCurrent:
            return internalLocalized("common_client_error_send_message_disabled_for_current")
        case .roomNotSupportPreloading:
            return internalLocalized("common_client_error_room_not_support_preloading")
        case .callInProgress:
            return internalLocalized("common_server_error_call_in_progress")
        case .systemInternalError:  // 100001
            return internalLocalized("common_server_error_system_internal_error")
        case .paramIllegal:     // 100002
            return internalLocalized("common_server_error_param_illegal")
        case .roomIdOccupied:   // 100003
            return internalLocalized("common_server_error_room_id_exists")
        case .roomIdNotExist:   // 100004
            return internalLocalized("common_server_error_room_does_not_exist")
        case .userNotEntered:   // 100005
            return internalLocalized("common_server_error_not_a_room_member")
        case .insufficientOperationPermissions: // 100006
            return internalLocalized("common_server_error_insufficient_operation_permissions")
        case .noPaymentInformation: // 100007
            return internalLocalized("common_server_error_no_payment_information")
        case .roomIsFull:   // 100008
            return internalLocalized("common_server_error_room_is_full")
        case .tagQuantityExceedsUpperLimit: // 100009
            return internalLocalized("common_server_error_tag_quantity_exceeds_upper_limit")
        case .roomIdHasBeenUsed:    // 100010
            return internalLocalized("common_server_error_room_id_has_been_used")
        case .roomIdHasBeenOccupiedByChat:  // 100011
            return internalLocalized("common_server_error_room_id_has_been_occupied_by_chat")
        case .creatingRoomsExceedsTheFrequencyLimit:    // 100012
            return internalLocalized("common_server_error_creating_rooms_exceeds_the_frequency_limit")
        case .exceedsTheUpperLimit:     // 100013
            return internalLocalized("common_server_error_exceeds_the_upper_limit")
        case .invalidRoomType:  // 100015
            return internalLocalized("common_server_error_invalid_room_type")
        case .memberHasBeenBanned:  // 100016
            return internalLocalized("common_server_error_this_member_has_been_banned")
        case .memberHasBeenMuted:   // 100017
            return internalLocalized("common_server_error_this_member_has_been_muted")
        case .requiresPassword:     // 100018
            return internalLocalized("common_server_error_requires_password")
        case .roomEntryPasswordError:   // 100019
            return internalLocalized("common_server_error_room_entry_password_error")
        case .roomAdminQuantityExceedsTheUpperLimit:    // 100020
            return internalLocalized("common_server_error_room_admin_quantity_exceeds_the_upper_limit")
        case .requestIdConflict:    // 100102
            return internalLocalized("common_server_error_signal_request_conflict")
        case .seatLocked:   // 100200
            return internalLocalized("common_server_error_mic_seat_is_locked")
        case .seatOccupied:     // 100201
            return internalLocalized("common_server_error_seat_is_already_occupied")
        case .alreadyOnTheSeatQueue:    // 100202
            return internalLocalized("common_server_error_already_on_the_mic_queue")
        case .alreadyInSeat:    // 100203
            return internalLocalized("common_server_error_already_on_the_mic")
        case .notOnTheSeatQueue:    // 100204
            return internalLocalized("common_server_error_not_on_the_mic_queue")
        case .allSeatOccupied:  // 100205
            return internalLocalized("common_server_error_the_seats_are_all_taken")
        case .userNotInSeat:    // 100206
            return internalLocalized("common_server_error_not_on_the_mic_seat")
        case .userAlreadyOnSeat:    // 100210
            return internalLocalized("common_server_error_user_is_already_on_the_mic_seat")
        case .seatNotSupportLinkMic:    // 100211
            return internalLocalized("common_server_error_room_does_not_support_mic_ability")
        case .emptySeatList:    // 100251
            return internalLocalized("common_server_error_the_seat_list_is_empty")
        case .connectionNotExist:   // 100400
            return internalLocalized("common_server_error_connection_does_not_exist")
        case .roomInConnection:     // 100401
            return internalLocalized("common_server_error_room_is_in_connection")
        case .pendingConnectionRequest:     // 100402
            return internalLocalized("common_server_error_there_is_a_pending_connection_request")
        case .roomConnectedInOther:     // 100403
            return internalLocalized("common_server_error_is_connecting_with_other_rooms")
        case .connectionOrBattleLimitExceeded:  // 100404
            return internalLocalized("common_server_error_has_exceeded_the_limit_in_connection_or_battle")
        case .creatingConnectionTooFrequent:    // 100405
            return internalLocalized("common_server_error_creating_connections_too_frequent")
        case .battleNotExistOrEnded:    // 100411
            return internalLocalized("common_server_error_battle_does_not_exist_or_has_ended")
        case .noRoomsInBattleIsValid:   // 100412
            return internalLocalized("common_server_error_no_rooms_in_the_battle_is_valid")
        case .creatingBattleTooFrequently:  // 100413
            return internalLocalized("common_server_error_creating_battles_too_frequently")
        case .roomNotInBattle:  // 100414
            return internalLocalized("common_server_error_the_room_is_not_in_the_battle")
        case .inOtherBattle:    // 100415
            return internalLocalized("common_server_error_in_other_battle")
        case .pendingBattleRequest:     // 100416
            return internalLocalized("common_server_error_there_is_a_pending_battle_request")
        case .notAllowedCancelBattleForRoomInBattle:    // 100419
            return internalLocalized("common_server_error_is_not_allowed_to_cancel_battle_for_room_in_battle")
        case .battleNotStart:   // 100420
            return internalLocalized("common_server_error_not_started_yet")
        case .battleHasEnded:   // 100421
            return internalLocalized("common_server_error_battle_session_has_ended")
        case .metadataKeyExceedsLimit:  // 100500
            return internalLocalized("common_server_error_metadata_number_of_keys_exceeds_the_limit")
        case .metadataValueSizeExceedsByteLimit:  // 100501
            return internalLocalized("common_server_error_metadata_size_of_value_exceeds_the_limit")
        case .metadataTotalValueSizeExceedsByteLimit:  // 100502
            return internalLocalized("common_server_error_metadata_total_size_exceeds_the_limit")
        case .metadataNoValidKey:  // 100503
            return internalLocalized("common_server_error_metadata_no_valid_keys")
        case .metadataKeySizeExceedsByteLimit:  // 100504
            return internalLocalized("common_server_error_metadata_the_size_of_key_exceeds_the_maximum_byte_limit")
        case .giftAbilityNotEnabled: // 102001
            return internalLocalized("common_server_error_gift_ability_not_enabled")
        case .giftNotExist: // 102002
            return internalLocalized("common_server_error_gift_not_exist")
        case .giftServerPreVerificationFailed: // 102004
            return internalLocalized("common_server_error_gift_server_pre_verification_failed")
            
        // TIMError
        case .ERR_SDK_COMM_TINYID_EMPTY:
            return internalLocalized("live_invalid_userId")
        case .ERR_SDK_COMM_API_CALL_FREQUENCY_LIMIT:
            return internalLocalized("common_client_error_freq_limit")
        case .ERR_SVR_GROUP_SHUTUP_DENY:
            return internalLocalized("common_client_error_send_message_disabled_for_current")
        case .ERR_SDK_BLOCKED_BY_SENSITIVE_WORD:
            return internalLocalized("live_barrage_error_sensitive_word")
        case .ERR_SDK_NET_PKG_SIZE_LIMIT:
            return internalLocalized("live_barrage_error_content_is_long")
        case .ERR_SDK_NET_DISCONNECT,
                .ERR_SDK_NET_WAIT_ACK_TIMEOUT,
                .ERR_SDK_NET_ALLREADY_CONN,
                .ERR_SDK_NET_CONN_TIMEOUT,
                .ERR_SDK_NET_CONN_REFUSE,
                .ERR_SDK_NET_NET_UNREACH,
                .ERR_SDK_NET_WAIT_INQUEUE_TIMEOUT,
                .ERR_SDK_NET_WAIT_SEND_TIMEOUT,
                .ERR_SDK_NET_WAIT_SEND_REMAINING_TIMEOUT,
                .ERR_SDK_NET_WAIT_SEND_TIMEOUT_NO_NETWORK,
                .ERR_SDK_NET_WAIT_ACK_TIMEOUT_NO_NETWORK,
                .ERR_SDK_NET_SEND_REMAINING_TIMEOUT_NO_NETWORK:
            return internalLocalized("live_barrage_error_network")
            
        @unknown default:
            return internalLocalized("common_client_error_failed") + ":\(self.rawValue)"
        }
    }
}
