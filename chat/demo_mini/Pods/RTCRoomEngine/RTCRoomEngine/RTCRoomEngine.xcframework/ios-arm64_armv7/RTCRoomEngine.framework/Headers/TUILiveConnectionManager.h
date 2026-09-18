/**
 * Copyright (c) 2024 Tencent. All rights reserved.
 * Module:   TUILiveConnectionManager @ TUIKitEngine
 * Function: 直播连线相关接口，此页面中的函数仅支持直播房间类型({@link TUIRoomTypeLive})。
 */

#import <Foundation/Foundation.h>
#import "TUICommonDefine.h"
#import "TUIRoomDefine.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * 连线用户信息
 */
TUIENGINE_EXPORT @interface TUIConnectionUser : NSObject

/// 连线的房间id。
@property(nonatomic, copy, nonnull) NSString *roomId;

/// 连线的用户id。
@property(nonatomic, copy, nonnull) NSString *userId;

/// 连线的用户昵称。
@property(nonatomic, copy, nonnull) NSString *userName;

/// 连线的用户头像地址。
@property(nonatomic, copy, nonnull) NSString *avatarUrl;

/// 连线开始标记时间戳。
@property(nonatomic, assign) NSUInteger joinConnectionTime;

@end

/**
 * 连线邀请状态
 */
typedef NS_ENUM(NSInteger, TUIConnectionCode) {

    /// 默认状态。
    TUIConnectionCodeUnknown = -1,

    /// 连线请求发送成功。
    TUIConnectionCodeSuccess = 0,

    /// 邀请连线的房间不存在。
    TUIConnectionCodeRoomNotExist = 1,

    /// 被邀请连线的房间已在邀请列表或者已连线。
    TUIConnectionCodeConnecting = 2,

    /// 被邀请连线的房间与其他房间连线中。
    TUIConnectionCodeConnectingOtherRoom = 3,

    /// 当前连线人数已达最大限制。
    TUIConnectionCodeFull = 4,

    /// 内部错误，推荐重试一次。
    TUIConnectionCodeRetry = 5,

    /// 房间类型不匹配，连线的房间必须类型相同。
    TUIConnectionCodeRoomMismatch = 6,

};

typedef void (^TUIConnectionRequestBlock)(NSDictionary<NSString *, NSNumber *> *resultMap);

@protocol TUILiveConnectionObserver <NSObject>
@optional

/**
 * 收到连线用户列表发生变化
 *
 * @param connectedList 已连线的用户列表。
 * @param joinedList 新加入连线的用户列表。
 * @param leavedList 退出连线的用户列表。
 */
- (void)onConnectionUserListChanged:(NSArray<TUIConnectionUser *> *)connectedList
                         joinedList:(NSArray<TUIConnectionUser *> *)joinedList
                         leavedList:(NSArray<TUIConnectionUser *> *)leavedList NS_SWIFT_NAME(onConnectionUserListChanged(connectedList:joinedList:leavedList:));

/**
 * 接收端收到连线邀请的回调
 *
 * @param inviter 邀请者信息。
 * @param inviteeList 被邀请连线的用户列表。
 * @param extensionInfo 透传信息。
 */
- (void)onConnectionRequestReceived:(TUIConnectionUser *)inviter inviteeList:(NSArray<TUIConnectionUser *> *)inviteeList extensionInfo:(NSString *)extensionInfo NS_SWIFT_NAME(onConnectionRequestReceived(inviter:inviteeList:extensionInfo:));

/**
 * 邀请取消回调
 *
 * @param inviter 邀请者信息。
 */
- (void)onConnectionRequestCancelled:(TUIConnectionUser *)inviter NS_SWIFT_NAME(onConnectionRequestCancelled(inviter:));

/**
 * 邀请被接受回调
 *
 * @param invitee 被邀请者的用户信息。
 */
- (void)onConnectionRequestAccept:(TUIConnectionUser *)invitee NS_SWIFT_NAME(onConnectionRequestAccept(invitee:));

/**
 * 邀请被拒绝回调
 *
 * @param invitee 被邀请者的用户信息。
 */
- (void)onConnectionRequestReject:(TUIConnectionUser *)invitee NS_SWIFT_NAME(onConnectionRequestReject(invitee:));

/**
 * 邀请超时回调
 *
 * @param inviter 邀请者信息。
 * @param invitee 被邀请者的用户信息。
 */
- (void)onConnectionRequestTimeout:(TUIConnectionUser *)inviter invitee:(TUIConnectionUser *)invitee NS_SWIFT_NAME(onConnectionRequestTimeout(inviter:invitee:));

@end

TUIENGINE_EXPORT @interface TUILiveConnectionManager : NSObject

/**
 * 添加事件回调
 *
 * @param observer 监听的实例。
 */
- (void)addObserver:(id<TUILiveConnectionObserver>)observer NS_SWIFT_NAME(addObserver(_:));

/**
 * 移除事件回调
 *
 * @param observer 监听的实例。
 */
- (void)removeObserver:(id<TUILiveConnectionObserver>)observer NS_SWIFT_NAME(removeObserver(_:));

/**
 * 发起连线请求
 *
 * @param roomIdList 待邀请的连线房间ID列表。
 * @param timeout 超时时间。
 * @param extensionInfo 扩展信息。
 */
- (void)requestConnection:(NSArray<NSString *> *)roomIdList
                  timeout:(NSTimeInterval)timeout
            extensionInfo:(NSString *)extensionInfo
                onSuccess:(TUIConnectionRequestBlock)onSuccess
                  onError:(TUIErrorBlock)onError NS_SWIFT_NAME(requestConnection(roomIdList:timeout:extensionInfo:onSuccess:onError:));

/**
 * 取消连线请求
 *
 * @param roomIdList 被取消连线请求的房间Id列表。
 */
- (void)cancelConnectionRequest:(NSArray<NSString *> *)roomIdList onSuccess:(TUISuccessBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(cancelConnectionRequest(roomIdList:onSuccess:onError:));

/**
 * 接受连线邀请
 *
 * @param roomId 房间Id。
 */
- (void)acceptConnection:(NSString *)roomId onSuccess:(TUISuccessBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(acceptConnection(_:onSuccess:onError:));

/**
 * 拒绝连线邀请
 *
 * @param roomId 房间Id。
 */
- (void)rejectConnection:(NSString *)roomId onSuccess:(TUISuccessBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(rejectConnection(_:onSuccess:onError:));

/**
 * 退出房间连线
 *
 * 调用该接口会退出房间连线状态，仅限已连线的状态下调用。
 */
- (void)disconnect:(TUISuccessBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(disconnect(_onSuccess:onError:));

/**
 * 禁音/取消禁音连线房间的音频
 *
 * @note 仅在跨房连线状态下可用，需要房主或管理员权限。
 * @param roomId 连线房间ID。
 * @param isMute YES表示禁音，NO表示取消禁音。
 */
- (void)muteConnection:(NSString *)roomId isMute:(BOOL)isMute onSuccess:(TUISuccessBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(muteConnection(roomId:isMute:onSuccess:onError:));

@end
NS_ASSUME_NONNULL_END
