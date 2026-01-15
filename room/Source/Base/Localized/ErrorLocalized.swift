//
//  ErrorLocalized.swift
//  TUIRoomKit
//
//  Created by adamsfliu on 2025/12/3.
//

import Foundation
import RTCRoomEngine
import Combine
import ImSDK_Plus
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
            return "roomkit_err_general".localized + ":\(code)"
        }
        
        public init(error: LocalizedError, message: String) {
            self.error = error
            self.message = message
        }
        
        public init(code: Int, message: String) {
            if let err = RoomError(rawValue: code) {
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
        "roomkit_err_general".localized + ":\(rawValue)"
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
            return "roomkit_err_0_success".localized
        case .failed:
            return "roomkit_err_general".localized + ":\(rawValue)"
        case .invalidUserId:
            return "roomkit_err_7002_invalid_user_id".localized
        case .ERR_SDK_COMM_API_CALL_FREQUENCY_LIMIT:
            return "roomkit_err_7008_request_rate_limited".localized
        case .ERR_SVR_GROUP_SHUTUP_DENY:
            return "roomkit_err_10017_muted_in_room".localized
        case .ERR_SDK_BLOCKED_BY_SENSITIVE_WORD:
            return "roomkit_err_7015_sensitive_words".localized
        case .ERR_SDK_NET_PKG_SIZE_LIMIT:
            return "roomkit_err_9522_content_too_long".localized
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
            return "roomkit_err_network_error".localized
        }
    }
}



