/**
 * Copyright (c) 2024 Tencent. All rights reserved.
 * Module:   TUICommonDefine @ TUIKitEngine
 * Function: TUIKitEngine 复用型定义
 */
#import <Foundation/Foundation.h>
#import "TUIEngineSymbolExport.h"

#if TARGET_OS_IPHONE || TARGET_OS_SIMULATOR
#import <UIKit/UIKit.h>
typedef UIView TUIVideoView;
typedef UIImage TUIImage;
typedef UIEdgeInsets TUIEdgeInsets;
#elif TARGET_OS_MAC
#import <AppKit/AppKit.h>
typedef NSView TUIVideoView;
typedef NSImage TUIImage;
typedef NSEdgeInsets TUIEdgeInsets;
#endif

/**
 * 1.1 错误码枚举定义。
 */
typedef NS_ENUM(NSInteger, TUIError) {

    /// 操作成功。
    TUIErrorSuccess = 0,

    /// 暂未归类的通用错误。
    TUIErrorFailed = -1,

    /// 请求被限频，请稍后重试。
    TUIErrorFreqLimit = -2,

    /// 重复操作。
    TUIErrorRepeatOperation = -3,

    /// 房间 ID 不匹配，请检查是否退房或者切换了房间。
    TUIErrorRoomMismatch = -4,

    /// 未找到SDKAppID，请在腾讯云视立方SDK[控制台](https://console.cloud.tencent.com/vcube/project/manage)确认应用信息。
    TUIErrorSDKAppIDNotFound = -1000,

    /// 调用 API 时，传入的参数不合法，检查入参是否合法。
    TUIErrorInvalidParameter = -1001,

    /// 未登录,请调用Login接口。
    TUIErrorSdkNotInitialized = -1002,

    /// 获取权限失败，当前未授权音/视频权限，请查看是否开启设备权限。Room场景下请使用以下错误码来处理:
    /// 摄像头没有系统授权: ERR_CAMERA_NOT_AUTHORIZED。
    /// 麦克风没有系统授权: ERR_MICROPHONE_NOT_AUTHORIZED。
    TUIErrorPermissionDenied = -1003,

    /// 该功能需要开通额外的套餐，请在腾讯云视立方SDK [控制台](https://console.cloud.tencent.com/vcube/project/manage) 按需开通对应套餐。
    TUIErrorRequirePayment = -1004,

    /// 错误描述:
    /// SDK检测到当前使用的License无效或已过期，导致播放功能受限无法正常播放
    /// 错误原因:
    /// 1. License非法或已过期
    /// 2. License未包含所需功能权限
    /// 3. License签名验证失败
    /// 处理建议:
    /// 1. 在腾讯云视立方控制台确认License有效期
    /// 2. 联系腾讯云技术支持更新或重新获取License
    TUIErrorInvalidLicense = -1005,

    /// 系统问题，打开摄像头失败。检查摄像头设备是否正常。
    TUIErrorCameraStartFail = -1100,

    /// 摄像头没有系统授权, 检查系统授权。
    TUIErrorCameraNotAuthorized = -1101,

    /// 摄像头被占用，检查是否有其他进程使用摄像头。
    TUIErrorCameraOccupied = -1102,

    /// 当前无摄像头设备，请插入摄像头设备解决该问题。
    TUIErrorCameraDeviceEmpty = -1103,

    /// 系统问题，打开麦克风失败。检查麦克风设备是否正常。
    TUIErrorMicrophoneStartFail = -1104,

    /// 麦克风没有系统授权，检查系统授权。
    TUIErrorMicrophoneNotAuthorized = -1105,

    /// 麦克风被占用。
    TUIErrorMicrophoneOccupied = -1106,

    /// 当前无麦克风设备。
    TUIErrorMicrophoneDeviceEmpty = -1107,

    /// 获取屏幕分享源（屏幕和窗口）失败，检查屏幕录制权限。
    TUIErrorGetScreenSharingTargetFailed = -1108,

    /// 开启屏幕分享失败，检查房间内是否有人正在屏幕分享。
    TUIErrorStartScreenSharingFailed = -1109,

    /// 音频采集设备不可用（例如被系统电话或微信语音电话占用）。
    TUIErrorAudioCaptureDeviceUnavailable = -1110,

    /// 需要进房后才可使用此功能。
    TUIErrorOperationInvalidBeforeEnterRoom = -2101,

    /// 房主不支持退房操作，Conference(会议)房间类型: 可以先转让房主，再退房。LivingRoom(直播)房间类型: 房主只能解散房间。
    TUIErrorExitNotSupportedForRoomOwner = -2102,

    /// 当前房间类型下不支持该操作。
    TUIErrorOperationNotSupportedInCurrentRoomType = -2103,

    /// 创建房间ID 非法，自定义 ID 必须为可打印 ASCII 字符（0x20-0x7e），最长48个字节。
    TUIErrorRoomIdInvalid = -2105,

    /// 房间名称非法，名称最长30字节，如果包含中文，字符编码必须是 UTF-8。
    TUIErrorRoomNameInvalid = -2107,

    /// 当前用户已在别的房间内，需要先退房才能加入新的房间:
    /// 单个roomEngine实例只支持用户进入一个房间，如果要进入不同的房间请先退房或者使用新的roomEngine实例。
    TUIErrorAlreadyInOtherRoom = -2108,

    /// 用户不存在。
    TUIErrorUserNotExist = -2200,

    /// 需要房主权限才能操作。
    TUIErrorUserNeedOwnerPermission = -2300,

    /// 需要房主或者管理员权限才能操作。
    TUIErrorUserNeedAdminPermission = -2301,

    /// 信令请求无权限，例如取消非自己发起的邀请。
    TUIErrorRequestNoPermission = -2310,

    /// 信令请求ID 无效或已经被处理过。
    TUIErrorRequestIdInvalid = -2311,

    /// 信令请求重复。
    TUIErrorRequestIdRepeat = -2312,

    /// 最大麦位超出套餐包数量限制。
    TUIErrorMaxSeatCountLimit = -2340,

    /// 麦位编号不存在。
    TUIErrorSeatIndexNotExist = -2344,

    /// 当前麦位音频被锁。
    TUIErrorOpenMicrophoneNeedSeatUnlock = -2360,

    /// 需要向房主或管理员申请后打开麦克风。
    TUIErrorOpenMicrophoneNeedPermissionFromAdmin = -2361,

    /// 当前麦位视频被锁, 需要由房主解锁麦位后，才能打开摄像头。
    TUIErrorOpenCameraNeedSeatUnlock = -2370,

    /// 需要向房主或管理员申请后打开摄像头。
    TUIErrorOpenCameraNeedPermissionFromAdmin = -2371,

    /// 当前麦位视频被锁, 需要由房主解锁麦位后，才能打开屏幕分享。
    TUIErrorOpenScreenShareNeedSeatUnlock = -2372,

    /// 需要向房主或管理员申请后打开屏幕分享。
    TUIErrorOpenScreenShareNeedPermissionFromAdmin = -2373,

    /// 当前房间已开启全员禁言。
    TUIErrorSendMessageDisabledForAll = -2380,

    /// 当前房间内，您已被已禁言。
    TUIErrorSendMessageDisabledForCurrent = -2381,

    /// 当前房间不支持预加载。
    TUIErrorRoomNotSupportPreloading = -4001,

    /// 错误描述：正在通话中，不允许操作设备/流相关接口。
    /// 错误原因：
    /// 当您在使用 TUIRoomEngine 直播过程中接听来自 TUICallEngine 的通话时，为了避免通话的音视频数据被直播间观众拉取到，TUIRoomEngine 会做如下处理：
    /// 1. 暂停视频流上行，如果您在直播时有调用 `setLocalVideoMuteImage` 接口设置过垫片图片，直播间观众会看到您设置的垫片图片；TUICallEngine 通话结束后会自动恢复摄像头画面的上行；
    /// 2. 暂停音频流上行，TUICallEngine 通话结束后会自动恢复麦克风音频的上行。
    /// 在 TUICallEngine 通话未结束期间，您在直播间内调用设备和流相关的 API 时均会出现此错误码。
    /// 处理建议：您可以在页面上弹框提醒用户 “您正在通话中，请挂断后再试”。
    TUIErrorCallInProgress = -6001,

    /// 错误描述：
    /// 服务器内部发生未知错误，导致请求无法正常处理
    /// 错误原因：
    /// 1. 服务器端服务异常或崩溃
    /// 2. 服务器资源不足或过载
    /// 3. 服务器配置错误
    /// 处理建议：
    /// 1. 提示用户"服务器繁忙，请稍后重试"
    /// 2. 检查服务器日志定位具体问题
    /// 3. 联系腾讯云技术支持排查后台服务问题
    TUIErrorServerSystemError = 100001,

    /// 错误描述:
    /// 服务器接收到非法或不完整的请求参数，导致请求无法处理
    /// 产生原因:
    /// 1. 必填参数缺失或为空
    /// 2. 参数格式不符合要求
    /// 3. 参数值超出允许范围
    /// 4. 参数类型不匹配
    /// 处理建议:
    /// 1. 检查请求参数是否完整
    /// 2. 验证参数格式和类型是否符合API文档要求
    /// 3. 确保参数值在有效范围内
    /// 4. 查阅相关API文档确认参数规范
    TUIErrorServerInvalidParameter = 100002,

    /// 房间ID 已被使用，请选择别的房间ID。
    TUIErrorRoomIdOccupied = 100003,

    /// 进房时房间不存在，或许已被解散。
    TUIErrorRoomIdNotExist = 100004,

    /// 用户不在当前房间内。
    TUIErrorUserNotEntered = 100005,

    /// 房间成员已满。
    TUIErrorRoomUserFull = 100008,

    /// 当前房间需要密码才能进入。
    TUIErrorNeedPassword = 100018,

    /// 进房密码错误。
    TUIErrorWrongPassword = 100019,

    /// 信令请求冲突。
    TUIErrorRequestIdConflict = 100102,

    /// 当前麦位被锁。
    TUIErrorSeatLocked = 100200,

    /// 当前麦位已经有人了。
    TUIErrorSeatOccupied = 100210,

    /// 当前用户已经在麦位上。
    TUIErrorAlreadyInSeat = 100203,

    /// 上麦人数已满。
    TUIErrorAllSeatOccupied = 100205,

    /// 当前用户没有在麦上。
    TUIErrorUserNotInSeat = 100206,

    /// 不支持连麦。
    TUIErrorSeatNotSupportLinkMic = 100211,

    /// 当前房间已连线。
    TUIErrorRoomAlreadyConnected = 100401,

    /// 当前房间与其他房间连线中。
    TUIErrorRoomConnectedInOther = 100403,

    /// 当前房间连线超出最大数量限制。
    TUIErrorMaxConnectedCountLimit = 100404,

    /// 房间自定义信息 key 数量超过上限
    TUIErrorRoomMetadataExceedKeyCountLimit = 100500,

    /// 房间自定义信息 value 字节大小超过上限
    TUIErrorRoomMetadataExceedValueSizeLimit = 100501,

    /// 礼物能力未开启
    TUIErrorGiftAbilityNotEnabled = 102001,

    /// 礼物ID不存在
    TUIErrorGiftNotExist = 102002,

    /// 错误描述:
    /// 礼物服务器预验证失败, 礼物系统在发送礼物之前，会向您在控制台上配置的回调服务器地址发送“礼物发送确认请求”，如果从您的服务器获得确认码为 0，礼物系统才会真正发出礼物。
    /// 错误原因：
    /// 1. 礼物系统向您的服务器请求超时了（超时时间为两秒），例如您的服务器没有打开相应的端口，或者防火墙策略限制了外网的 http 协议访问。
    /// 2. 您的服务器没有成功解析“礼物发送确认请求”的数据包，导致您的服务器返回了数值不为 0 的确认码。
    /// 处理建议:
    /// 1. 检查服务器端口开放状态和防火墙设置。
    /// 2. 确保服务器能正确处理JSON格式的验证请求。
    TUIErrorGiftServerPreVerificationFailed = 102004,

};

