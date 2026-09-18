/**
 * Copyright (c) 2022 Tencent. All rights reserved.
 * Module:   TUICallEngine
 * Function: TUICallEngine's main feature API
 * Version: <:Version:>
 */

#import <Foundation/Foundation.h>
#import "TUICallObserver.h"
#import "TUICallDefine.h"
#import "TUICommonDefine.h"

@class TRTCCloud;

NS_ASSUME_NONNULL_BEGIN

TUIENGINE_EXPORT @interface TUICallEngine : NSObject

/**
 * 创建 TUICallEngine 实例（单例模式）
 */
+ (TUICallEngine *)createInstance NS_SWIFT_NAME(createInstance());

/**
 * 销毁 TUICallEngine 实例（单例模式）
 */
+ (void)destroyInstance NS_SWIFT_NAME(destroyInstance());

/**
 * 初始化函数，请在使用所有功能之前先调用该函数，以便完成包含通话服务鉴权在内初始化动作。
 *
 * @param sdkAppId 应用ID
 * @param userId   当前用户的 ID
 * @param userSig  安全保护签名
 */
- (void)init:(int)sdkAppId userId:(NSString *)userId userSig:(NSString *)userSig succ:(TUICallSucc)succ fail:(TUICallFail)fail;

/**
 * 添加回调接口，您可以通过这个接口，监听TUICallObserver相关的事件回调。
 */
- (void)addObserver:(id<TUICallObserver>)observer NS_SWIFT_NAME(addObserver(_:));

/**
 * 移除事件回调
 */
- (void)removeObserver:(id<TUICallObserver>)observer NS_SWIFT_NAME(removeObserver(_:));

/**
 * 发起 1VN 通话
 *
 * @param userIdList    目标用户的 userId 列表
 * @param callMediaType 通话的媒体类型，例如：视频通话、语音通话
 * @param params        通话参数扩展字段，例如：离线推送自定义内容
 */
- (void)calls:(NSArray<NSString *> *)userIdList callMediaType:(TUICallMediaType)callMediaType params:(TUICallParams *_Nullable)params succ:(TUICallSucc)succ fail:(TUICallFail)fail NS_SWIFT_NAME(calls(userIdList:callMediaType:params:succ:fail:));

/**
 * 接受当前通话，当您作为被叫收到 onCallReceived() 的回调时，可以调用该函数接听来电。
 */
- (void)accept:(TUICallSucc)succ fail:(TUICallFail)fail NS_SWIFT_NAME(accept(succ:fail:));

/**
 * 拒绝当前通话，当您作为被叫收到 onCallReceived() 的回调时，可以调用该函数拒绝来电。
 */
- (void)reject:(TUICallSucc)succ fail:(TUICallFail)fail NS_SWIFT_NAME(reject(succ:fail:));

/**
 * 挂断当前通话，当您处于通话中，可以调用该函数结束通话。
 */
- (void)hangup:(TUICallSucc)succ fail:(TUICallFail)fail NS_SWIFT_NAME(hangup(succ:fail:));

/**
 * 忽略当前通话，当您作为被叫收到 onCallReceived() 的回调时，可以调用该函数忽略来电，此时主叫会收到 onUserLineBusy 的回调。
 * 备注：如果您的业务中存在直播、会议等场景，在直播/会议中的情况时，也可以调用这个函数来忽略此次来电。
 */
- (void)ignore:(TUICallSucc)succ fail:(TUICallFail)fail NS_SWIFT_NAME(ignore(succ:fail:));

/**
 * 主动加入此次多人通话。
 *
 * @param callId 此次通话的唯一ID
 */
- (void)join:(NSString *)callId succ:(TUICallSucc)succ fail:(TUICallFail)fail NS_SWIFT_NAME(join(callId:succ:fail:));

/**
 * 邀请用户加入此次群组通话。
 * 使用场景：一个群组通话中的用户主动邀请其他人时使用。
 *
 * @param userIdList 目标用户的 userId 列表
 * @param params     通话参数扩展字段，例如：离线推送自定义内容
 */
- (void)inviteUser:(NSArray<NSString *> *)userIdList params:(TUICallParams *)params succ:(void (^)(NSArray<NSString *> *userIdList))succ fail:(TUICallFail)fail NS_SWIFT_NAME(inviteUser(userIdList:params:succ:fail:));

/**
 * 切换通话媒体类型，比如视频通话切音频通话
 *
 * @param callMediaType 通话的媒体类型，例如：视频通话、语音通话
 */
- (void)switchCallMediaType:(TUICallMediaType)callMediaType NS_SWIFT_NAME(switchCallMediaType(_:));

