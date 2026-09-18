/**
 * Copyright (c) 2024 Tencent. All rights reserved.
 * Module:   TUIRoomObserver @ TUIKitEngine
 * Function: TUIRoomEngine的事件回调接口
 */
#import <Foundation/Foundation.h>
#import "TUIRoomDefine.h"
#import "TUIRoomDeviceManager.h"

NS_ASSUME_NONNULL_BEGIN

@protocol TUIRoomObserver <NSObject>
@optional

/////////////////////////////////////////////////////////////////////////////////
//
//                      错误事件回调
//
///////////////////////////////////////////////////////////////

/**
 * 1.1 错误事件回调
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * 当发生错误事件时触发，表示 SDK 抛出的不可恢复的错误，例如进入房间失败或设备开启失败等。
 * @param errorCode 错误码，请参见：{@link TUIError}。
 * @param message  错误信息。
 */
- (void)onError:(TUIError)errorCode message:(NSString *)message NS_SWIFT_NAME(onError(error:message:));

/////////////////////////////////////////////////////////////////////////////////
//
//                   登录状态事件回调
//
/////////////////////////////////////////////////////////////////////////////////

/**
 * 2.1 用户被踢下线
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * 当用户被踢下线时触发。
 * @param message 被踢下线的描述。
 */
- (void)onKickedOffLine:(NSString *)message NS_SWIFT_NAME(onKickedOffLine(message:));

/**
 * 2.2 用户凭证超时事件
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * 用户的凭证过期时触发。
 */
- (void)onUserSigExpired NS_SWIFT_NAME(onUserSigExpired());

/////////////////////////////////////////////////////////////////////////////////
//
//                   房间内事件回调
//
/////////////////////////////////////////////////////////////////////////////////

/**
 * 3.1 房间名称更改事件
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * 房间名称改变时触发。
 * @param roomId 房间ID。
 * @param roomName 房间名称。
 */
- (void)onRoomNameChanged:(NSString *)roomId roomName:(NSString *)roomName NS_SWIFT_NAME(onRoomNameChanged(roomId:roomName:));

/**
 * 3.2 房间内所有用户麦克风被禁用事件
 *
 * @note 此函数仅支持会议房间类型({@link TUIRoomTypeConference})。
 * 所有用户的麦克风禁用状态改变时触发。
 * @param roomId 房间ID。
 * @param isDisable 是否被禁用。
 */
- (void)onAllUserMicrophoneDisableChanged:(NSString *)roomId isDisable:(BOOL)isDisable NS_SWIFT_NAME(onAllUserMicrophoneDisableChanged(roomId:isDisable:));

/**
 * 3.3 房间内所有用户摄像头被禁用事件
 *
 * @note 此函数仅支持会议房间类型({@link TUIRoomTypeConference})。
 * 所有用户的摄像头禁用状态改变时触发。
 * @param roomId 房间ID。
 * @param isDisable 是否被禁用。
 */
- (void)onAllUserCameraDisableChanged:(NSString *)roomId isDisable:(BOOL)isDisable NS_SWIFT_NAME(onAllUserCameraDisableChanged(roomId:isDisable:));

/**
 * 3.4 房间内所有用户屏幕分享被禁用事件
 *
 * @note 此函数仅支持会议房间类型({@link TUIRoomTypeConference})。
 * 所有用户的屏幕共享权限改变时触发。
 * @param roomId 房间ID。
 * @param isDisable 是否被禁用。
 */
- (void)onScreenShareForAllUserDisableChanged:(NSString *)roomId isDisable:(BOOL)isDisable NS_SWIFT_NAME(onScreenShareForAllUserDisableChanged(roomId:isDisable:));

/**
 * 3.5 房间内用户发送文本消息被禁用事件
 *
 * @note 此函数仅支持会议房间类型({@link TUIRoomTypeConference})。
 * 所有用户的发送消息权限改变时触发。
 * @param roomId 房间ID。
 * @param isDisable 是否被禁用。
 */
- (void)onSendMessageForAllUserDisableChanged:(NSString *)roomId isDisable:(BOOL)isDisable NS_SWIFT_NAME(onSendMessageForAllUserDisableChanged(roomId:isDisable:));

/**
 * 3.6 房间被解散事件
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * 房间被解散时触发。
 * @param roomId 房间ID。
 * @param reason 房间解散原因，请参见：{@link TUIRoomDismissedReason}。
 */
- (void)onRoomDismissed:(NSString *)roomId reason:(TUIRoomDismissedReason)reason NS_SWIFT_NAME(onRoomDismissed(roomId:reason:));

/**
 * 3.7 被踢出房间事件
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * 用户被房主/管理员踢出房间触发。
 * @param roomId 房间ID。
 * @param reason 被踢出原因。
 * @param message 被踢出的描述。
 */
