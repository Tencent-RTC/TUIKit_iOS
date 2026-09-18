/**
 * Copyright (c) 2024 Tencent. All rights reserved.
 * Module:   TUIConferenceListManager @ TUIKitEngine
 * Function: 会议列表相关接口，此页面中的函数仅支持会议房间类型({@link TUIRoomTypeConference})。
 */

#import <Foundation/Foundation.h>
#import "TUICommonDefine.h"
#import "TUIRoomDefine.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * 会议状态
 */
typedef NS_OPTIONS(NSUInteger, TUIConferenceStatus) {

    /// 未知状态
    TUIConferenceStatusNone = 0,

    /// 会议未开始
    TUIConferenceStatusNotStarted = 1,

    /// 会议进行中（当前时间 - 预约开始时间 < 1 分钟时，会议状态从未开始转到进行中）
    TUIConferenceStatusRunning = 2,

};

/**
 * 会议取消原因
 */
typedef NS_ENUM(NSUInteger, TUIConferenceCancelReason) {

    /// 房主取消
    TUIConferenceCancelReasonCancelledByAdmin = 0,

    /// 当前用户被移出参会人员列表
    TUIConferenceCancelReasonRemovedFromAttendees = 1,

};

/**
 * 预定会议信息修改标记位
 */
typedef NS_OPTIONS(NSUInteger, TUIConferenceModifyFlag) {

    /// 未定义
    TUIConferenceModifyFlagNone = 0x00,

    /// 会议名称
    TUIConferenceModifyFlagRoomName = 0x01 << 0,

    /// 是否禁止全员发送消息
    TUIConferenceModifyFlagDisableMessage = 0x1 << 1,

    /// 是否禁止全员打开摄像头
    TUIConferenceModifyFlagDisableCamera = 0x1 << 2,

    /// 是否禁止全员打开麦克风
    TUIConferenceModifyFlagDisableMicrophone = 0x1 << 3,

    /// 是否禁止全员屏幕分享
    TUIConferenceModifyFlagDisableScreenSharing = 0x1 << 4,

    /// 房间密码
    TUIConferenceModifyFlagPassword = 0x1 << 5,

    /// 会议开始前提醒时间
    TUIConferenceModifyFlagReminderSecondsBeforeStart = 0x1 << 6,

    /// 预定开始时间，不填写则默认为当前时间
    TUIConferenceModifyFlagScheduleStartTime = 0x01 << 16,

    /// 预定结束时间，不填写，则默认为预定开始时间后 1 小时（即默认的会议时长为 1 小时），会议最小持续时间不能小于 5 分钟，最长时间不能超过 24 小时
    TUIConferenceModifyFlagScheduleEndTime = 0x01 << 17,

};

/**
 * 会议信息
 */
TUIENGINE_EXPORT @interface TUIConferenceInfo : NSObject

/// 预定会议开始时间（时间戳，秒）
@property(nonatomic, assign) NSUInteger scheduleStartTime;

/// 预定会议结束时间（时间戳，秒）
@property(nonatomic, assign) NSUInteger scheduleEndTime;

/// 邀请参会成员列表，可在预定会议时设置，拉取成员请使用 {@link fetchAttendeeList} 接口
@property(nonatomic, strong, readwrite) NSArray<NSString *> *scheduleAttendees;

/// 会议开始前提醒时间（时间间隔，秒）
@property(nonatomic, assign) NSInteger reminderSecondsBeforeStart;

/// 房间状态（只读）
@property(nonatomic, assign, readonly) TUIConferenceStatus status;

/// 会议基础信息
@property(nonatomic, strong, readwrite) TUIRoomInfo *basicRoomInfo;

@end

typedef void (^TUIConferenceInfoBlock)(TUIConferenceInfo *_Nonnull conference);
typedef void (^TUIScheduledAttendeesResponseBlock)(NSArray<TUIUserInfo *> *_Nonnull list, NSString *cursor, NSUInteger totalAttendeeCount);
typedef void (^TUIScheduledConferenceListResponseBlock)(NSArray<TUIConferenceInfo *> *_Nonnull list, NSString *cursor);

@protocol TUIConferenceListManagerObserver <NSObject>

@optional

/**
 * 会议预定回调
 *
 * @param conferenceInfo 会议信息
 */
- (void)onConferenceScheduled:(TUIConferenceInfo *)conferenceInfo NS_SWIFT_NAME(onConferenceScheduled(conferenceInfo:));

/**
 * 会议即将开始回调
 *
 * @param conferenceInfo 会议信息。
 */
