/**
 * Copyright (c) 2024 Tencent. All rights reserved.
 * Module:   TUILiveBattleManager @ TUIKitEngine
 * Function: 直播 Battle 相关接口
 */

#import <Foundation/Foundation.h>
#import "TUICommonDefine.h"
#import "TUIRoomDefine.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Battle 用户信息
 */
TUIENGINE_EXPORT @interface TUIBattleUser : NSObject

/// Battle 房间 id。
@property(nonatomic, copy, nonnull) NSString *roomId;

/// Battle 用户id。
@property(nonatomic, copy, nonnull) NSString *userId;

/// Battle 用户昵称。
@property(nonatomic, copy, nonnull) NSString *userName;

/// Battle 用户头像地址。
@property(nonatomic, copy, nonnull) NSString *avatarUrl;

/// Battle 分数。
@property(nonatomic, assign) NSUInteger score;

@end

/**
 * Battle 配置
 */
TUIENGINE_EXPORT @interface TUIBattleConfig : NSObject

/// Battle 最大时长（单位：秒）。
@property(nonatomic, assign) NSTimeInterval duration;

/// 被邀请用户是否需要回复同意/拒绝。
@property(nonatomic, assign) BOOL needResponse;

/// Battle 扩展信息。
@property(nonatomic, copy, nonnull) NSString *extensionInfo;

@end

/**
 * Battle 信息
 */
TUIENGINE_EXPORT @interface TUIBattleInfo : NSObject

/// Battle ID。
@property(nonatomic, copy, readonly, nonnull) NSString *battleId;

/// Battle 配置。
@property(nonatomic, strong, readonly, nonnull) TUIBattleConfig *config;

/// Battle 发起人。
@property(nonatomic, strong, readonly, nonnull) TUIBattleUser *inviter;

/// Battle 邀请成员。
@property(nonatomic, strong, readonly, nonnull) NSArray<TUIBattleUser *> *inviteeList;

/// Battle 开始标记时间戳（单位：秒）。
@property(nonatomic, assign, readonly) NSUInteger startTime;

/// Battle 结束标记时间戳（单位：秒）。
@property(nonatomic, assign, readonly) NSUInteger endTime;

@end

/**
 * Battle 邀请状态
 */
typedef NS_ENUM(NSInteger, TUIBattleCode) {

    /// 默认状态。
    TUIBattleCodeUnknown = -1,

    /// Battle 请求发送成功。
    TUIBattleCodeSuccess = 0,

    /// 被邀请的房间不存在。
    TUIBattleCodeRoomNotExist = 1,

    /// 被邀请的房间已在 Battle 中。
    TUIBattleCodeBattling = 2,

    /// 被邀请的房间已与其他房间 Battle 中。
    TUIBattleCodeBattlingOtherRoom = 3,

    /// 房间已退出。
    TUIBattleCodeRoomExit = 4,

    /// 内部错误，推荐重试一次。
    TUIBattleCodeRetry = 5,

};

/**
 * Battle 结束的原因
 */
typedef NS_ENUM(NSInteger, TUIBattleStoppedReason) {

    /// Battle 到达最大时长而超时结束
    TUIBattleStoppedReasonTimeOver = 0,

    /// Battle 其余人员都已退出
    TUIBattleStoppedReasonOtherExit = 1,

};

typedef void (^TUIBattleRequestBlock)(TUIBattleInfo *battleInfo, NSDictionary<NSString *, NSNumber *> *resultMap);

@protocol TUILiveBattleObserver <NSObject>
@optional

/**
 * 收到 Battle 开始的通知
 *
 * @param battleInfo Battle 信息。
 */
- (void)onBattleStarted:(TUIBattleInfo *)battleInfo NS_SWIFT_NAME(onBattleStarted(battleInfo:));

/**
 * 收到 Battle 结束的通知
 *
 * @param battleInfo Battle 信息。
 * @param reason Battle 结束的原因。
 */
- (void)onBattleEnded:(TUIBattleInfo *)battleInfo reason:(TUIBattleStoppedReason)reason NS_SWIFT_NAME(onBattleEnded(battleInfo:reason:));

/**
 * 收到用户加入 Battle 的通知
 *
 * @param battleId Battle ID。
 * @param battleUser Battle 用户信息。
 */
- (void)onUserJoinBattle:(NSString *)battleId battleUser:(TUIBattleUser *)battleUser NS_SWIFT_NAME(onUserJoinBattle(battleId:battleUser:));

/**
 * 收到用户退出 Battle 的通知
 *
 * @param battleId Battle ID。
 * @param battleUser Battle 用户信息。
 */
- (void)onUserExitBattle:(NSString *)battleId battleUser:(TUIBattleUser *)battleUser NS_SWIFT_NAME(onUserExitBattle(battleId:battleUser:));

/**
 * 收到用户 Battle 分数更新的通知
 *
 * @param battleId Battle ID。
 * @param battleUserList Battle 所有用户信息。
 */