- (void)onKickedOutOfRoom:(NSString *)roomId reason:(TUIKickedOutOfRoomReason)reason message:(NSString *)message NS_SWIFT_NAME(onKickedOutOfRoom(roomId:reason:message:));

/**
 * 3.8 房间上麦模式发生变化
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * 房间上麦模式发生变化时触发
 * @param roomId 房间ID。
 * @param seatMode 上麦模式。
 */
- (void)onRoomSeatModeChanged:(NSString *)roomId seatMode:(TUISeatMode)seatMode NS_SWIFT_NAME(onRoomSeatModeChanged(roomId:seatMode:));

/**
 * 3.9 房间内人员数量发生变化
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * 房间内人数发生变化时触发。
 * @param roomId 房间ID。
 * @param userCount 人员数量。
 */
- (void)onRoomUserCountChanged:(NSString *)roomId userCount:(NSInteger)userCount NS_SWIFT_NAME(onRoomUserCountChanged(roomId:userCount:));

/**
 * 3.10 房间内自定义信息发生变化
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * 房间自定义信息改变时触发。
 * @param key 房间自定义信息 key
 * @param value 房间自定义信息 value
 */
- (void)onRoomMetadataChanged:(NSString *)key value:(NSString *)value NS_SWIFT_NAME(onRoomMetadataChanged(key:value:));

/////////////////////////////////////////////////////////////////////////////////
//
//                   房间内用户事件回调
//
/////////////////////////////////////////////////////////////////////////////////

/**
 * 4.1 远端用户进房事件
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * 远端用户进入房间时触发。
 * @param roomId 房间ID。
 * @param userInfo 用户信息。
 */
- (void)onRemoteUserEnterRoom:(NSString *)roomId userInfo:(TUIUserInfo *)userInfo NS_SWIFT_NAME(onRemoteUserEnterRoom(roomId:userInfo:));

/**
 * 4.2 远端用户离开房间事件
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * 远端用户离开房间时触发。
 * @param roomId 房间ID。
 * @param userInfo 用户信息。
 */
- (void)onRemoteUserLeaveRoom:(NSString *)roomId userInfo:(TUIUserInfo *)userInfo NS_SWIFT_NAME(onRemoteUserLeaveRoom(roomId:userInfo:));

/**
 * 4.3 房间内用户信息发生变化事件。
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * 当房间内用户信息发生变化时触发。
 * @param userInfo 用户信息。
 * @param modifyFlag 用户信息参数变更Key, 可参考{@link TUIUserInfoModifyFlag}。
 */
- (void)onUserInfoChanged:(TUIUserInfo *)userInfo modifyFlag:(TUIUserInfoModifyFlag)modifyFlag NS_SWIFT_NAME(onUserInfoChanged(userInfo:modifyFlag:));

/**
 * 4.4 用户视频状态发生变化事件
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * 当用户的视频状态改变时触发。
 * @param userId 用户ID。
 * @param streamType 视频流类型。
 * @param hasVideo 是否有视频流。
 * @param reason 视频流发生变化原因 {@link TUIChangeReasonBySelf}: 自己切换  {@link TUIChangeReasonByAdmin}: 被管理员切换。
 */
- (void)onUserVideoStateChanged:(NSString *)userId streamType:(TUIVideoStreamType)streamType hasVideo:(BOOL)hasVideo reason:(TUIChangeReason)reason NS_SWIFT_NAME(onUserVideoStateChanged(userId:streamType:hasVideo:reason:));

/**
 * 4.5 用户音频状态发生变化事件
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * 当用户的音频状态改变时触发。
 * @param userId 用户ID。
 * @param hasAudio 是否有音频流。
 * @param reason 视频流发生变化原因 {@link TUIChangeReasonBySelf}: 自己切换  {@link TUIChangeReasonByAdmin}: 被管理员切换。
 */
- (void)onUserAudioStateChanged:(NSString *)userId hasAudio:(BOOL)hasAudio reason:(TUIChangeReason)reason NS_SWIFT_NAME(onUserAudioStateChanged(userId:hasAudio:reason:));

/**
 * 4.6 用户音量变化事件
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * 当用户的音量改变时触发。
 * @param volumeMap 用户音量字典 key: userId, value: 用于承载所有正在说话的用户的音量大小，取值范围 0 - 100。
 */
- (void)onUserVoiceVolumeChanged:(NSDictionary<NSString *, NSNumber *> *)volumeMap NS_SWIFT_NAME(onUserVoiceVolumeChanged(volumeMap:));

/**
 * 4.7 用户文本消息发送能力发生变化事件
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * 当用户的发送消息权限改变时触发。
 * @param userId 用户ID。
 * @param isDisable 是否被禁止发送文本消息 {@link YES}: 用户被禁止发送消息 {@link NO}: 用户被解除禁止，可以发送消息。
 */
