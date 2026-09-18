/**
 * Copyright (c) 2024 Tencent. All rights reserved.
 * Module:   TUIRoomDefine @ TUIKitEngine
 * Function: TUIRoomEngine 关键类型定义
 */
#import <Foundation/Foundation.h>
#import "TUICommonDefine.h"

/////////////////////////////////////////////////////////////////////////////////
//
//                    房间、角色相关枚举值定义
//
/////////////////////////////////////////////////////////////////////////////////

/**
 * 1.1 房间类型
 */
typedef NS_ENUM(NSUInteger, TUIRoomType) {

    /// 会议类型房间，适用于会议，教育场景，该房间中可以开启自由发言，申请发言、上麦发言等不同模式。
    TUIRoomTypeConference = 1,

    /// 直播类型房间，适用于直播场景，该房间可以开启自由发言，上麦发言模式。
    TUIRoomTypeLive = 2,

};

/**
 * 1.2 上麦模式
 */
typedef NS_ENUM(NSUInteger, TUISeatMode) {

    /// 自由上麦模式，台下观众可以自由上麦，无需申请。
    TUISeatModeFreeToTake = 1,

    /// 申请上麦模式，台下观众上麦需要房主或者管理员同意后才能上麦。
    TUISeatModeApplyToTake = 2,

};

/**
 * 1.3 房间内媒体设备类型
 */
typedef NS_ENUM(NSUInteger, TUIMediaDevice) {

    /// 麦克风。
    TUIMediaDeviceMicrophone = 1,

    /// 摄像头。
    TUIMediaDeviceCamera = 2,

    /// 屏幕共享。
    TUIMediaDeviceScreenSharing = 3,

};

/**
 * 1.4 房间内角色类型
 */
typedef NS_ENUM(NSUInteger, TUIRole) {

    /// 房主，一般指房间的创建者，房间内最高权限拥有者。
    TUIRoleRoomOwner = 0,

    /// 房间管理员。
    TUIRoleAdministrator = 1,

    /// 房间内普通成员。
    TUIRoleGeneralUser = 2,

};

/**
 * 1.5 房间解散原因
 */
typedef NS_ENUM(NSUInteger, TUIRoomDismissedReason) {

    /// 被房主解散。
    TUIRoomDismissedReasonByOwner = 1,

    /// 被服务器解散。
    TUIRoomDismissedReasonByServer = 2,

};

/**
 * 1.6 用户的挂起状态
 */
typedef NS_ENUM(NSUInteger, TUISuspendStatus) {

    /// 未挂起
    TUISuspendStatusNone = 0,

    /// 用户进入后台挂起
    TUISuspendStatusInBackground = 1 << 0,

    /// 用户正在接听电话
    TUISuspendStatusInCalling = 1 << 1,

};

/**
 * 1.7 用户的设备状态
 */
typedef NS_ENUM(NSUInteger, TUIDeviceStatus) {

    /// 当前设备处于打开状态
    TUIDeviceStatusOpened = 0,

    /// 当前设备处于关闭状态，且是用户主动关闭
    TUIDeviceStatusClosedBySelf = 1,

    /// 当前设备处于关闭状态，且是被房主/管理员强制关闭
    TUIDeviceStatusClosedByAdmin = 2,

};

/**
 * 1.8 移动麦上用户的策略
 */
typedef NS_ENUM(NSUInteger, TUIMoveSeatPolicy) {

    /// 目标麦位有人时放弃移动（默认策略）​​
    TUIMoveSeatPolicyAbortWhenOccupied = 0,

    /// 强制替换目标麦位上的用户​​，被替换的用户将会被踢下麦
    TUIMoveSeatPolicyForceReplace = 1,

    /// ​与目标麦位用户交换位置​​
    TUIMoveSeatPolicySwapPosition = 2,

};

/**
 * 1.9 锁定麦位标记位
 */
