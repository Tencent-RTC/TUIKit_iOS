/**
 * Copyright (c) 2024 Tencent. All rights reserved.
 */
#import "TUIRoomEngine.h"

@class TRTCCloud;
@class TXDeviceManager;
@class TXAudioEffectManager;
@class TXBeautyManager;

NS_ASSUME_NONNULL_BEGIN
@interface TUIRoomEngine (deprecated)

/////////////////////////////////////////////////////////////////////////////////
//
//                    弃用接口（建议使用对应的新接口）
//
/////////////////////////////////////////////////////////////////////////////////

/**
 * 获得设备管理对象
 *
 * @deprecated v1.5.0 版本开始不推荐使用。
 */
- (TXDeviceManager *)getDeviceManager NS_SWIFT_NAME(getDeviceManager()) __attribute__((deprecated("Deprecated from v1.5.0")));

/**
 * 获得音效管理对象
 *
 * @deprecated v1.5.0 版本开始不推荐使用。
 */
- (TXAudioEffectManager *)getAudioEffectManager NS_SWIFT_NAME(getAudioEffectManager()) __attribute__((deprecated("Deprecated from v1.5.0")));

/**
 * 获得美颜管理对象
 *
 * @deprecated v1.5.0 版本开始不推荐使用。
 */
- (TXBeautyManager *)getBeautyManager NS_SWIFT_NAME(getBeautyManager()) __attribute__((deprecated("Deprecated from v1.5.0")));

/**
 * 设置本地用户视频渲染的视图控件
 *
 * @deprecated v1.6.1 版本开始不推荐使用。
 */
- (void)setLocalVideoView:(TUIVideoStreamType)streamType view:(TUIVideoView *__nullable)view NS_SWIFT_NAME(setLocalVideoView(streamType:view:)) __attribute__((deprecated("Deprecated from v1.6.1")));

#if TARGET_OS_IPHONE

/**
 * 切换前置或后置摄像头（仅适用于移动端）
 *
 * @deprecated v2.0 版本开始不推荐使用,建议使用{$TUIRoomDeviceManager$}中的{@link switchCamera}代替。
 * @return 0：操作成功；负数：操作失败。
 */
- (NSInteger)switchCamera:(BOOL)frontCamera NS_SWIFT_NAME(switchCamera(frontCamera:)) __attribute__((deprecated("Deprecated from v2.0")));

#endif

#if !TARGET_OS_IPHONE && TARGET_OS_MAC

/**
 * 获取设备列表（仅适用于桌面端）
 *
 * @deprecated v2.0 版本开始不推荐使用,建议使用{$TUIRoomDeviceManager$}中的{@link getDevicesList}代替。
 * @param type  设备类型，指定需要获取哪种设备的列表。详见 TXMediaDeviceType 定义。
 * @note
 * - 使用完毕后请调用 release 方法释放资源，这样可以让 SDK 维护 ITXDeviceCollection 对象的生命周期。
 *   - 不要使用 delete 释放返回的 Collection 对象，delete ITXDeviceCollection* 指针会导致异常崩溃。
 *   - type 只支持 TXMediaDeviceTypeMic、TXMediaDeviceTypeSpeaker、TXMediaDeviceTypeCamera。
 *   - 此接口只支持 Mac 和 Windows 平台。
 */
- (NSArray<TXMediaDeviceInfo *> *_Nullable)getDevicesList:(TUIMediaDeviceType)type NS_SWIFT_NAME(getDevicesList(type:)) __attribute__((deprecated("Deprecated from v2.0")));

/**
 * 设置当前要使用的设备（仅适用于桌面端）
 *
 * @deprecated v2.0 版本开始不推荐使用,建议使用{$TUIRoomDeviceManager$}中的{@link setCurrentDevice}代替。
 * 设置当前要使用的设备后,SDK会通过 {@link TUIRoomObserver} 中的 {@link onDeviceChanged} 通知您。
 * @param type 设备类型，详见 TXMediaDeviceType 定义。
 * @param deviceId 设备ID，您可以通过接口 {@link getDevicesList} 获得设备 ID。
 * @return 0：操作成功；负数：操作失败。
 */
- (NSInteger)setCurrentDevice:(TUIMediaDeviceType)type deviceId:(NSString *)deviceId NS_SWIFT_NAME(setCurrentDevice(type:deviceId:)) __attribute__((deprecated("Deprecated from v2.0")));

#endif

/**
 * 调用实验性接口
 *
 * @deprecated v3.0 版本开始不推荐使用
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * @param  jsonStr 接口信息。
 * @return 返回结果
 */
+ (id)callExperimentalAPI:(NSString *)jsonStr NS_SWIFT_NAME(callExperimentalAPI(jsonStr:)) __attribute__((deprecated("Deprecated from v3.0")));