/**
 * 1.2 网络质量。
 */
typedef NS_ENUM(NSUInteger, TUINetworkQuality) {

    /// 未定义。
    TUINetworkQualityUnknown = 0,

    /// 当前网络非常好。
    TUINetworkQualityExcellent = 1,

    /// 当前网络比较好。
    TUINetworkQualityGood = 2,

    /// 当前网络一般。
    TUINetworkQualityPoor = 3,

    /// 当前网络较差。
    TUINetworkQualityBad = 4,

    /// 当前网络很差。
    TUINetworkQualityVeryBad = 5,

    /// 当前网络不满足 TRTC 的最低要求。
    TUINetworkQualityDown = 6,

};

/**
 * 1.3 插件类型。
 */
typedef NS_ENUM(NSUInteger, TUIExtensionType) {

    /// 设备管理插件。
    TUIExtensionTypeDeviceManager = 1,

    /// 直播管理插件。
    TUIExtensionTypeLiveListManager = 2,

    /// 会议列表插件。
    TUIExtensionTypeConferenceListManager = 3,

    /// 会中呼叫插件。
    TUIExtensionTypeConferenceInvitationManager = 4,

    /// 直播布局插件。
    TUIExtensionTypeLiveLayoutManager = 5,

    /// 直播礼物插件
    TUIExtensionTypeLiveGiftManager = 6,

    /// 歌曲列表插件
    TUIExtensionTypeSongListManager = 7,

};