typedef NS_OPTIONS(NSUInteger, TUISeatLockFlag) {

    TUISeatLockFlagNone = 0x00,

    /// 锁定麦位
    TUISeatLockFlagSeat = 0x01 << 0,

    /// 锁定麦位摄像头
    TUISeatLockFlagVideo = 0x01 << 1,

    /// 锁定麦位麦克风
    TUISeatLockFlagAudio = 0x01 << 2,

    TUISeatLockFlagAll = TUISeatLockFlagSeat | TUISeatLockFlagVideo | TUISeatLockFlagAudio,

};

/////////////////////////////////////////////////////////////////////////////////
//
//                    音视频相关枚举值定义
//
/////////////////////////////////////////////////////////////////////////////////

/**
 * 2.1 视频质量档位。
 *
 * 此枚举定义了视频采集的质量档位。SDK 内部已根据不同档位预置了对应的分辨率、帧率和码率组合，方便在不同场景中直接选用。
 *
 * 不同档位会影响 RTC 服务的计费，请参考：
 *
 * - 国内用户：https://cloud.tencent.com/document/product/647/44248#price
 * - 海外用户：https://trtc.io/document/42734?product=pricing
 */
typedef NS_ENUM(NSUInteger, TUIVideoQuality) {

    /// 360P，分辨率 640 × 360。
    TUIVideoQuality360P = 1,

    /// 540P，分辨率 960 × 540。
    TUIVideoQuality540P = 2,

    /// 720P，分辨率 1280 × 720。
    TUIVideoQuality720P = 3,

    /// 1080P，分辨率 1920 × 1080。
    TUIVideoQuality1080P = 4,

};

/**
 * 2.2 音频质量
 */
typedef NS_ENUM(NSUInteger, TUIAudioQuality) {

    /// 人声模式。
    TUIAudioQualitySpeech = 0,

    /// 默认模式。
    TUIAudioQualityDefault = 1,

    /// 音乐模式。
    TUIAudioQualityMusic = 2,

};

/**
 * 2.3 视频流类型
 */
typedef NS_ENUM(NSUInteger, TUIVideoStreamType) {

    /// 高清摄像头视频流。
    TUIVideoStreamTypeCameraStream = 0,

    /// 屏幕分享视频流。
    TUIVideoStreamTypeScreenStream = 1,

    /// 低清摄像头视频流。
    TUIVideoStreamTypeCameraStreamLow = 2,

};

/**
 * 2.4 音视频状态更改原因（分类: 自己主动修改 或者 被房主、管理员修改）
 */
typedef NS_ENUM(NSUInteger, TUIChangeReason) {

    /// 自己操作。
    TUIChangeReasonBySelf = 0,

    /// 房主或管理员操作。
    TUIChangeReasonByAdmin = 1,

};

/**
 * 2.5 用户被踢出房间原因（分类: 被主持人或管理员踢出、在其它设备进入房间被踢出 或者 被服务端踢出）
 */
typedef NS_ENUM(NSUInteger, TUIKickedOutOfRoomReason) {

    /// 被主持人或管理员踢出。
    TUIKickedOutOfRoomReasonByAdmin = 0,

    /// 在其它设备进入房间被踢出。
    TUIKickedOutOfRoomReasonByLoggedOnOtherDevice = 1,

    /// 被服务端踢出。
    TUIKickedOutOfRoomReasonByServer = 2,

    /// 网络中断超时退房。
    TUIKickedOutOfRoomReasonForNetworkDisconnected = 3,

    /// 离线期间态进房状发生变化（被踢出房间或者房间已解散）。
    TUIKickedOutOfRoomReasonForJoinRoomStatusInvalidDuringOffline = 4,

    /// 超过了单设备最大可同时加入的房间个数，导致最早加入的房间自动退出
    TUIKickedOutOfRoomReasonForCountOfJoinedRoomsExceedLimit = 5,

};

/**
 * 2.6 分辨率模式（横屏 or 竖屏）
 */
typedef NS_ENUM(NSUInteger, TUIResolutionMode) {

    /// 横屏。
    TUIResolutionModeLandscape = 0,

    /// 竖屏。
    TUIResolutionModePortrait = 1,

};