/**
 * 开始订阅远端用户视频流
 *
 * @param userId    目标用户的 userId
 * @param videoView 待渲染的视图
 */
- (void)startRemoteView:(NSString *)userId
              videoView:(TUIVideoView *)videoView
              onPlaying:(void (^)(NSString *userId))onPlaying
              onLoading:(void (^)(NSString *userId))onLoading
                onError:(void (^)(NSString *userId, int code, NSString *errMsg))onError NS_SWIFT_NAME(startRemoteView(userId:videoView:onPlaying:onLoading:onError:));

/**
 * 停止订阅远端用户视频流
 *
 * @param userId 目标用户的 userId
 */
- (void)stopRemoteView:(NSString *)userId NS_SWIFT_NAME(stopRemoteView(userId:));

/**
 * 开启摄像头
 *
 * @param camera    前置/后置 摄像头
 * @param videoView 待渲染的视图
 */
- (void)openCamera:(TUICamera)camera videoView:(TUIVideoView *)videoView succ:(TUICallSucc)succ fail:(TUICallFail)fail NS_SWIFT_NAME(openCamera(_:videoView:succ:fail:));

/**
 * 关闭摄像头
 */
- (void)closeCamera NS_SWIFT_NAME(closeCamera());

/**
 * 切换前后摄像头
 *
 * @param camera 前置/后置 摄像头
 */
- (void)switchCamera:(TUICamera)camera NS_SWIFT_NAME(switchCamera(_:));

/**
 * 打开麦克风
 */
- (void)openMicrophone:(TUICallSucc)succ fail:(TUICallFail)fail NS_SWIFT_NAME(openMicrophone(succ:fail:));

/**
 * 关闭麦克风
 */
- (void)closeMicrophone NS_SWIFT_NAME(closeMicrophone());

/**
 * 选择音频播放设备（听筒/扬声器）
 *
 * @param device 听筒/扬声器
 */
- (void)selectAudioPlaybackDevice:(TUIAudioPlaybackDevice)device NS_SWIFT_NAME(selectAudioPlaybackDevice(_:));

/**
 * 设置用户的昵称、头像
 *
 * @param nickname 用户昵称
 * @param avatar   用户头像（格式为 URL）
 */
- (void)setSelfInfo:(NSString *_Nullable)nickname avatar:(NSString *_Nullable)avatar succ:(TUICallSucc)succ fail:(TUICallFail)fail NS_SWIFT_NAME(setSelfInfo(nickname:avatar:succ:fail:));

/**
 * 开启/关闭 TUICallEngine 的多设备登录模式 （尊享版套餐支持）
 *
 * @param enable   开启:true; 关闭:false
 */
- (void)enableMultiDeviceAbility:(BOOL)enable succ:(TUICallSucc)succ fail:(TUICallFail)fail NS_SWIFT_NAME(enableMultiDeviceAbility(enable:succ:fail:));

/**
 * 设置用户画面的渲染模式
 *
 * @param userId   指定用户的 ID
 * @param params   画面渲染参数：画面的旋转角度、填充模式，详见 {@link TUICommonDefine.VideoRenderParams}.
 */
- (void)setVideoRenderParams:(NSString *)userId params:(TUIVideoRenderParams *)params succ:(TUICallSucc)succ fail:(TUICallFail)fail NS_SWIFT_NAME(setVideoRenderParams(userId:params:succ:fail:));

/**
 * 设置视频编码器的编码参数
 * 该设置能够决定远端用户看到的画面质量，同时也能决定云端录制出的视频文件的画面质量。
 *
 * @param params   编码参数：画面的分辨率、视频宽高比模式，详见 {@link TUICommonDefine.VideoEncoderParams}.
 */
- (void)setVideoEncoderParams:(TUIVideoEncoderParams *)params succ:(TUICallSucc)succ fail:(TUICallFail)fail NS_SWIFT_NAME(setVideoEncoderParams(_:succ:fail:));

/**
 * 设置美颜
 */
- (void)setBeautyLevel:(CGFloat)level succ:(TUICallSucc)succ fail:(TUICallFail)fail NS_SWIFT_NAME(setBeautyLevel(_:succ:fail:));

/**
 * 高级接口，获得当前通话业务中的 TRTCCloud 实例
 *
 * @return TRTCCloud 实例
 */
- (TRTCCloud *)getTRTCCloudInstance NS_SWIFT_NAME(getTRTCCloudInstance());

/**
 * 调用实验性接口
 *
 * @param jsonObject json 数据
 */