- (void)onSendMessageForUserDisableChanged:(NSString *)roomId userId:(NSString *)userId isDisable:(BOOL)muted NS_SWIFT_NAME(OnSendMessageForUserDisableChanged(roomId:userId:isDisable:));

/**
 * 4.8 用户网络状态变化事件
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * 当用户的网络质量改变时触发。
 * @param networkList 用户网络状态数组，可参见 {@link TUINetworkInfo} 对象。
 */
- (void)onUserNetworkQualityChanged:(NSArray<TUINetworkInfo *> *)networkList NS_SWIFT_NAME(onUserNetworkQualityChanged(networkList:));

/**
 * 4.9  屏幕分享暂停
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * 用户的屏幕分享暂停时触发。
 * @param reason 暂停原因，0：用户主动暂停；1：屏幕窗口不可见暂停（Mac）或设置屏幕分享参数导致的暂停（Windows）；2：屏幕分享窗口被最小化导致的暂停（仅 Windows）；3：屏幕分享窗口被隐藏导致的暂停（仅 Windows）；4：系统停止录屏（仅iOS）。
 */
- (void)onUserScreenCapturePaused:(NSInteger)reason NS_SWIFT_NAME(onUserScreenCapturePaused(reason:));

/**
 * 4.10  屏幕分享恢复
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * 用户的屏幕分享恢复时触发。
 * @param reason 恢复原因，0：用户主动恢复；1：屏幕窗口恢复可见从而恢复分享（Mac）或屏幕分享参数设置完毕后自动恢复（Windows）2：屏幕分享窗口从最小化被恢复（仅 Windows）；3：屏幕分享窗口从隐藏被恢复（仅 Windows）；4：系统恢复录屏（仅iOS）
 */
- (void)onUserScreenCaptureResumed:(NSInteger)reason NS_SWIFT_NAME(onUserScreenCaptureResumed(reason:));

/**
 * 4.11  屏幕分享结束
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * 用户的屏幕分享停止时触发。
 * @param reason 停止原因，0：用户主动停止；1：屏幕窗口关闭导致停止；2：表示屏幕分享的显示屏状态变更（如接口被拔出、投影模式变更等）。
 */
- (void)onUserScreenCaptureStopped:(NSInteger)reason NS_SWIFT_NAME(onUserScreenCaptureStopped(reason:));

/**
 * 4.12  用户视频大小发生改变
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * 用户视频大小发生改变时触发。
 * @param roomId 房间ID。
 * @param userId 当本地为观众且与主播成功连麦时，该参数表示主播的用户ID；否则，表示混流ID。
 * @param streamType 视频流类型。
 * @param width 视频流的宽度。
 * @param height 视频流的高度。
 */
- (void)onUserVideoSizeChanged:(NSString *)roomId userId:(NSString *)userId streamType:(TUIVideoStreamType)streamType width:(int)width height:(int)height NS_SWIFT_NAME(onUserVideoSizeChanged(roomId:userId:streamType:width:height:));

/////////////////////////////////////////////////////////////////////////////////
//
//                   房间内麦位事件回调
//
/////////////////////////////////////////////////////////////////////////////////

/**
 * 5.1 麦位列表发生变化事件
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * 当麦位列表改变时触发。
 * @param roomId 当前的房间 ID
 * @param seatList 目前麦上最新的用户列表，包含新上麦的用户。
 * @param newlySeatedUsers 新上麦的用户列表。
 * @param newlyLeftUsers 新下麦的用户列表。
 */
- (void)onSeatListChanged:(NSString *)roomId
                 seatList:(NSArray<TUISeatFullInfo *> *)seatList
         newlySeatedUsers:(NSArray<TUIUserInfo *> *)newlySeatedUsers
           newlyLeftUsers:(NSArray<TUIUserInfo *> *)newlyLeftUsers NS_SWIFT_NAME(onSeatListChanged(roomId:seatList:newlySeatedUsers:newlyLeftUsers:));

/**
 * 5.2 收到用户被踢下麦事件
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * 当用户被踢下麦时触发。
 * @param seatIndex 麦位编号。
 * @param operateUser 操作踢人的（主持人/管理员）用户信息。
 * @param extensionInfo 扩展信息。
 */
- (void)onKickedOffSeat:(NSInteger)seatIndex operateUser:(TUIUserInfo *)operateUser extensionInfo:(NSString *)extensionInfo NS_SWIFT_NAME(onKickedOffSeat(seatIndex:operateUser:extensionInfo:));

/////////////////////////////////////////////////////////////////////////////////
//
//                   请求信令事件回调
//
/////////////////////////////////////////////////////////////////////////////////

/**
 * 6.1 收到请求消息事件
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * 当收到其他用户的请求时触发。
 * @param request 请求内容，可参见 {@link TUIRequest} 对象。
 */