/**
 * 2.7 屏幕分享捕获源类型
 */
typedef NS_ENUM(NSInteger, TUICaptureSourceType) {

    /// 未定义。
    TUICaptureSourceTypeUnknown = -1,

    /// 窗口。
    TUICaptureSourceTypeWindow = 0,

    /// 屏幕。
    TUICaptureSourceTypeScreen = 1,

};

/////////////////////////////////////////////////////////////////////////////////
//
//                    信令请求相关枚举值定义
//
/////////////////////////////////////////////////////////////////////////////////

/**
 * 4.1 请求类型
 */
typedef NS_ENUM(NSUInteger, TUIRequestAction) {

    /// 无效请求。
    TUIRequestActionInvalidAction = 0,

    /// 请求远端用户打开其摄像头。
    TUIRequestActionOpenRemoteCamera = 1,

    /// 请求远端用户打开其麦克风。
    TUIRequestActionOpenRemoteMicrophone = 2,

    /// 向管理员请求让自己上麦。
    TUIRequestActionTakeSeat = 4,

    /// 请求远端用户上麦。
    TUIRequestActionRemoteUserOnSeat = 5,

    /// 向管理员请求打开自己的本地摄像头。
    TUIRequestActionApplyToAdminToOpenLocalCamera = 6,

    /// 向管理员请求打开自己的本地麦克风。
    TUIRequestActionApplyToAdminToOpenLocalMicrophone = 7,

    /// 向管理员请求打开自己的本地屏幕分享。
    TUIRequestActionApplyToAdminToOpenLocalScreenShare = 8,

    /// 请求远端用户关闭其摄像头。
    TUIRequestActionCloseRemoteCamera = 9,

    /// 请求远端用户关闭其麦克风。
    TUIRequestActionCloseRemoteMicrophone = 10,

    /// 请求远端用户关闭其屏幕分享。
    TUIRequestActionCloseRemoteScreenShare = 11,

};

NS_ASSUME_NONNULL_BEGIN

/////////////////////////////////////////////////////////////////////////////////
//
//                      TUIRoomEngine 核心类型定义
//
/////////////////////////////////////////////////////////////////////////////////
///

/**
 * 5.1 房间信息
 *
 * TUIRoomEngine 只支持字符串房间ID。
 */
TUIENGINE_EXPORT @interface TUIRoomInfo : NSObject

/// 房间ID (创建房间必填参数，最大支持48个字节)。
@property(nonatomic, strong, nonnull) NSString* roomId;

/// 房主ID: 默认为房间创建者ID（只读）。
@property(nonatomic, readonly, nonnull) NSString* ownerId;

/// 房主昵称: 默认为房间创建者昵称（只读）。
@property(nonatomic, readonly, nonnull) NSString* ownerName;

/// 房主头像URL: 默认为房间创建者头像URL（只读）。
@property(nonatomic, readonly, nonnull) NSString* ownerAvatarUrl;

/// 房间类型（创建房间可选参数），请参见：{@link TUIRoomType}。
@property(nonatomic, assign) TUIRoomType roomType;

/// 房间名称（创建房间可选参数，默认房间ID，最大支持100个字节）。
@property(nonatomic, copy, nonnull) NSString* name;

/// 是否禁止打开摄像头（创建房间可选参数），默认值：{@link NO}。
@property(nonatomic, assign) BOOL isCameraDisableForAllUser;

/// 是否禁止打开麦克风（创建房间可选参数），默认值：{@link NO}。
@property(nonatomic, assign) BOOL isMicrophoneDisableForAllUser;

/// 是否禁止打开屏幕分享（创建房间可选参数），默认值：{@link NO}。
@property(nonatomic, assign) BOOL isScreenShareDisableForAllUser;

/// 是否禁止发送消息（创建房间可选参数），默认值：{@link NO}。
@property(nonatomic, assign) BOOL isMessageDisableForAllUser;

/// 是否开启麦位控制。
@property(nonatomic, assign) BOOL isSeatEnabled;

