/**
 * Copyright (c) 2024 Tencent. All rights reserved.
 * Module:   TUIConferenceInvitationManager @ TUIKitEngine
 * Function: 会中邀请相关接口，此页面中的函数仅支持会议房间类型({@link TUIRoomTypeConference})。
 */

#import <Foundation/Foundation.h>
#import "TUICommonDefine.h"
#import "TUIRoomDefine.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * 邀请状态
 */
typedef NS_ENUM(NSUInteger, TUIInvitationStatus) {

    /// 未知状态。
    TUIInvitationStatusNone = 0,

    /// 待处理状态。
    TUIInvitationStatusPending = 1,

    /// 超时状态。
    TUIInvitationStatusTimeout = 2,

    /// 已接受状态。
    TUIInvitationStatusAccepted = 3,

    /// 被拒绝状态。
    TUIInvitationStatusRejected = 4,

};

/**
 * 邀请错误码枚举
 */
typedef NS_ENUM(NSInteger, TUIInvitationCode) {

    /// 邀请成功。
    TUIInvitationCodeSuccess = 0,

    /// 当前用户已在邀请列表。
    TUIInvitationCodeAlreadyInInvitationList = 1,

    /// 当前用户已在房间内。
    TUIInvitationCodeAlreadyInConference = 2,

};

/**
 * 邀请拒绝原因枚举
 */
typedef NS_ENUM(NSInteger, TUIInvitationRejectedReason) {

    /// 拒绝进入。
    TUIInvitationRejectedReasonRejectToEnter = 0,

    /// 在其他会议中。
    TUIInvitationRejectedReasonInOtherConference = 1,

};

/**
 * 邀请信息结构体
 */
TUIENGINE_EXPORT @interface TUIInvitation : NSObject

/// 邀请状态。
@property(nonatomic, assign, readonly) TUIInvitationStatus status;

/// 被邀请者信息。
@property(nonatomic, strong, readwrite) TUIUserInfo *invitee;

/// 邀请者信息。
@property(nonatomic, strong, readwrite) TUIUserInfo *inviter;

@end

typedef void (^TUIInvitationListResponseBlock)(NSArray<TUIInvitation *> *_Nonnull list, NSString *cursor);

typedef void (^TUIInviteUsersResponseBlock)(NSDictionary<NSString *, NSNumber *> *resultMap);

@protocol TUIConferenceInvitationObserver <NSObject>
@optional

/**
 * 收到邀请回调
 *
 * @param roomInfo 房间信息。
 * @param invitation 邀请信息。
 * @param extensionInfo 扩展信息。
 */
- (void)onReceiveInvitation:(TUIRoomInfo *)roomInfo invitation:(TUIInvitation *)invitation extensionInfo:(NSString *)extensionInfo NS_SWIFT_NAME(onReceiveInvitation(roomInfo:invitation:extensionInfo:));

/**
 * 邀请已在其他设备被处理回调
 *
 * @param roomInfo 房间信息。
 * @param accepted 邀请是否被接受。
 */
- (void)onInvitationHandledByOtherDevice:(TUIRoomInfo *)roomInfo accepted:(BOOL)accepted NS_SWIFT_NAME(onInvitationHandledByOtherDevice(roomInfo:accepted:));

/**
 * 邀请被取消回调
 *
 * @param roomInfo 房间信息。
 * @param invitation 邀请信息。
 */
- (void)onInvitationCancelled:(TUIRoomInfo *)roomInfo invitation:(TUIInvitation *)invitation NS_SWIFT_NAME(onInvitationCancelled(roomInfo:invitation:));

/**
 * 邀请被接受回调
 *
 * @param roomInfo 房间信息。
 * @param invitation 邀请信息。
 */
- (void)onInvitationAccepted:(TUIRoomInfo *)roomInfo invitation:(TUIInvitation *)invitation NS_SWIFT_NAME(onInvitationAccepted(roomInfo:invitation:));

/**
 * 邀请被拒绝回调
 *
 * @param roomInfo 房间信息。
 * @param invitation 邀请信息。
 * @param reason 拒绝原因。
 */
- (void)onInvitationRejected:(TUIRoomInfo *)roomInfo invitation:(TUIInvitation *)invitation reason:(TUIInvitationRejectedReason)reason NS_SWIFT_NAME(onInvitationRejected(roomInfo:invitation:reason:));