/**
 * 1.4 音频设备。
 */
typedef NS_ENUM(NSUInteger, TUIAudioPlaybackDevice) {

    /// 扬声器。
    TUIAudioPlaybackDeviceSpeakerphone = 0,

    /// 听筒。
    TUIAudioPlaybackDeviceEarpiece = 1,

};

/**
 * 1.5 前置/后置摄像头。
 */
typedef NS_ENUM(NSUInteger, TUICamera) {

    /// 前置摄像头。
    TUICameraFront = 0,

    /// 后置摄像头。
    TUICameraBack = 1,

};

/**
 * 1.6 网络质量信息。
 */
TUIENGINE_EXPORT @interface TUINetworkInfo : NSObject

/// 用户ID。
@property(nonatomic, copy, nullable) NSString* userId;

/// 网络质量。
@property(nonatomic, assign) TUINetworkQuality quality;

/// 上行丢包率，单位 (%) 该数值越小越好。
/// 如果 upLoss 为 0%，则意味着上行链路的网络质量很好，上传到云端的数据包基本不发生丢失。
/// 如果 upLoss 为 30%，则意味着 SDK 向云端发送的音视频数据包中，会有 30%丢失在传输链路中。
@property(nonatomic, assign) uint32_t upLoss;

/// 下行丢包率，单位 (%) 该数值越小越好。
/// 如果 downLoss 为 0%，则意味着下行链路的网络质量很好，从云端接收的数据包基本不发生丢失。
/// 如果 downLoss 为 30%，则意味着云端向 SDK 传输的音视频数据包中，会有 30%丢失在传输链路中。
@property(nonatomic, assign) uint32_t downLoss;