/// 上麦模式(只有开启麦位控制后生效)。
@property(nonatomic, assign) TUISeatMode seatMode;

/// 最大麦位数。
@property(nonatomic, assign) NSInteger maxSeatCount;

/// 房主上麦后常驻麦位。
@property(nonatomic, assign) BOOL keepOwnerOnSeat;

/// 房间创建时间（只读）。
@property(nonatomic, readonly) NSUInteger createTime;

/// 房间内成员数量（只读）。
@property(nonatomic, readonly) NSInteger memberCount;

/// 房间密码。
@property(nonatomic, copy, nonnull) NSString* password;

@end

/**
 * 5.2 用户登录信息
 */
TUIENGINE_EXPORT @interface TUILoginUserInfo : NSObject

/// 用户ID。
@property(nonatomic, copy, nonnull) NSString* userId;

/// 用户名称。
@property(nonatomic, copy, nonnull) NSString* userName;

/// 用户头像URL。
@property(nonatomic, copy, nonnull) NSString* avatarUrl;

/// 用户的等级。
@property(nonatomic, assign) NSUInteger level;

/// 自定义信息。
@property(nonatomic, strong, nullable) NSDictionary<NSString*, NSData*>* customInfo __attribute__((deprecated("use customInfo in TUIUserInfo instead")));

@end

/**
 * 5.3 房间内用户信息
 */
TUIENGINE_EXPORT @interface TUIUserInfo : NSObject

/// 用户ID。
@property(nonatomic, copy, nonnull) NSString* userId;

/// 用户名称。
@property(nonatomic, copy, nonnull) NSString* userName;

/// 房间内用户昵称，最大支持32个字节。
@property(nonatomic, copy, nonnull) NSString* nameCard;

/// 用户头像URL。
@property(nonatomic, copy, nonnull) NSString* avatarUrl;

/// 用户角色类型，会议类型的房间角色仅存在于房间内，退房后再进入角色为普通用户。直播可以在进房前设置，房间不解散，角色依然存在。详情参见：{@link TUIRole}。
@property(nonatomic, assign) TUIRole userRole;

/// 是否有音频流，默认值：{@link NO}。
@property(nonatomic, assign) BOOL hasAudioStream;

/// 是否有视频流，默认值：{@link NO}。
@property(nonatomic, assign) BOOL hasVideoStream;

/// 是否有屏幕分享流，默认值：{@link NO}。
@property(nonatomic, assign) BOOL hasScreenStream;

/// 是否被禁止发送消息，默认值：{@link NO}。
@property(nonatomic, assign) BOOL isMessageDisabled;

/// 用户等级。
@property(nonatomic, assign) NSUInteger level;

/// 房间成员自定义信息。
@property(nonatomic, strong, nullable) NSDictionary<NSString*, NSData*>* roomCustomInfo;

@end

/**
 * 5.4 房间内用户信息变更参数key。
 */
typedef NS_OPTIONS(NSUInteger, TUIUserInfoModifyFlag) {

    TUIUserInfoModifyFlagNone = 0x00,

    /// userRole 参数发生变更。
    TUIUserInfoModifyFlagUserRole = 0x01 << 0,

    /// nameCard 参数发生变更。
    TUIUserInfoModifyFlagNameCard = 0x01 << 1,

};

/**
 * 5.5 视频编码参数
 */
TUIENGINE_EXPORT @interface TUIRoomVideoEncoderParams : NSObject

/// 视频质量, 请参见：{@link TUIVideoQuality}。
@property(nonatomic, assign) TUIVideoQuality videoResolution;

/// 分辨率模式, 请参见：{@link TUIResolutionMode}。
@property(nonatomic, assign) TUIResolutionMode resolutionMode;

/// 视频采集帧率。
@property(nonatomic, assign) NSInteger fps;

/// 目标视频码率。
@property(nonatomic, assign) NSInteger bitrate;

@end

/**
 * 5.6 房间内座位信息
 */