/**
 * 上麦（上麦发言模式下，需要申请）
 *
 * @deprecated 此接口在 v3.5 版本开始废弃，未来会被回收，请使用 takeSeat(seatIndex, timeout, extensionInfo, onAccepted, onRejected, onCancelled, onTimeout, onSuccess, onError) 代替。
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * 上麦成功后,SDK会通过 {@link TUIRoomObserver} 中的 {@link onSeatListChanged} 通知房间内用户。
 * @note 开启上麦发言模式时，需要向主持人或管理员发起申请才允许上麦。
 *       开启自由发言模式，直播场景可以自由上麦，上麦后开麦发言，会议场景无需调用该接口，即可开麦发言。
 * @param seatIndex 麦位编号。未开启麦位、不关心麦位序列的情况下，填-1即可。
 * @param timeout 超时时间，单位秒，如果设置为 0，SDK 不会做超时检测，也不会触发超时回调。
 * @param onAccepted 邀请被接受的回调。
 * @param onRejected 邀请被拒绝的回调。
 * @param onCancelled 邀请被取消的回调。
 * @param onTimeout 邀请超时未处理的回调。
 * @param onError 邀请发生错误的回调。
 * @return TUIRequest 请求体。
 */
- (TUIRequest *)takeSeat:(NSInteger)seatIndex
                 timeout:(NSTimeInterval)timeout
              onAccepted:(TUIRequestAcceptedBlock)onAccepted
              onRejected:(TUIRequestRejectedBlock)onRejected
             onCancelled:(TUIRequestCancelledBlock)onCancelled
               onTimeout:(TUIRequestTimeoutBlock)onTimeout
                 onError:(TUIRequestErrorBlock)onError NS_SWIFT_NAME(takeSeat(_:timeout:onAccepted:onRejected:onCancelled:onTimeout:onError:)) __attribute__((deprecated("Deprecated from v3.5")));

/**
 * 主持人/管理员 邀请用户上麦
 *
 * @deprecated 此接口在 v3.5 版本开始废弃，未来会被回收，请使用 takeUserOnSeatByAdmin(seatIndex, userId, timeout, extensionInfo, onAccepted, onRejected, onCancelled, onTimeout, onSuccess, onError) 代替。
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * 接口调用成功后,SDK会通过 {@link TUIRoomObserver} 中的 {@link onRequestReceived} 通知被邀请用户。
 * @param seatIndex 麦位编号。未开启麦位、不关心麦位序列的情况下，填-1即可。
 * @param userId 用户ID。
 * @param timeout 超时时间，单位秒，如果设置为 0，SDK 不会做超时检测，也不会触发超时回调。
 * @param onAccepted 邀请被接受的回调。
 * @param onRejected 邀请被拒绝的回调。
 * @param onCancelled 邀请被取消的回调。
 * @param onTimeout 邀请超时未处理的回调。
 * @param onError 邀请发生错误的回调。
 * @return TUIRequest 请求体。
 */
- (TUIRequest *)takeUserOnSeatByAdmin:(NSInteger)seatIndex
                               userId:(NSString *)userId
                              timeout:(NSTimeInterval)timeout
                           onAccepted:(TUIRequestAcceptedBlock)onAccepted
                           onRejected:(TUIRequestRejectedBlock)onRejected
                          onCancelled:(TUIRequestCancelledBlock)onCancelled
                            onTimeout:(TUIRequestTimeoutBlock)onTimeout
                              onError:(TUIRequestErrorBlock)onError NS_SWIFT_NAME(takeUserOnSeatByAdmin(_:userId:timeout:onAccepted:onRejected:onCancelled:onTimeout:onError:)) __attribute__((deprecated("Deprecated from v3.5")));

/**
 * 主持人/管理员 将用户踢下麦
 *
 * @deprecated 此接口在 v3.5 版本开始废弃，未来会被回收，请使用 kickUserOffSeatByAdmin(seatIndex, userId, extensionInfo, onSuccess, onError) 代替。
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * 接口调用成功后,SDK会通过 {@link TUIRoomObserver} 中的 {@link onSeatListChanged} 通知房间内用户。
 * @param seatIndex 麦位编号。未开启麦位、不关心麦位序列的情况下，填-1即可。
 * @param userId 用户ID。
 * @param onSuccess 成功回调。
 * @param onError 失败回调。
 */
- (void)kickUserOffSeatByAdmin:(NSInteger)seatIndex
                        userId:(NSString *)userId
                     onSuccess:(TUISuccessBlock)onSuccess
                       onError:(TUIErrorBlock)onError NS_SWIFT_NAME(kickUserOffSeatByAdmin(_:userId:onSuccess:onError:)) __attribute__((deprecated("Deprecated from v3.5")));

/**
 * 回复请求
 *
 * @deprecated 此接口在 v3.5 版本开始废弃，未来会被回收，请使用 responseRemoteRequest(requestId, agree, extensionInfo, onSuccess, onError) 代替。
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * @note 在收到信令请求时，可以使用此接口来回复接收到的请求。
 * @param requestId 请求ID(发送请求的接口返回或者OnRequestReceived事件通知)。
 * @param agree 是否同意 YES: 同意请求, NO: 拒绝请求。
 * @param onSuccess 成功回调。
 * @param onError 失败回调。
 */
- (void)responseRemoteRequest:(NSString *)requestId
                        agree:(BOOL)agree
                    onSuccess:(TUISuccessBlock)onSuccess
                      onError:(TUIErrorBlock)onError NS_SWIFT_NAME(responseRemoteRequest(_:agree:onSuccess:onError:)) __attribute__((deprecated("Deprecated from v3.5")));

NS_ASSUME_NONNULL_END
@end
