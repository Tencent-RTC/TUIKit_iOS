/**
 * Copyright (c) 2022 Tencent. All rights reserved.
 * Module: TUICallDefine 关键类型定义
 * Description: 定义枚举或常量，例如：通话类型，角色等。
 */
#import <Foundation/Foundation.h>
#import "TUICommonDefine.h"

@class TUIOfflinePushInfo;

typedef void (^TUICallSucc)(void);
typedef void (^TUICallFail)(int code, NSString *_Nullable errMsg);

/// TUICallEngine 版本号
static const NSString *_Nullable TUICALL_VERSION = @"0.0.0.0";

/// 您当前未购买音视频通话能力套餐，请前往控制台开通免费体验：（https://console.cloud.tencent.com/im/detail）或加购正式版：（https://buy.cloud.tencent.com/avc）
static const int ERROR_PACKAGE_NOT_PURCHASED = -1001;

/// 您当前购买的套餐不支持该能力，请先购买：https://buy.cloud.tencent.com/avc
static const int ERROR_PACKAGE_NOT_SUPPORTED = -1002;

/// TIM SDK 版本过低，请升级 TIM SDK 版本 >= 6.6
static const int ERROR_TIM_VERSION_OUTDATED = -1003;

/// 获取权限失败，当前未授权音 / 视频权限，请查看是否开启设备权限
static const int ERROR_PERMISSION_DENIED = -1101;

/// 未调用 init，TUICallEngine API 使用需在 init 之后
static const int ERROR_INIT_FAIL = -1201;

/// 参数错误
static const int ERROR_PARAM_INVALID = -1202;

/// 当前状态不支持调用
static const int ERROR_REQUEST_REFUSED = -1203;

/// 当前方法正在执行中，请勿重复调用
static const int ERROR_REQUEST_REPEATED = -1204;

/// 当前通话场景，不支持该功能
static const int ERROR_SCENE_NOT_SUPPORTED = -1205;

/// 信令发送失败
static const int ERROR_SIGNALING_SEND_FAIL = -1401;

/// 通话类型：未知、音频、视频
typedef NS_ENUM(NSUInteger, TUICallMediaType) {
    TUICallMediaTypeUnknown,
    TUICallMediaTypeAudio,
    TUICallMediaTypeVideo,
};

/// 通话角色：未知、主叫、被叫
typedef NS_ENUM(NSUInteger, TUICallRole) {
    TUICallRoleNone,
    TUICallRoleCall,
    TUICallRoleCalled,
};

/// 通话状态：空闲、等待中、接听中
typedef NS_ENUM(NSUInteger, TUICallStatus) {
    TUICallStatusNone,
    TUICallStatusWaiting,
    TUICallStatusAccept,
};

typedef NS_ENUM(NSUInteger, TUICallScene) {
    TUICallSceneNone = 0,
    TUICallSceneGroup = 1,
    TUICallSceneMulti = 2,
    TUICallSceneSingle = 3,
};

typedef NS_ENUM(NSUInteger, TUICallIOSOfflinePushType) {
    TUICallIOSOfflinePushTypeAPNs = 0,
    TUICallIOSOfflinePushTypeVoIP = 1,
};

typedef NS_ENUM(NSUInteger, TUICallEndReason) {
    TUICallEndReasonUnknown = 0,
    TUICallEndReasonHangup = 1,
    TUICallEndReasonReject = 2,
    TUICallEndReasonNoResponse = 3,
    TUICallEndReasonOffline = 4,
    TUICallEndReasonLineBusy = 5,
    TUICallEndReasonCanceled = 6,
    TUICallEndReasonOtherDeviceAccepted = 7,
    TUICallEndReasonOtherDeviceReject = 8,
    TUICallEndReasonEndByServer = 9,
};

// 通话结果
typedef NS_ENUM(NSUInteger, TUICallResultType) {
    TUICallResultTypeUnknown,
    TUICallResultTypeMissed,
    TUICallResultTypeIncoming,
    TUICallResultTypeOutgoing,
};