TUIENGINE_EXPORT @interface TUISeatInfo : NSObject

/// 房间 ID。
@property(nonatomic, copy, nullable) NSString* roomId;

/// 麦位序号。
@property(nonatomic, assign) NSInteger index;

/// 用户ID。
@property(nonatomic, copy, nullable) NSString* userId;

/// 用户昵称
@property(nonatomic, copy, nullable) NSString* userName;

/// 房间内用户昵称
@property(nonatomic, copy, nullable) NSString* nameCard;

/// 用户头像URL
@property(nonatomic, copy, nullable) NSString* avatarUrl;

/// 麦位是否被锁定，默认值：{@link NO}。
@property(nonatomic, assign) BOOL isLocked;

/// 麦位是否被禁止打开摄像头，默认值：{@link NO}。
@property(nonatomic, assign) BOOL isVideoLocked;

/// 麦位是否被禁止打开麦克风，默认值：{@link NO}。
@property(nonatomic, assign) BOOL isAudioLocked;

@end

/**
 * 5.7 房间内座位的全量信息
 */
TUIENGINE_EXPORT @interface TUISeatFullInfo : NSObject

/// 房间 ID
@property(nonatomic, copy, nonnull) NSString* roomId;

/// 麦位编号
@property(nonatomic, assign) NSInteger seatIndex;

/// 麦位是否被锁定
@property(nonatomic, assign) BOOL isSeatLocked;

/// 麦上用户 ID
@property(nonatomic, copy, nullable) NSString* userId;

/// 麦上用户的昵称
@property(nonatomic, copy, nullable) NSString* userName;

/// 麦上用户的头像 URL
@property(nonatomic, copy, nullable) NSString* userAvatar;

/// 麦上用户的麦克风状态
@property(nonatomic, assign) TUIDeviceStatus userMicrophoneStatus;

/// 麦上用户的摄像头状态
@property(nonatomic, assign) TUIDeviceStatus userCameraStatus;

/// 麦上用户的挂起状态
@property(nonatomic, assign) TUISuspendStatus userSuspendStatus;

/// 麦上用户是否为主咖
@property(nonatomic, assign) BOOL isFeaturedHost;

/// 麦位的 x 坐标
@property(nonatomic, assign) NSUInteger x;

/// 麦位的 y 坐标
@property(nonatomic, assign) NSUInteger y;

/// 麦位的宽度
@property(nonatomic, assign) NSUInteger width;

/// 麦位的高度
@property(nonatomic, assign) NSUInteger height;

/// 麦位的纵向层级
@property(nonatomic, assign) NSUInteger zorder;

@end

/**
 * 5.8 锁定麦位操作参数
 */
TUIENGINE_EXPORT @interface TUISeatLockParams : NSObject

/// 锁定麦位，默认值：{@link NO}。
@property(nonatomic, assign) BOOL lockSeat;

/// 锁定麦位摄像头，默认值：{@link NO}。
@property(nonatomic, assign) BOOL lockVideo;

/// 锁定麦位麦克风，默认值：{@link NO}。
@property(nonatomic, assign) BOOL lockAudio;

/// 锁定麦位标记位，默认值：{@link TUISeatLockFlagAll}。
@property(nonatomic, assign) TUISeatLockFlag lockFlag;

@end

/**
 * 5.9 房间内用户音量
 */
TUIENGINE_EXPORT @interface TUIUserVoiceVolume : NSObject

/// 用户ID。
@property(nonatomic, copy, nonnull) NSString* userId;

/// 音量 用于承载所有正在说话的用户的音量大小，取值范围 0 - 100。
@property(nonatomic, assign) NSUInteger volume;

@end

/**
 * 5.10 信令请求
 */
TUIENGINE_EXPORT @interface TUIRequest : NSObject

/// 请求ID。
@property(nonatomic, readonly, nonnull) NSString* requestId;

/// 请求类型。
@property(nonatomic, assign) TUIRequestAction requestAction;

/// 请求发送者的信息。
@property(nonatomic, strong, nonnull) TUIUserInfo* fromUser;