/// 网络延迟，单位 ms。
@property(nonatomic, assign) uint32_t delay;

@end

/**
 * 1.8 网络质量信息（废弃，推荐使用1.6 {@link TUINetworkInfo}）。
 */
TUIENGINE_EXPORT __attribute__((deprecated))
@interface TUINetworkQualityInfo : NSObject

/// 用户 ID。
@property(nonatomic, copy, nullable) NSString* userId;

/// 网络质量。
@property(nonatomic, assign) TUINetworkQuality quality;

@end

/**
 * 1.9 视频画面填充模式。
 */
typedef NS_ENUM(NSInteger, TUIVideoRenderParamsFillMode) {

    /// 填充模式：即将画面内容居中等比缩放以充满整个显示区域，超出显示区域的部分将会被裁剪掉，此模式下画面可能不完整。
    TUIVideoRenderParamsFillModeFill = 0,

    /// 适应模式：即按画面长边进行缩放以适应显示区域，短边部分会被填充为黑色，此模式下图像完整但可能留有黑边。
    TUIVideoRenderParamsFillModeFit = 1,

};

/**
 * 1.10 视频画面旋转方向。
 */
typedef NS_ENUM(NSInteger, TUIVideoRenderParamsRotation) {

    /// 不旋转。
    TUIVideoRenderParamsRotation_0 = 0,

    /// 顺时针旋转90度。
    TUIVideoRenderParamsRotation_90 = 1,

    /// 顺时针旋转180度。
    TUIVideoRenderParamsRotation_180 = 2,

    /// 顺时针旋转270度。
    TUIVideoRenderParamsRotation_270 = 3,

};