- (void)onConferenceWillStart:(TUIConferenceInfo *)conferenceInfo NS_SWIFT_NAME(onConferenceWillStart(conferenceInfo:));

/**
 * 会议取消回调
 *
 * @param conferenceInfo 会议信息。
 * @param reason 会议取消原因。
 * @param operateUser 取消会议操作者信息。
 */
- (void)onConferenceDidCancelled:(TUIConferenceInfo *)conferenceInfo reason:(TUIConferenceCancelReason)reason operateUser:(TUIUserInfo *)operateUser NS_SWIFT_NAME(onConferenceDidCancelled(conferenceInfo:reason:operateUser:));

/**
 * 会议信息变更回调
 *
 * @param conferenceInfo 会议信息。
 * @param modifyFlag 会议信息变更标志位。
 */
- (void)onConferenceInfoChanged:(TUIConferenceInfo *)conferenceInfo modifyFlag:(TUIConferenceModifyFlag)modifyFlag NS_SWIFT_NAME(onConferenceInfoChanged(conferenceInfo:modifyFlag:));

/**
 * 参会人员变更回调
 *
 * @param conferenceInfo 会议信息。
 * @param leftUsers 离开成员列表。
 * @param joinedUsers 新加入成员列表。
 */
- (void)onScheduleAttendeesUpdated:(TUIConferenceInfo *)conferenceInfo leftUsers:(NSArray<TUIUserInfo *> *)leftUsers joinedUsers:(NSArray<TUIUserInfo *> *)joinedUsers NS_SWIFT_NAME(onScheduleAttendeesUpdated(conferenceInfo:leftUsers:joinedUsers:));

/**
 * 会议状态变更回调
 *
 * @param conferenceInfo 会议信息。
 * @param status 会议状态枚举，详情参见：{@link TUIConferenceStatus}。
 */
- (void)onConferenceStatusUpdated:(TUIConferenceInfo *)conferenceInfo status:(TUIConferenceStatus)status NS_SWIFT_NAME(onConferenceStatusUpdated(conferenceInfo:status:));

/**
 * 会议房主变更回调
 *
 * @param conferenceInfo 会议信息。
 * @param newOwner 新房主信息。
 * @param oldOwner 原房主信息。
 */
- (void)onConferenceOwnerChanged:(TUIConferenceInfo *)conferenceInfo newOwner:(TUIUserInfo *)newOwner oldOwner:(TUIUserInfo *)oldOwner NS_SWIFT_NAME(onConferenceOwnerChanged(conferenceInfo:newOwner:oldOwner:));

/**
 * 会议取消回调 (从 3.6 版本开始废弃，请使用 onConferenceDidCancelled)
 *
 * @param roomId 会议Id，即房间roomId。
 * @param reason 会议取消原因。
 * @param operateUser 取消会议操作者信息。
 */
- (void)onConferenceCancelled:(NSString *)roomId
                       reason:(TUIConferenceCancelReason)reason
                  operateUser:(TUIUserInfo *)operateUser NS_SWIFT_NAME(onConferenceCancelled(roomId:reason:operateUser:)) __attribute__((deprecated("use onConferenceDidCancelled instead")));

/**
 * 参会人员变更回调 (从 3.6 版本开始废弃，请使用 onScheduleAttendeesUpdated)
 *
 * @param roomId 会议Id，即房间roomId。
 * @param leftUsers 离开成员列表。
 * @param joinedUsers 新加入成员列表。
 */
- (void)onScheduleAttendeesChanged:(NSString *)roomId
                         leftUsers:(NSArray<TUIUserInfo *> *)leftUsers
                       joinedUsers:(NSArray<TUIUserInfo *> *)joinedUsers NS_SWIFT_NAME(onScheduleAttendeesChanged(roomId:leftUsers:joinedUsers:)) __attribute__((deprecated("use onScheduleAttendeesUpdated instead")));

/**
 * 会议状态变更回调 (从 3.6 版本开始废弃，请使用 onConferenceStatusUpdated)
 *
 * @param roomId 会议Id，即房间roomId。
 * @param status 会议状态枚举，详情参见：{@link TUIConferenceStatus}。
 */
- (void)onConferenceStatusChanged:(NSString *)roomId status:(TUIConferenceStatus)status NS_SWIFT_NAME(onConferenceStatusChanged(roomId:status:)) __attribute__((deprecated("use onConferenceStatusUpdated instead")));

@end

TUIENGINE_EXPORT @interface TUIConferenceListManager : NSObject