/// 请求接收者的信息。
@property(nonatomic, strong, nonnull) TUIUserInfo* toUser;

/// 信令内容。
@property(nonatomic, copy, nonnull) NSString* content;

/// 时间戳。
@property(nonatomic, assign) NSUInteger timestamp;

/// 扩展信息。
@property(nonatomic, copy, nonnull) NSString* extensionInfo;

/// 用户ID。(从 3.6 版本开始废弃，请使用 fromUser 和 toUser)
@property(nonatomic, copy, nonnull) NSString* userId __attribute__((deprecated));

/// 用户昵称。(从 3.6 版本开始废弃，请使用 fromUser 和 toUser)
@property(nonatomic, copy, nonnull) NSString* userName __attribute__((deprecated));

/// 房间内用户昵称。(从 3.6 版本开始废弃，请使用 fromUser 和 toUser)
@property(nonatomic, copy, nonnull) NSString* nameCard __attribute__((deprecated));

/// 用户头像URL。(从 3.6 版本开始废弃，请使用 fromUser 和 toUser)
@property(nonatomic, copy, nonnull) NSString* avatarUrl __attribute__((deprecated));

@end

/**
 * 5.11 进房参数
 */
TUIENGINE_EXPORT @interface TUIEnterRoomOptions : NSObject

/// 房间密码。
@property(nonatomic, copy, nonnull) NSString* password;

@end

/**
 * 5.12 搜索参数
 */
TUIENGINE_EXPORT @interface TUIUserSearchParam : NSObject

/// 搜索关键字，目前支持用户昵称搜索
@property(nonatomic, copy, nonnull) NSString* keyword;

/// 获取分页列表的下标。
@property(nonatomic, copy, nonnull) NSString* cursor;

@end

/**
 * 5.13 房间内文本消息
 */
TUIENGINE_EXPORT @interface TUIRoomTextMessage : NSObject

/// 房间 ID（只读）
@property(nonatomic, copy, nonnull, readonly) NSString* roomId;

/// 消息发送者（只读）
@property(nonatomic, strong, nonnull, readonly) TUIUserInfo* sender;

/// 消息序列号（只读）
@property(nonatomic, assign, readonly) NSUInteger sequence;

/// 消息时间戳（只读）
@property(nonatomic, assign, readonly) NSTimeInterval timestampInSecond;

/// 消息文本
@property(nonatomic, copy, nonnull) NSString* textContent;

/// 消息扩展字段
@property(nonatomic, strong, nullable) NSDictionary<NSString*, NSString*>* extensionInfo;

@end

/**
 * 5.14 房间内自定义消息
 */
TUIENGINE_EXPORT @interface TUIRoomCustomMessage : NSObject

/// 房间 ID（只读）
@property(nonatomic, copy, nonnull, readonly) NSString* roomId;

/// 消息发送者（只读）
@property(nonatomic, strong, nonnull, readonly) TUIUserInfo* sender;

/// 消息序列号（只读）
@property(nonatomic, assign, readonly) NSUInteger sequence;

/// 消息时间戳（只读）
@property(nonatomic, assign, readonly) NSTimeInterval timestampInSecond;

/// 自定义业务 ID
@property(nonatomic, copy, nonnull) NSString* businessId;

/// 自定义业务数据
@property(nonatomic, copy, nonnull) NSString* data;

@end

/////////////////////////////////////////////////////////////////////////////////
//
//                      TUIRoomEngine 基本类型定义
//
/////////////////////////////////////////////////////////////////////////////////
///

#if TARGET_OS_MAC && !TARGET_OS_IPHONE

/**
 * 屏幕分享采集源信息
 */
TUIENGINE_EXPORT @interface TUIShareTarget : NSObject

/// 采集源的ID，对于窗口，该字段代表窗口的 ID；对于屏幕，该字段代表显示器的 ID。
@property(nonatomic, readonly, nonnull) NSString* targetId;

/// 采集源类型。
@property(nonatomic, readonly) TUICaptureSourceType sourceType;