- (void)onBattleScoreChanged:(NSString *)battleId battleUserList:(NSArray<TUIBattleUser *> *)battleUserList NS_SWIFT_NAME(onBattleScoreChanged(battleId:battleUserList:));

/**
 * 被叫收到 Battle 邀请的通知
 *
 * @param battleInfo Battle 信息。
 * @param inviter 发起邀请的用户信息。
 * @param invitee 收到邀请的用户信息。
 */
- (void)onBattleRequestReceived:(TUIBattleInfo *)battleInfo inviter:(TUIBattleUser *)inviter invitee:(TUIBattleUser *)invitee NS_SWIFT_NAME(onBattleRequestReceived(battleInfo:inviter:invitee:));

/**
 * 被叫收到 Battle 取消的通知
 *
 * @param battleInfo Battle 信息。
 * @param inviter 发起邀请的用户信息。
 * @param invitee 收到邀请的用户信息。
 */
- (void)onBattleRequestCancelled:(TUIBattleInfo *)battleInfo inviter:(TUIBattleUser *)inviter invitee:(TUIBattleUser *)invitee NS_SWIFT_NAME(onBattleRequestCancelled(battleInfo:inviter:invitee:));

/**
 * 收到 Battle 处理超时的通知
 *
 * @param battleInfo Battle 信息。
 * @param inviter 发起邀请的用户信息。
 * @param invitee 收到邀请的用户信息。
 */
- (void)onBattleRequestTimeout:(TUIBattleInfo *)battleInfo inviter:(TUIBattleUser *)inviter invitee:(TUIBattleUser *)invitee NS_SWIFT_NAME(onBattleRequestTimeout(battleInfo:inviter:invitee:));

/**
 * 主叫收到被叫同意的通知
 *
 * @param battleInfo Battle 信息。
 * @param inviter 发起邀请的用户信息。
 * @param invitee 收到邀请的用户信息。
 */
- (void)onBattleRequestAccept:(TUIBattleInfo *)battleInfo inviter:(TUIBattleUser *)inviter invitee:(TUIBattleUser *)invitee NS_SWIFT_NAME(onBattleRequestAccept(battleInfo:inviter:invitee:));

/**
 * 主叫收到被叫拒绝的通知
 *
 * @param battleInfo Battle 信息。
 * @param inviter 发起邀请的用户信息。
 * @param invitee 收到邀请的用户信息。
 */
- (void)onBattleRequestReject:(TUIBattleInfo *)battleInfo inviter:(TUIBattleUser *)inviter invitee:(TUIBattleUser *)invitee NS_SWIFT_NAME(onBattleRequestReject(battleInfo:inviter:invitee:));

@end

TUIENGINE_EXPORT @interface TUILiveBattleManager : NSObject

/**
 * 添加事件回调
 *
 * @param observer 监听的实例。
 */
- (void)addObserver:(id<TUILiveBattleObserver>)observer NS_SWIFT_NAME(addObserver(_:));

/**
 * 移除事件回调
 *
 * @param observer 监听的实例。
 */
- (void)removeObserver:(id<TUILiveBattleObserver>)observer NS_SWIFT_NAME(removeObserver(_:));

/**
 * 发起 Battle 请求
 *
 * @param config Battle 配置信息。
 * @param userIdList 待邀请的用户ID列表。
 * @param timeout 超时时间。
 */
- (void)requestBattle:(TUIBattleConfig *)config
           userIdList:(NSArray<NSString *> *)userIdList
              timeout:(NSTimeInterval)timeout
            onSuccess:(TUIBattleRequestBlock)onSuccess
              onError:(TUIErrorBlock)onError NS_SWIFT_NAME(requestBattle(config:userIdList:timeout:onSuccess:onError:));

/**
 * 取消 Battle 请求
 *
 * @param battleId Battle ID。
 * @param userIdList 待取消的用户ID列表。
 */
- (void)cancelBattleRequest:(NSString *)battleId userIdList:(NSArray<NSString *> *)userIdList onSuccess:(TUISuccessBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(cancelBattleRequest(battleId:userIdList:onSuccess:onError:));

/**
 * 接受 Battle 请求
 *
 * @param battleId Battle ID。
 */
- (void)acceptBattle:(NSString *)battleId onSuccess:(TUISuccessBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(acceptBattle(battleId:onSuccess:onError:));

/**
 * 拒绝 Battle 请求
 *
 * @param battleId Battle ID。
 */
- (void)rejectBattle:(NSString *)battleId onSuccess:(TUISuccessBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(rejectBattle(battleId:onSuccess:onError:));

/**
 * 退出 Battle
 *
 * @param battleId Battle ID。
 */
- (void)exitBattle:(NSString *)battleId onSuccess:(TUISuccessBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(exitBattle(battleId:onSuccess:onError:));

@end
NS_ASSUME_NONNULL_END
