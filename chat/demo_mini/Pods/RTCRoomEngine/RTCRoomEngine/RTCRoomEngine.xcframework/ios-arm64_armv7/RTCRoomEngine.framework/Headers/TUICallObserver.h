/**
 * Copyright (c) 2022 Tencent. All rights reserved.
 * Module:   TUICallObserver
 * Function: TUICallObserver 主功能接口
 * Version: <:Version:>
 */

#import <Foundation/Foundation.h>
#import "TUICallDefine.h"

@class TUIRoomId, TUINetworkQualityInfo;

NS_ASSUME_NONNULL_BEGIN

@protocol TUICallObserver <NSObject>

@optional

/**
 * 通话过程中错误回调
 *
 * @param code 错误码
 * @param message  错误信息
 */
- (void)onError:(int)code message:(NSString *_Nullable)message NS_SWIFT_NAME(onError(code:message:));

/**
 * 收到通话请求的回调(仅被叫收到)
 *
 * @param callId        此次通话的唯一 ID
 * @param callerId      主叫 ID（邀请方）
 * @param calleeIdList  被叫 ID 列表（被邀请方）
 * @param mediaType     通话的媒体类型，比如视频通话、语音通话
 * @param info          扩展信息
 */
- (void)onCallReceived:(NSString *)callId
              callerId:(NSString *)callerId
          calleeIdList:(NSArray<NSString *> *)calleeIdList
             mediaType:(TUICallMediaType)mediaType
                  info:(TUICallObserverExtraInfo *)info NS_SWIFT_NAME(onCallReceived(callerId:calleeIdList:mediaType:info:));

/**
 * 通话接通的回调(主叫和被叫都可以收到)
 *
 * @param callId        此次通话的唯一 ID
 * @param mediaType     通话的媒体类型，比如视频通话、语音通话
 * @param info          扩展信息
 */
- (void)onCallBegin:(NSString *)callId mediaType:(TUICallMediaType)mediaType info:(TUICallObserverExtraInfo *)info NS_SWIFT_NAME(onCallBegin(callId:mediaType:info:));

/**
 * 通话结束的回调(主叫和被叫都可以收到)
 *
 * @param callId        此次通话的唯一 ID
 * @param mediaType     通话的媒体类型，比如视频通话、语音通话
 * @param reason        通话结束原因
 * @param userId        结束通话的用户 ID
 * @param totalTime     此次通话的时长
 * @param info          扩展信息
 */
- (void)onCallEnd:(NSString *)callId
        mediaType:(TUICallMediaType)mediaType
           reason:(TUICallEndReason)reason
           userId:(NSString *)userId
        totalTime:(float)totalTime
             info:(TUICallObserverExtraInfo *)info NS_SWIFT_NAME(onCallEnd(callId:mediaType:reason:userId:totalTime:info:));

/**
 * 通话取消的回调
 *
 * @param callId        此次通话的唯一 ID
 * @param mediaType     通话的媒体类型，比如视频通话、语音通话
 * @param reason        通话结束原因
 * @param userId        结束通话的用户 ID
 * @param info          扩展信息
 */
- (void)onCallNotConnected:(NSString *)callId
                 mediaType:(TUICallMediaType)mediaType
                    reason:(TUICallEndReason)reason
                    userId:(NSString *)userId
                      info:(TUICallObserverExtraInfo *)info NS_SWIFT_NAME(onCallNotConnected(callId:mediaType:reason:userId:info:));

/**
 * 通话媒体类型发生改变的回调
 *
 * @param oldCallMediaType 旧的通话类型
 * @param newCallMediaType 新的通话类型
 */
- (void)onCallMediaTypeChanged:(TUICallMediaType)oldCallMediaType newCallMediaType:(TUICallMediaType)newCallMediaType NS_SWIFT_NAME(onCallMediaTypeChanged(oldCallMediaType:newCallMediaType:));

/**
 * xxxx 用户拒绝通话的回调
 *
 * @param userId 拒绝用户的 ID
 */
- (void)onUserReject:(NSString *)userId NS_SWIFT_NAME(onUserReject(userId:));

/**
 * xxxx 用户不响应的回调
 *
 * @param userId 无响应用户的 ID
 */
- (void)onUserNoResponse:(NSString *)userId NS_SWIFT_NAME(onUserNoResponse(userId:));

/**
 * xxxx 用户忙线的回调
 *
 * @param userId 忙线用户的 ID
 */
- (void)onUserLineBusy:(NSString *)userId NS_SWIFT_NAME(onUserLineBusy(userId:));

/**
 * 当其他用户被邀请加入通话时的回调
 *
 * @param userId 被邀请的用户 ID
 */
- (void)onUserInviting:(NSString *)userId NS_SWIFT_NAME(onUserInviting(userId:));

/**
 * xxxx 用户加入通话的回调
 *
 * @param userId 加入当前通话的用户 ID
 */