/// 采集源名称。
@property(nonatomic, readonly, nullable) NSString* sourceName;

/// 缩略图。
@property(nonatomic, readonly, nullable) TUIImage* thumbnailImage;

/// 图标。
@property(nonatomic, readonly, nullable) TUIImage* iconImage;

/// 窗口的扩展信息。
@property(nonatomic, readonly, nullable) NSDictionary* extInfo;

@end

#endif

typedef void (^TUIRoomListBlock)(NSArray* _Nonnull list);

typedef void (^TUIRoomInfoBlock)(TUIRoomInfo* _Nullable roomInfo);
typedef void (^TUIRoomListResponseBlock)(NSArray<TUIRoomInfo*>* _Nonnull list);
typedef void (^TUIUserInfoBlock)(TUIUserInfo* _Nullable userInfo);
typedef void (^TUIUserListResponseBlock)(NSArray<TUIUserInfo*>* _Nonnull list, NSInteger nextSequence);
typedef void (^TUISeatListResponseBlock)(NSArray<TUISeatInfo*>* _Nonnull list);
typedef void (^TUIRequestListResponseBlock)(NSArray<TUIRequest*>* _Nonnull list);
typedef void (^TUIRoomMetadataResponseBlock)(NSDictionary<NSString*, NSString*>* _Nonnull metadata);
typedef void (^TUIUserSearchResponseBlock)(NSArray<TUIUserInfo*>* _Nonnull list, NSString* cursor);
typedef void (^TUISendTextMessageBlock)(TUIRoomTextMessage* _Nonnull message);
typedef void (^TUISendCustomMessageBlock)(TUIRoomCustomMessage* _Nonnull message);

typedef void (^TUIPlayOnPlayingBlock)(NSString* _Nonnull userId);
typedef void (^TUIPlayOnLoadingBlock)(NSString* _Nonnull userId);
typedef void (^TUIPlayOnErrorBlock)(NSString* _Nonnull userId, TUIError code, NSString* _Nonnull message);

typedef void (^TUIRequestAcceptedBlock)(NSString* _Nonnull requestId, NSString* _Nonnull userId);
typedef void (^TUIRequestRejectedBlock)(NSString* _Nonnull requestId, NSString* _Nonnull userId, NSString* _Nonnull message);
typedef void (^TUIRequestCancelledBlock)(NSString* _Nonnull requestId, NSString* _Nonnull userId);
typedef void (^TUIRequestTimeoutBlock)(NSString* _Nonnull requestId, NSString* _Nonnull userId);
typedef void (^TUIRequestErrorBlock)(NSString* _Nonnull requestId, NSString* _Nonnull userId, TUIError code, NSString* _Nonnull message);

typedef void (^TUIRequestAcceptedCallback)(NSString* _Nonnull requestId, TUIUserInfo* _Nonnull userInfo, NSString* _Nonnull extensionInfo);
typedef void (^TUIRequestRejectedCallback)(NSString* _Nonnull requestId, TUIUserInfo* _Nonnull userInfo, NSString* _Nonnull message, NSString* _Nonnull extensionInfo);
typedef void (^TUIRequestCancelledCallback)(NSString* _Nonnull requestId, TUIUserInfo* _Nonnull userInfo);
typedef void (^TUIRequestTimeoutCallback)(NSString* _Nonnull requestId, TUIUserInfo* _Nonnull userInfo);
typedef void (^TUIRequestSuccessCallback)(NSString* _Nonnull requestId, TUIUserInfo* _Nonnull userInfo);
typedef void (^TUIRequestErrorCallback)(NSString* _Nonnull requestId, TUIUserInfo* _Nonnull userInfo, TUIError code, NSString* _Nonnull message);

typedef void (^TUIExperimentalAPIResponseBlock)(NSString* _Nonnull jsonData);
typedef void (^TUIJsonAPIResponseBlock)(int32_t code, NSString* _Nonnull message, NSString* _Nonnull data);

NS_ASSUME_NONNULL_END