/**
 * 扩展参数
 */
NS_ASSUME_NONNULL_BEGIN

TUIENGINE_EXPORT @interface TUICallParams : NSObject

@property(nonatomic, strong) TUIRoomId *roomId;

@property(nonatomic, strong) TUIOfflinePushInfo *offlinePushInfo;

@property(nonatomic, assign) int timeout;

@property(nonatomic, copy) NSString *userData;

@property(nonatomic, copy) NSString *chatGroupId;

@property(nonatomic, assign) BOOL isEphemeralCall;

@property(nonatomic, assign) TUICloudRecordPolicy cloudRecordPolicy;

@end

/**
 * 扩展信息
 */
TUIENGINE_EXPORT @interface TUICallObserverExtraInfo : NSObject

@property(nonatomic, strong) TUIRoomId *roomId;

@property(nonatomic, assign) TUICallRole role;

@property(nonatomic, copy) NSString *userData;

@property(nonatomic, copy) NSString *chatGroupId;

@property(nonatomic, assign) BOOL isEphemeralCall;

@end

/**
 * 离线推送自定义类
 */
TUIENGINE_EXPORT @interface TUIOfflinePushInfo : NSObject

@property(nonatomic, copy) NSString *title;

@property(nonatomic, copy) NSString *desc;

@property(nonatomic, assign) BOOL ignoreIOSBadge;
@property(nonatomic, assign) BOOL enableIOSBackgroundNotification;

@property(nonatomic, copy) NSString *iOSInterruptionLevel;
@property(nonatomic, copy) NSString *iOSImage;
@property(nonatomic, copy) NSString *iOSSound;

@property(nonatomic, copy) NSString *AndroidSound;

@property(nonatomic, copy) NSString *AndroidOPPOChannelID;
@property(nonatomic, copy) NSString *OPPOCategory;
@property(nonatomic, assign) NSInteger OPPONotifyLevel;

@property(nonatomic, copy) NSString *AndroidFCMChannelID;
@property(nonatomic, copy) NSString *fcmImage;

@property(nonatomic, assign) NSInteger AndroidVIVOClassification;
@property(nonatomic, copy) NSString *VIVOCategory;

@property(nonatomic, copy) NSString *AndroidXiaoMiChannelID;

@property(nonatomic, copy) NSString *AndroidHuaWeiCategory;
@property(nonatomic, copy) NSString *huaweiImage;

@property(nonatomic, copy) NSString *honorImportance;
@property(nonatomic, copy) NSString *honorImage;

@property(nonatomic, assign) BOOL isDisablePush;

@property(nonatomic, assign) TUICallIOSOfflinePushType iOSPushType;

@property(nonatomic, copy) NSString *extraInfo;

@end

/**
 * 通话记录
 */
TUIENGINE_EXPORT @interface TUICallRecords : NSObject

@property(nonatomic, copy) NSString *callId;

@property(nonatomic, copy) NSString *inviter;

@property(nonatomic, strong) NSArray *inviteList;

@property(nonatomic, copy) NSString *groupId;

@property(nonatomic, assign) TUICallScene scene;

@property(nonatomic, assign) TUICallMediaType mediaType;

@property(nonatomic, assign) TUICallRole role;

@property(nonatomic, assign) TUICallResultType result;

@property(nonatomic, assign) NSTimeInterval beginTime;

@property(nonatomic, assign) NSTimeInterval totalTime;

@end

/// 通话扩展参数
TUIENGINE_EXPORT @interface TUICallRecentCallsFilter : NSObject

@property(nonatomic, assign) TUICallResultType result;

typedef void (^TUIJsonAPIResponseBlock)(int32_t code, NSString *_Nonnull message, NSString *_Nonnull data);

@end

NS_ASSUME_NONNULL_END