/**
 * 添加事件回调
 *
 * @param observer 监听的实例。
 */
- (void)addObserver:(id<TUIConferenceListManagerObserver>)observer NS_SWIFT_NAME(addObserver(_:));

/**
 * 移除事件回调
 *
 * @param observer 监听的实例。
 */
- (void)removeObserver:(id<TUIConferenceListManagerObserver>)observer NS_SWIFT_NAME(removeObserver(_:));

/**
 * 预定会议
 *
 * @param conferenceInfo 预定会议信息。
 */
- (void)scheduleConference:(TUIConferenceInfo *)conferenceInfo onSuccess:(TUISuccessBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(scheduleConference(_:onSuccess:onError:));

/**
 * 取消预定会议
 *
 * @param roomId 要取消会议的会议Id，即房间roomId。
 */
- (void)cancelConference:(NSString *)roomId onSuccess:(TUISuccessBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(cancelConference(_:onSuccess:onError:));

/**
 * 查询会议房间详细信息
 *
 * @param roomId 会议房间 ID
 */
- (void)fetchConferenceInfo:(NSString *)roomId onSuccess:(TUIConferenceInfoBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(fetchConferenceInfo(roomId:onSuccess:onError:));

/**
 * 更新预定会议信息
 *
 * @param conferenceInfo 预定会议信息。
 * @param modifyFlag 更新会议信息标记位。
 */
- (void)updateConferenceInfo:(TUIConferenceInfo *)conferenceInfo
                  modifyFlag:(TUIConferenceModifyFlag)modifyFlag
                   onSuccess:(TUISuccessBlock)onSuccess
                     onError:(TUIErrorBlock)onError NS_SWIFT_NAME(updateConferenceInfo(conferenceInfo:modifyFlag:onSuccess:onError:));

/**
 * 获取预定会议列表
 *
 * @param status 会议状态。
 * @param cursor 分页获取索引，第一次拉取填 ""，回调成功 如果callback返回的数据中 cursor 不为""，表示需要分页，请以返回的cursor作为参数再次调用接口拉取，直至返回的cursor为""，表示数据已经全部拉取。
 * @param count 本次拉取数量。
 */
- (void)fetchScheduledConferenceList:(TUIConferenceStatus)status
                              cursor:(NSString *)cursor
                               count:(NSInteger)count
                           onSuccess:(TUIScheduledConferenceListResponseBlock)onSuccess
                             onError:(TUIErrorBlock)onError NS_SWIFT_NAME(fetchScheduledConferenceList(status:cursor:count:onSuccess:onError:));

/**
 * 获取预定会议邀请成员列表
 *
 * @param roomId 预定会议会议Id，即房间roomId。
 * @param cursor 分页获取索引，第一次拉取填 ""，回调成功 如果callback返回的数据中 cursor 不为""，表示需要分页，请以返回的cursor作为参数再次调用接口拉取，直至返回的cursor为""，表示数据已经全部拉取。
 * @param count 本次拉取数量。
 */
- (void)fetchAttendeeList:(NSString *)roomId
                   cursor:(NSString *)cursor
                    count:(NSInteger)count
                onSuccess:(TUIScheduledAttendeesResponseBlock)onSuccess
                  onError:(TUIErrorBlock)onError NS_SWIFT_NAME(fetchAttendeeList(roomId:cursor:count:onSuccess:onError:));

/**
 * 添加成员至邀请列表
 *
 * @param roomId 预定会议Id，即房间roomId。
 * @param userIdList 成员userId列表。
 */
- (void)addAttendeesByAdmin:(NSString *)roomId userIdList:(NSArray<NSString *> *)userIdList onSuccess:(TUISuccessBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(addAttendeesByAdmin(roomId:userIdList:onSuccess:onError:));

/**
 * 从邀请列表移除成员
 *
 * @param roomId 预定会议Id，即房间roomId。
 * @param userIdList 成员userId列表。
 */
- (void)removeAttendeesByAdmin:(NSString *)roomId userIdList:(NSArray<NSString *> *)userIdList onSuccess:(TUISuccessBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(removeAttendeesByAdmin(roomId:userIdList:onSuccess:onError:));

/**
 * 转让会议房主
 *
 * @param roomId 会议 ID，即房间 roomId。
 * @param userId 新房主 userId。
 */
- (void)transferConferenceOwner:(NSString *)roomId toUser:(NSString *)userId onSuccess:(TUISuccessBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(transferConferenceOwner(roomId:toUser:onSuccess:onError:));

@end
NS_ASSUME_NONNULL_END