- (void)callExperimentalAPI:(NSString *)jsonObject NS_SWIFT_NAME(callExperimentalAPI(jsonObject:));

/**
 * 查询通话记录
 *
 * @param filter   查询过滤条件
 */
- (void)queryRecentCalls:(TUICallRecentCallsFilter *)filter succ:(void (^)(NSArray<TUICallRecords *> *callRecords))succ fail:(void (^)(void))fail NS_SWIFT_NAME(queryRecentCalls(filter:succ:fail:));

/**
 * 删除通话记录
 *
 * @param callIdList 待删除记录的callId列表
 */
- (void)deleteRecordCalls:(NSArray<NSString *> *)callIdList succ:(void (^)(NSArray<NSString *> *succList))succ fail:(void (^)(void))fail NS_SWIFT_NAME(deleteRecordCalls(_:succ:fail:));

/**
 * 设置视频通话虚化效果
 *
 * @param level    虚化等级: 0-关闭虚化效果; 1-low; 2-middle; 3-high
 */
- (void)setBlurBackground:(NSInteger)level fail:(TUICallFail)fail NS_SWIFT_NAME(setBlurBackground(_:fail:));

/**
 * 设置视频通话图片背景
 *
 * @param imagePath 图片本地路径,为空则关闭背景图片效果; 不为空则开启图片背景效果
 */
- (void)setVirtualBackground:(NSString *)imagePath fail:(TUICallFail)fail NS_SWIFT_NAME(setVirtualBackground(_:fail:));

/**
 * 语义化的 JSON API.
 */
- (void)call:(NSString *)api param:(NSString *)jsonParam callback:(TUIJsonAPIResponseBlock)callback NS_SWIFT_NAME(call(api:param:callback:));
- (NSString *)query:(NSString *)api param:(NSString *)jsonParam NS_SWIFT_NAME(query(api:param:));

/**
 * 此接口已于2023年9月废弃。若您刚刚开始接入TUICallEngine，请优先使用calls，其功能更强大，稳定性更佳。
 */
- (void)call:(TUIRoomId *)roomId
           userId:(NSString *)userId
    callMediaType:(TUICallMediaType)callMediaType
           params:(TUICallParams *)params
             succ:(TUICallSucc)succ
             fail:(TUICallFail)fail NS_SWIFT_NAME(call(roomId:userId:callMediaType:params:succ:fail:)) __attribute__((deprecated));

/**
 * 此接口已于2025年1月废弃。若您刚刚开始接入TUICallEngine，请优先使用calls，其功能更强大，稳定性更佳。
 */
- (void)call:(NSString *)userId callMediaType:(TUICallMediaType)callMediaType params:(TUICallParams *)params succ:(TUICallSucc)succ fail:(TUICallFail)fail NS_SWIFT_NAME(call(userId:callMediaType:params:succ:fail:)) __attribute__((deprecated));

/**
 * 此接口已于2023年9月废弃。若您刚刚开始接入TUICallEngine，请优先使用calls，其功能更强大，稳定性更佳。
 */
- (void)groupCall:(TUIRoomId *)roomId
          groupId:(NSString *)groupId
       userIdList:(NSArray<NSString *> *)userIdList
    callMediaType:(TUICallMediaType)callMediaType
           params:(TUICallParams *)params
             succ:(TUICallSucc)succ
             fail:(TUICallFail)fail NS_SWIFT_NAME(groupCall(roomId:groupId:userIdList:callMediaType:params:succ:fail:)) __attribute__((deprecated));

/**
 * 此接口已于2025年1月废弃。若您刚刚开始接入TUICallEngine，请优先使用calls，其功能更强大，稳定性更佳。
 */
- (void)groupCall:(NSString *)groupId
       userIdList:(NSArray<NSString *> *)userIdList
    callMediaType:(TUICallMediaType)callMediaType
           params:(TUICallParams *)params
             succ:(TUICallSucc)succ
             fail:(TUICallFail)fail NS_SWIFT_NAME(groupCall(groupId:userIdList:callMediaType:params:succ:fail:)) __attribute__((deprecated));

/**
 * 此接口已于2015年1月废弃。若您刚刚开始接入TUICallEngine，请优先使用join。
 */
- (void)joinInGroupCall:(TUIRoomId *)roomId
                groupId:(NSString *)groupId
          callMediaType:(TUICallMediaType)callMediaType
                   succ:(TUICallSucc)succ
                   fail:(TUICallFail)fail NS_SWIFT_NAME(joinInGroupCall(roomId:groupId:callMediaType:succ:fail:)) __attribute__((deprecated));

@end

NS_ASSUME_NONNULL_END