/**
 * 邀请超时回调
 *
 * @param roomInfo 房间信息。
 * @param invitation 邀请信息。
 */
- (void)onInvitationTimeout:(TUIRoomInfo *)roomInfo invitation:(TUIInvitation *)invitation NS_SWIFT_NAME(onInvitationTimeout(roomInfo:invitation:));

/**
 * 邀请被管理员/房主撤销回调
 *
 * @param roomInfo 房间信息。
 * @param invitation 邀请信息。
 * @param admin 管理员/房主信息。
 */
- (void)onInvitationRevokedByAdmin:(TUIRoomInfo *)roomInfo invitation:(TUIInvitation *)invitation admin:(TUIUserInfo *)admin NS_SWIFT_NAME(onInvitationRevokedByAdmin(roomInfo:invitation:admin:));

/**
 * 新增邀请回调
 *
 * @param roomId 房间Id。
 * @param invitation 邀请信息。
 */
- (void)onInvitationAdded:(NSString *)roomId invitation:(TUIInvitation *)invitation NS_SWIFT_NAME(onInvitationAdded(roomId:invitation:));

/**
 * 邀请被移除回调
 *
 * @param roomId 房间Id。
 * @param invitation 邀请信息。
 */
- (void)onInvitationRemoved:(NSString *)roomId invitation:(TUIInvitation *)invitation NS_SWIFT_NAME(onInvitationRemoved(roomId:invitation:));

/**
 * 邀请状态变更回调
 *
 * @param roomId 房间Id。
 * @param invitation 邀请信息。
 */
- (void)onInvitationStatusChanged:(NSString *)roomId invitation:(TUIInvitation *)invitation NS_SWIFT_NAME(onInvitationStatusChanged(roomId:invitation:));

@end

TUIENGINE_EXPORT @interface TUIConferenceInvitationManager : NSObject

/**
 * 添加事件回调
 *
 * @param observer 监听的实例。
 */
- (void)addObserver:(id<TUIConferenceInvitationObserver>)observer NS_SWIFT_NAME(addObserver(_:));

/**
 * 移除事件回调
 *
 * @param observer 监听的实例。
 */
- (void)removeObserver:(id<TUIConferenceInvitationObserver>)observer NS_SWIFT_NAME(removeObserver(_:));

/**
 * 邀请成员
 *
 * @param roomId 房间Id。
 * @param userIdList 成员userId列表。
 * @param timeout 超时时间。
 * @param extensionInfo 扩展信息。
 */
- (void)inviteUsers:(NSString *)roomId
         userIdList:(NSArray<NSString *> *)userIdList
            timeout:(NSTimeInterval)timeout
      extensionInfo:(NSString *)extensionInfo
          onSuccess:(TUIInviteUsersResponseBlock)onSuccess
            onError:(TUIErrorBlock)onError NS_SWIFT_NAME(inviteUsers(_:userIdList:timeout:extensionInfo:onSuccess:onError:));

/**
 * 取消邀请
 *
 * @param roomId 房间Id。
 * @param userIdList 成员userId列表。
 */
- (void)cancelInvitation:(NSString *)roomId userIdList:(NSArray<NSString *> *)userIdList onSuccess:(TUISuccessBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(cancelInvitation(_:userIdList:onSuccess:onError:));

/**
 * 接受邀请
 *
 * @param roomId 房间Id。
 */
- (void)accept:(NSString *)roomId onSuccess:(TUISuccessBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(accept(_:onSuccess:onError:));

/**
 * 拒绝邀请
 *
 * @param roomId 房间Id。
 * @param reason 拒绝原因。
 */
- (void)reject:(NSString *)roomId reason:(TUIInvitationRejectedReason)reason onSuccess:(TUISuccessBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(reject(_:reason:onSuccess:onError:));

/**
 * 拉取邀请列表
 *
 * @param roomId 房间Id。
 * @param cursor 分页获取索引，第一次拉取填 ""，回调成功 如果callback返回的数据中 cursor 不为""，表示需要分页，请以返回的cursor作为参数再次调用接口拉取，直至返回的cursor为""，表示数据已经全部拉取。
 * @param count 本次拉取数量。
 */
- (void)getInvitationList:(NSString *)roomId cursor:(NSString *)cursor count:(NSInteger)count onSuccess:(TUIInvitationListResponseBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(getInvitationList(_:cursor:count:onSuccess:onError:));

@end
NS_ASSUME_NONNULL_END