- (void)onRequestReceived:(TUIRequest *)request NS_SWIFT_NAME(onRequestReceived(request:));

/**
 * 6.2 收到请求被取消的事件
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * 当其他用户取消请求时触发。
 * @param request 请求内容，可参见 {@link TUIRequest} 对象。
 * @param operateUser 取消信令的用户信息。
 */
- (void)onRequestCancelled:(TUIRequest *)request operateUser:(TUIUserInfo *)operateUser NS_SWIFT_NAME(onRequestCancelled(request:operateUser:));

/**
 * 6.3 收到请求被其他 管理员/房主 处理事件
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * 收到请求被其他 管理员/房主 处理时触发。
 * @param request 请求内容，可参见 {@link TUIRequest} 对象。
 * @param operateUser 取消信令的用户信息。
 */
- (void)onRequestProcessed:(TUIRequest *)request operateUser:(TUIUserInfo *)operateUser NS_SWIFT_NAME(onRequestProcessed(request:operateUser:));

/////////////////////////////////////////////////////////////////////////////////
//
//                   房间内消息回调
//
/////////////////////////////////////////////////////////////////////////////////

/**
 * 7.1 收到了文本消息
 *
 * @param textMessage 消息对象，可参见 {@link $TUIRoomTextMessage$} 对象。
 */
- (void)onReceiveTextMessage:(TUIRoomTextMessage *)textMessage NS_SWIFT_NAME(onReceiveTextMessage(textMessage:));

/**
 * 7.2 收到了自定义消息
 *
 * @param customMessage 消息对象，可参见 {@link $TUIRoomCustomMessage$} 对象。
 */
- (void)onReceiveCustomMessage:(TUIRoomCustomMessage *)customMessage NS_SWIFT_NAME(onReceiveCustomMessage(customMessage:));

/////////////////////////////////////////////////////////////////////////////////
//
//                   State 相关回调
//
/////////////////////////////////////////////////////////////////////////////////

/**
 * 8.1 收到全局事件
 */
- (void)on:(NSString *)key data:(NSString *)jsonData NS_SWIFT_NAME(on(key:data:));

/////////////////////////////////////////////////////////////////////////////////
//
//                   废弃回调
//
/////////////////////////////////////////////////////////////////////////////////

#if !TARGET_OS_IPHONE && TARGET_OS_MAC

/**
 * 本地设备添加事件
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * 当用户的设备状态发生改变时触发，例如用户的麦克风或摄像头被打开或关闭。当本地设备（包括摄像头、麦克风以及扬声器）添加时，SDK 便会抛出此事件回调。
 * @deprecated v2.0 版本开始不推荐使用,建议使用{$TUIRoomDeviceManager$}中的{@link onDeviceChanged}代替。
 * @param deviceId 设备 ID。
 * @param type 设备类型。
 * @param state 通断状态，0：设备已添加；1：设备已被移除；2：设备已启用。
 */
- (void)onDeviceChanged:(NSString *)deviceId type:(TUIMediaDeviceType)type state:(TUIMediaDeviceState)state NS_SWIFT_NAME(onDeviceChanged(deviceId:type:state:)) __attribute__((deprecated("use onDeviceChanged in TUIRoomDeviceManager instead")));

#endif

/**
 * 麦位列表发生变化事件
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * 当麦位列表改变时触发。
 * @deprecated 此回调在 v3.5 版本开始废弃，未来会被回收，请使用 onSeatListChanged(roomId, seatList, newlySeatedUsers, newlyLeftUsers) 代替。
 * @param seatList 目前麦上最新的用户列表，包含新上麦的用户。
 * @param seatedList 新上麦的用户列表。
 * @param leftList 新下麦的用户列表。
 */
- (void)onSeatListChanged:(NSArray<TUISeatInfo *> *)seatList seated:(NSArray<TUISeatInfo *> *)seatedList left:(NSArray<TUISeatInfo *> *)leftList NS_SWIFT_NAME(onSeatListChanged(seatList:seated:left:)) __attribute__((deprecated));

/**
 * 收到用户被踢下麦事件
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * 当用户被踢下麦时触发。
 * @deprecated 此回调在 v3.5 版本开始废弃，未来会被回收，请使用 onKickedOffSeat(seatIndex, operateUser, extensionInfo) 代替。
 * @param seatIndex 麦位编号。
 * @param operateUser 操作踢人的（主持人/管理员）用户信息。
 */
- (void)onKickedOffSeat:(NSInteger)seatIndex operateUser:(TUIUserInfo *)operateUser NS_SWIFT_NAME(onKickedOffSeat(seatIndex:operateUser:)) __attribute__((deprecated));

@end
NS_ASSUME_NONNULL_END
