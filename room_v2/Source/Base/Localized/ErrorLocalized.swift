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
            return "Temporarily unclassified general error".localized + ":\(code)"
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
        "Temporarily unclassified general error".localized + ":\(rawValue)"
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
            return "Operation successful".localized
        case .failed:
            return "Temporarily unclassified general error".localized + ":\(rawValue)"
        case .invalidUserId:
            return "Invalid userid".localized
        case .ERR_SDK_COMM_API_CALL_FREQUENCY_LIMIT:
            return "Request rate limited, please try again later".localized
        case .ERR_SVR_GROUP_SHUTUP_DENY:
            return "You have been muted in the current room".localized
        case .ERR_SDK_BLOCKED_BY_SENSITIVE_WORD:
            return "Sensitive words are detected, please modify it and try again".localized
        case .ERR_SDK_NET_PKG_SIZE_LIMIT:
            return "The content is too long, please reduce the content and try again".localized
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
            return "The network is abnormal, please try again later".localized
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
            return "Operation successful".localized
        case .freqLimit:
            return "Request rate limited, please try again later".localized
        case .repeatOperation:
            return "Repeat operation".localized
        case .roomMismatch:
            return "Room id does not match, please check if you have checked out or changed rooms.".localized
        case .sdkAppIDNotFound:
            return "Not found sdkappid, please confirm application info in trtc console".localized
        case .invalidParameter:
            return "Passing illegal parameters when calling api, check if the parameters are legal".localized
        case .sdkNotInitialized:
            return "Not logged in, please call login api".localized
        case .permissionDenied:
            return "Failed to obtain permission, unauthorized audio/video permission, please check if device permission is enabled".localized
        case .requirePayment:
            return "This feature requires an additional package. please activate the corresponding package as needed in the trtc console".localized
        case .invalidLicense:
            return "License is invalid or expired, please check its validity period in the trtc console. please activate the corresponding package as needed in the trtc console.".localized
        case .cameraStartFail:
            return "System issue, failed to open camera. check if camera device is normal".localized
        case .cameraNotAuthorized:
            return "Camera has no system authorization, check system authorization".localized
        case .cameraOccupied:
            return "Camera is occupied, check if other process is using camera".localized
        case .cameraDeviceEmpty:
            return "No camera device currently, please insert camera device to solve the problem".localized
        case .microphoneStartFail:
            return "System issue, failed to open mic. check if mic device is normal".localized
        case .microphoneNotAuthorized:
            return "Mic has no system authorization, check system authorization".localized
        case .microphoneOccupied:
            return "Mic is occupied".localized
        case .microphoneDeviceEmpty:
            return "No mic device currently".localized
        case .getScreenSharingTargetFailed:
            return "Failed to get screen sharing source (screen and window), check screen recording permissions".localized
        case .startScreenSharingFailed:
            return "Failed to enable screen sharing, check if someone is already screen sharing in the room".localized
        case .operationInvalidBeforeEnterRoom:
            return "This feature can only be used after entering the room".localized
        case .exitNotSupportedForRoomOwner:
            return "Room owner does not support leaving the room, room owner can only close the room".localized
        case .operationNotSupportedInCurrentRoomType:
            return "This operation is not supported in the current room type".localized
        case .roomIdInvalid:
            return "Illegal custom room id, must be printable ascii characters (0x20–0x7e), up to 48 bytes long".localized
        case .roomNameInvalid:
            return "Illegal room name, maximum 30 bytes, must be utf-8 encoding if contains chinese characters".localized
        case .alreadyInOtherRoom:
            return "User is already in another room, single roomengine instance only supports user entering one room, to enter different room, please leave the room or use new roomengine instance".localized
        case .userNotExist:
            return "User is not exist".localized
        case .userNeedOwnerPermission:
            return "Room owner permission required for operation".localized
        case .userNeedAdminPermission:
            return "Room owner or administrator permission required for operation".localized
        case .requestNoPermission:
            return "No permission for signaling request, e.g. canceling an invite not initiated by yourself".localized
        case .requestIdInvalid:
            return "Signaling request id is invalid or has been processed".localized
        case .requestIdRepeat:
            return "Signal request repetition".localized
        case .maxSeatCountLimit:
            return "Maximum seat exceeds package quantity limit".localized
        case .seatIndexNotExist:
            return "Seat serial number does not exist".localized
        case .openMicrophoneNeedSeatUnlock:
            return "Current seat audio is locked".localized
        case .openMicrophoneNeedPermissionFromAdmin:
            return "All on mute audio unable to turn on microphone".localized
        case .openCameraNeedSeatUnlock:
            return "Current seat video is locked, need room owner to unlock mic seat before opening camera".localized
        case .openCameraNeedPermissionFromAdmin:
            return "All on mute video unable to turn on camera".localized
        case .openScreenShareNeedSeatUnlock:
            return "The current microphone position video is locked and needs to be unlocked by the room owner before screen sharing can be enabled".localized
        case .openScreenShareNeedPermissionFromAdmin:
            return "Screen sharing needs to be enabled after applying to the room owner or administrator".localized
        case .sendMessageDisabledForAll:
            return "All members muted in the current room".localized
        case .sendMessageDisabledForCurrent:
            return "You have been muted in the current room".localized
        case .roomNotSupportPreloading:
            return "The current room does not support preloading".localized
        case .callInProgress:
            return "The device operation failed while in a call".localized
        case .systemInternalError:  // 100001
            return "Server internal error, please retry".localized
        case .paramIllegal:     // 100002
            return "The parameter is illegal. check whether the request is correct according to the error description".localized
        case .roomIdOccupied:   // 100003
            return "The room id already exists. please select another room id".localized
        case .roomIdNotExist:   // 100004
            return "The room does not exist, or it once existed but has now been dissolved".localized
        case .userNotEntered:   // 100005
            return "Not a room member".localized
        case .insufficientOperationPermissions: // 100006
            return "You are currently unable to perform this operation (possibly due to lack of permission or scenario restrictions)".localized
        case .noPaymentInformation: // 100007
            return "No payment information, you need to purchase a package in the console".localized
        case .roomIsFull:   // 100008
            return "The room is full".localized
        case .tagQuantityExceedsUpperLimit: // 100009
            return "Tag quantity exceeds upper limit".localized
        case .roomIdHasBeenUsed:    // 100010
            return "The room id has been used, and the operator is the room owner, it can be used directly".localized
        case .roomIdHasBeenOccupiedByChat:  // 100011
            return "The room id has been occupied by chat. you can use a different room id or dissolve the group first".localized
        case .creatingRoomsExceedsTheFrequencyLimit:    // 100012
            return "Creating rooms exceeds the frequency limit, the same room id can only be created once within 1 second".localized
        case .exceedsTheUpperLimit:     // 100013
            return "Exceeds the upper limit, for example, the number of microphone seats, the number of pk match rooms, etc., exceeds the payment limit".localized
        case .invalidRoomType:  // 100015
            return "Invalid room type".localized
        case .memberHasBeenBanned:  // 100016
            return "This member has been banned".localized
        case .memberHasBeenMuted:   // 100017
            return "This member has been muted".localized
        case .requiresPassword:     // 100018
            return "The current room requires a password for entry".localized
        case .roomEntryPasswordError:   // 100019
            return "Room entry password error".localized
        case .roomAdminQuantityExceedsTheUpperLimit:    // 100020
            return "The admin quantity exceeds the upper limit".localized
        case .requestIdConflict:    // 100102
            return "Signal request conflict".localized
        case .seatLocked:   // 100200
            return "The seat is locked. you can try another seat".localized
        case .seatOccupied:     // 100201
            return "The current seat is already occupied".localized
        case .alreadyOnTheSeatQueue:    // 100202
            return "Already on the seat queue".localized
        case .alreadyInSeat:    // 100203
            return "Already on the seat".localized
        case .notOnTheSeatQueue:    // 100204
            return "Not on the seat queue".localized
        case .allSeatOccupied:  // 100205
            return "The seats are all taken.".localized
        case .userNotInSeat:    // 100206
            return "Not on the seat".localized
        case .userAlreadyOnSeat:    // 100210
            return "The user is already on the seat".localized
        case .seatNotSupportLinkMic:    // 100211
            return "The room does not support seat ability".localized
        case .emptySeatList:    // 100251
            return "The seat list is empty".localized
        case .metadataKeyExceedsLimit:  // 100500
            return "The number of keys in the room's metadata exceeds the limit".localized
        case .metadataValueSizeExceedsByteLimit:  // 100501
            return "The size of value in the room's metadata exceeds the maximum byte limit".localized
        case .metadataTotalValueSizeExceedsByteLimit:  // 100502
            return "The total size of all value in the room's metadata exceeds the maximum byte limit".localized
        case .metadataNoValidKey:  // 100503
            return "There is no valid keys when delete metadata".localized
        case .metadataKeySizeExceedsByteLimit:  // 100504
            return "The size of key in the room's metadata exceeds the maximum byte limit".localized
            
            // TIMError
        case .ERR_SDK_COMM_TINYID_EMPTY:
            return "Invalid userid".localized
        case .ERR_SDK_COMM_API_CALL_FREQUENCY_LIMIT:
            return "Request rate limited, please try again later".localized
        case .ERR_SVR_GROUP_SHUTUP_DENY:
            return "You have been muted in the current room".localized
        case .ERR_SDK_BLOCKED_BY_SENSITIVE_WORD:
            return "Sensitive words are detected, please modify it and try again".localized
        case .ERR_SDK_NET_PKG_SIZE_LIMIT:
            return "The content is too long, please reduce the content and try again".localized
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
            return "The network is abnormal, please try again later".localized
            
        @unknown default:
            return "Temporarily unclassified general error".localized + ":\(self.rawValue)"
        }
    }
}