/**
 * 1.11 视频宽高比模式。
 */
typedef NS_ENUM(NSInteger, TUIVideoEncoderParamsResolutionMode) {

    /// 横屏分辨率，例如：Resolution_640_360 + Landscape = 640x360。
    TUIVideoEncoderParamsResolutionModeLandscape = 0,

    /// 竖屏分辨率,例如：Resolution_640_360 + Portrait = 360x640。
    TUIVideoEncoderParamsResolutionModePortrait = 1,

};

/**
 * 1.12 视频分辨率。
 */
typedef NS_ENUM(NSInteger, TUIVideoEncoderParamsResolution) {

    /// 宽高比 16:9；分辨率 640x360；建议码率（VideoCall）500kbps。
    TUIVideoEncoderParamsResolution_640_360 = 1,

    /// 宽高比 16:9；分辨率 960x540；建议码率（VideoCall）850kbps。
    TUIVideoEncoderParamsResolution_960_540 = 2,

    /// 宽高比 16:9；分辨率 1280x720；建议码率（VideoCall）1200kbps。
    TUIVideoEncoderParamsResolution_1280_720 = 3,

    /// 宽高比 16:9；分辨率 1920x1080；建议码率（VideoCall）2000kbps。
    TUIVideoEncoderParamsResolution_1920_1080 = 4,

};

/**
 * 1.13 通话中音视频房间ID。
 *
 * - intRoomId 与 strRoomId 是互斥的，若您选用 strRoomId，则 intRoomId 需要填写为 0。若两者都填，SDK 将优先选用 intRoomId。
 * - 不要混用 intRoomId 和 strRoomId，因为它们之间是不互通的，例如数字 123 和字符串 123 两个完全不同的房间。
 */
TUIENGINE_EXPORT @interface TUIRoomId : NSObject

/// 数字房间号，取值范围 ：1 - 2147483647(2^31-1)。
@property(nonatomic, assign) UInt32 intRoomId;

/// 字符串房间号，推荐取值：
/// 限制长度为 64 字节。以下为支持的字符集范围（共 89 个字符）:
/// 大小写英文字母（a-zA-Z）；
/// 数字（0-9）；
/// 空格、!、#、$、%、&、(、)、+、-、:、;、<、=、.、>、?、@、[、]、^、_、{、}、|、~、,。
@property(nonatomic, copy) NSString* _Nullable strRoomId;

@end

/**
 * 1.14 视频画面的渲染参数。
 */
TUIENGINE_EXPORT @interface TUIVideoRenderParams : NSObject

/// 视频画面填充模式。
@property(nonatomic, assign) TUIVideoRenderParamsFillMode fillMode;

/// 视频画面旋转方向。
@property(nonatomic, assign) TUIVideoRenderParamsRotation rotation;

@end

/**
 * 1.15 视频编码参数。
 */
TUIENGINE_EXPORT @interface TUIVideoEncoderParams : NSObject

/// 视频分辨率。
@property(nonatomic, assign) TUIVideoEncoderParamsResolution resolution;

/// 视频宽高比。
@property(nonatomic, assign) TUIVideoEncoderParamsResolutionMode resolutionMode;

@end

/**
 * 1.16 云端录制策略
 */
typedef NS_ENUM(NSUInteger, TUICloudRecordPolicy) {

    /// 跟随控制台配置
    TUICloudRecordPolicyFollowConsoleConfig = 0,

    /// 开启云端录制（忽略控制台配置）
    TUICloudRecordPolicyEnable = 1,

    /// 关闭云端录制（忽略控制台配置）
    TUICloudRecordPolicyDisable = 2,

};

typedef void (^TUISuccessBlock)(void);
typedef void (^TUIErrorBlock)(TUIError code, NSString* _Nonnull message);