public enum RoomError: Int, Error {
    case success = 0
    case freqLimit = -2
    case repeatOperation = -3
    case roomMismatch = -4
    case sdkAppIDNotFound = -1000
    case invalidParameter = -1001
    case sdkNotInitialized = -1002
    case permissionDenied = -1003
    case requirePayment = -1004
    case invalidLicense = -1005
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
    case metadataKeyExceedsLimit = 100500
    case metadataValueSizeExceedsByteLimit = 100501
    case metadataTotalValueSizeExceedsByteLimit = 100502
    case metadataNoValidKey = 100503
    case metadataKeySizeExceedsByteLimit = 100504
    
    
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

extension RoomError: LocalizedError {
    public var description: String {
        switch self {
        case .success:
            return "roomkit_err_0_success".localized
        case .freqLimit:
            return "roomkit_err_n2_request_rate_limited".localized
        case .repeatOperation:
            return "roomkit_err_n3_repeat_operation".localized
        case .roomMismatch:
            return "roomkit_err_n4_roomID_not_match".localized
        case .sdkAppIDNotFound:
            return "roomkit_err_n1000_sdk_appid_not_found".localized
        case .invalidParameter:
            return "roomkit_err_n1001_invalid_parameter".localized
        case .sdkNotInitialized:
            return "roomkit_err_n1002_not_logged_in".localized
        case .permissionDenied:
            return "roomkit_err_n1003_permission_denied".localized
        case .requirePayment:
            return "roomkit_err_n1004_package_required".localized
        case .invalidLicense:
            return "roomkit_err_n1005_invalid_license".localized
        case .cameraStartFail:
            return "roomkit_err_n1100_camera_open_failed".localized
        case .cameraNotAuthorized:
            return "roomkit_err_n1101_camera_no_permission".localized
        case .cameraOccupied:
            return "roomkit_err_n1102_camera_occupied".localized
        case .cameraDeviceEmpty:
            return "roomkit_err_n1103_camera_not_found".localized
        case .microphoneStartFail:
            return "roomkit_err_n1104_mic_open_failed".localized
        case .microphoneNotAuthorized:
            return "roomkit_err_n1105_mic_no_permission".localized
        case .microphoneOccupied:
            return "roomkit_err_n1106_mic_occupied".localized
        case .microphoneDeviceEmpty:
            return "roomkit_err_n1107_mic_not_found".localized
        case .getScreenSharingTargetFailed:
            return "roomkit_err_n1108_screen_share_get_source_failed".localized
        case .startScreenSharingFailed:
            return "roomkit_err_n1109_screen_share_start_failed".localized
        case .operationInvalidBeforeEnterRoom:
            return "roomkit_err_n2101_not_in_room".localized
        case .exitNotSupportedForRoomOwner:
            return "roomkit_err_n2102_owner_cannot_leave".localized
        case .operationNotSupportedInCurrentRoomType:
            return "roomkit_err_n2103_unsupported_in_room_type".localized
        case .roomIdInvalid:
            return "roomkit_err_n2105_invalid_room_id".localized
        case .roomNameInvalid:
            return "roomkit_err_n2107_invalid_room_name".localized
        case .alreadyInOtherRoom:
            return "roomkit_err_n2108_user_already_in_other_room".localized
        case .userNotExist:
            return "roomkit_err_n2200_user_not_exist".localized
        case .userNeedOwnerPermission:
            return "roomkit_err_n2300_need_owner_permission".localized
        case .userNeedAdminPermission:
            return "roomkit_err_n2301_need_admin_permission".localized
        case .requestNoPermission:
            return "roomkit_err_n2310_signal_no_permission".localized
        case .requestIdInvalid:
            return "roomkit_err_n2311_signal_invalid_request_id".localized
        case .requestIdRepeat:
            return "roomkit_err_n2312_signal_request_duplicated".localized
        case .maxSeatCountLimit:
            return "roomkit_err_n2340_seat_count_limit_exceeded".localized
        case .seatIndexNotExist:
            return "roomkit_err_n2344_seat_not_exist".localized
        case .openMicrophoneNeedSeatUnlock:
            return "roomkit_err_n2360_seat_audio_locked".localized
        case .openMicrophoneNeedPermissionFromAdmin:
            return "roomkit_tip_all_muted_cannot_unmute".localized
        case .openCameraNeedSeatUnlock:
            return "roomkit_err_n2370_seat_video_locked".localized
        case .openCameraNeedPermissionFromAdmin:
            return "roomkit_tip_all_video_off_cannot_start".localized
        case .openScreenShareNeedSeatUnlock:
            return "roomkit_err_n2372_screen_share_seat_locked".localized
        case .openScreenShareNeedPermissionFromAdmin:
            return "roomkit_err_n2373_screen_share_need_permission".localized
        case .sendMessageDisabledForAll:
            return "roomkit_err_n2380_all_members_muted".localized
        case .sendMessageDisabledForCurrent:
            return "roomkit_err_10017_muted_in_room".localized
        case .roomNotSupportPreloading:
            return "roomkit_err_n4001_room_not_support_preload".localized
        case .callInProgress:
            return "roomkit_err_n6001_device_busy_during_call".localized
        case .systemInternalError:  // 100001
            return "roomkit_err_100001_server_internal_error".localized
        case .paramIllegal:     // 100002
            return "roomkit_err_100002_server_invalid_parameter".localized
        case .roomIdOccupied:   // 100003
            return "roomkit_err_100003_room_id_already_exists".localized
        case .roomIdNotExist:   // 100004
            return "roomkit_err_100004_room_not_exist".localized
        case .userNotEntered:   // 100005
            return "roomkit_err_100005_not_room_member".localized
        case .insufficientOperationPermissions: // 100006
            return "roomkit_err_100006_operation_not_allowed".localized
        case .noPaymentInformation: // 100007
            return "roomkit_err_100007_no_payment_info".localized
        case .roomIsFull:   // 100008
            return "roomkit_err_100008_room_is_full".localized
        case .tagQuantityExceedsUpperLimit: // 100009
            return "roomkit_err_100009_room_tag_limit_exceeded".localized
        case .roomIdHasBeenUsed:    // 100010
            return "roomkit_err_100010_room_id_reusable_by_owner".localized
        case .roomIdHasBeenOccupiedByChat:  // 100011
            return "roomkit_err_100011_room_id_occupied_by_im".localized
        case .creatingRoomsExceedsTheFrequencyLimit:    // 100012
            return "roomkit_err_100012_create_room_frequency_limit".localized
        case .exceedsTheUpperLimit:     // 100013
            return "roomkit_err_100013_payment_limit_exceeded".localized
        case .invalidRoomType:  // 100015
            return "roomkit_err_100015_invalid_room_type".localized
        case .memberHasBeenBanned:  // 100016
            return "roomkit_err_100016_member_already_banned".localized
        case .memberHasBeenMuted:   // 100017
            return "roomkit_err_100017_member_already_muted".localized
        case .requiresPassword:     // 100018
            return "roomkit_err_100018_room_password_required".localized
        case .roomEntryPasswordError:   // 100019
            return "roomkit_err_100019_room_password_incorrect".localized
        case .roomAdminQuantityExceedsTheUpperLimit:    // 100020
            return "roomkit_err_100020_admin_limit_exceeded".localized
        case .requestIdConflict:    // 100102
            return "roomkit_err_100102_signal_request_conflict".localized
        case .seatLocked:   // 100200
            return "roomkit_err_100200_seat_is_locked".localized
        case .seatOccupied:     // 100201
            return "roomkit_err_100201_seat_is_occupied".localized
        case .alreadyOnTheSeatQueue:    // 100202
            return "roomkit_err_100202_already_in_seat_queue".localized
        case .alreadyInSeat:    // 100203
            return "roomkit_err_100203_already_on_seat".localized
        case .notOnTheSeatQueue:    // 100204
            return "roomkit_err_100204_not_in_seat_queue".localized
        case .allSeatOccupied:  // 100205
            return "roomkit_err_100205_all_seats_are_full".localized
        case .userNotInSeat:    // 100206
            return "roomkit_err_100206_not_on_seat".localized
        case .userAlreadyOnSeat:    // 100210
            return "roomkit_err_100210_user_already_on_seat".localized
        case .seatNotSupportLinkMic:    // 100211
            return "roomkit_err_100211_seat_not_supported".localized
        case .emptySeatList:    // 100251
            return "roomkit_err_100251_seat_list_is_empty".localized
        case .metadataKeyExceedsLimit:  // 100500
            return "roomkit_err_100500_room_metadata_key_limit".localized
        case .metadataValueSizeExceedsByteLimit:  // 100501
            return "roomkit_err_100501_room_metadata_value_limit".localized
        case .metadataTotalValueSizeExceedsByteLimit:  // 100502
            return "roomkit_err_100502_room_metadata_total_limit".localized
        case .metadataNoValidKey:  // 100503
            return "roomkit_err_100503_room_metadata_no_valid_keys".localized
        case .metadataKeySizeExceedsByteLimit:  // 100504
            return "roomkit_err_100504_room_metadata_key_size_limit".localized
            
            // TIMError
        case .ERR_SDK_COMM_TINYID_EMPTY:
            return "roomkit_err_7002_invalid_user_id".localized
        case .ERR_SDK_COMM_API_CALL_FREQUENCY_LIMIT:
            return "roomkit_err_7008_request_rate_limited".localized
        case .ERR_SVR_GROUP_SHUTUP_DENY:
            return "roomkit_err_10017_muted_in_room".localized
        case .ERR_SDK_BLOCKED_BY_SENSITIVE_WORD:
            return "roomkit_err_7015_sensitive_words".localized
        case .ERR_SDK_NET_PKG_SIZE_LIMIT:
            return "roomkit_err_9522_content_too_long".localized
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
            return "roomkit_err_network_error".localized
            
        @unknown default:
            return "roomkit_err_general".localized + ":\(self.rawValue)"
        }
    }
}