- (void)onUserJoin:(NSString *)userId NS_SWIFT_NAME(onUserJoin(userId:));

/**
 * xxxx 用户离开通话的回调
 *
 * @param userId 离开当前通话的用户 ID
 */
- (void)onUserLeave:(NSString *)userId NS_SWIFT_NAME(onUserLeave(userId:));

/**
 * xxxx 远端用户是否有视频流的回调
 *
 * @param userId           通话用户 ID
 * @param isVideoAvailable 用户视频是否可用
 */
- (void)onUserVideoAvailable:(NSString *)userId isVideoAvailable:(BOOL)isVideoAvailable NS_SWIFT_NAME(onUserVideoAvailable(userId:isVideoAvailable:));

/**
 * xxxx 远端用户是否有音频流的回调
 *
 * @param userId           通话用户 ID
 * @param isAudioAvailable 用户音频是否可用
 */
- (void)onUserAudioAvailable:(NSString *)userId isAudioAvailable:(BOOL)isAudioAvailable NS_SWIFT_NAME(onUserAudioAvailable(userId:isAudioAvailable:));

/**
 * 所有用户音量大小的反馈回调
 *
 * @param volumeMap 音量表，根据每个 userId 可以获取对应用户的音量大小，音量范围：0-100
 */
- (void)onUserVoiceVolumeChanged:(NSDictionary<NSString *, NSNumber *> *)volumeMap NS_SWIFT_NAME(onUserVoiceVolumeChanged(volumeMap:));

/**
 * 所有用户网络质量的反馈回调
 *
 * @param networkQualityList 网络状态，根据每个 userId 可以获取对应用户当前的网络质量
 */
- (void)onUserNetworkQualityChanged:(NSArray<TUINetworkQualityInfo *> *)networkQualityList NS_SWIFT_NAME(onUserNetworkQualityChanged(networkQualityList:));

/**
 * 当前用户被踢下线：此时可以 UI 提示用户,并再次重新调用初始化
 */
- (void)onKickedOffline NS_SWIFT_NAME(onKickedOffline());

/**
 * 在线时票据过期：此时您需要生成新的 userSig,并再次重新调用初始化
 */
- (void)onUserSigExpired NS_SWIFT_NAME(onUserSigExpired());

/**
 * 收到全局事件
 */
- (void)on:(NSString *)key data:(NSString *)jsonData NS_SWIFT_NAME(on(key:data:));

/**
 * 此接口已于2025年3月废弃，推荐使用新的 onCallReceived 回调，功能更强，信息更全面；
 */
- (void)onCallReceived:(NSString *)callerId
          calleeIdList:(NSArray<NSString *> *)calleeIdList
               groupId:(NSString *_Nullable)groupId
         callMediaType:(TUICallMediaType)callMediaType NS_SWIFT_NAME(onCallReceived(callerId:calleeIdList:groupId:callMediaType:)) __attribute__((deprecated("Deprecated from v3.0")));

/**
 * 此接口已于2025年3月废弃，推荐使用新的 onCallReceived 回调，功能更强，信息更全面；
 */
- (void)onCallReceived:(NSString *)callerId
          calleeIdList:(NSArray<NSString *> *)calleeIdList
               groupId:(NSString *_Nullable)groupId
         callMediaType:(TUICallMediaType)callMediaType
              userData:(NSString *_Nullable)userData NS_SWIFT_NAME(onCallReceived(callerId:calleeIdList:groupId:callMediaType:userData:)) __attribute__((deprecated("Deprecated from v3.0")));

/**
 * 此接口已于2025年3月废弃, 推荐使用 onCallNotConnected 回调，功能更强，信息更全面；
 */
- (void)onCallCancelled:(NSString *)callerId NS_SWIFT_NAME(onCallCancelled(callerId:)) __attribute__((deprecated("Deprecated from v3.0")));

/**
 * 此接口已于2025年3月废弃，推荐使用新的 onCallBegin 回调，功能更强，信息更全面；
 */
- (void)onCallBegin:(TUIRoomId *)roomId callMediaType:(TUICallMediaType)callMediaType callRole:(TUICallRole)callRole NS_SWIFT_NAME(onCallBegin(roomId:callMediaType:callRole:)) __attribute__((deprecated("Deprecated from v3.0")));

/**
 * 此接口已于2025年3月废弃，推荐使用新的 onCallEnd 回调，功能更强，信息更全面；
 */
- (void)onCallEnd:(TUIRoomId *)roomId
    callMediaType:(TUICallMediaType)callMediaType
         callRole:(TUICallRole)callRole
        totalTime:(float)totalTime NS_SWIFT_NAME(onCallEnd(roomId:callMediaType:callRole:totalTime:)) __attribute__((deprecated("Deprecated from v3.0")));

@end

NS_ASSUME_NONNULL_END
