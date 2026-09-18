/**
 * Copyright (c) 2024 Tencent. All rights reserved.
 * Module:   TUILiveListManager @ TUIKitEngine
 * Function: 直播房间列表相关接口，此页面中的函数仅支持直播房间类型({@link TUIRoomTypeLive})。
 */

#import <Foundation/Foundation.h>
#import "TUICommonDefine.h"
#import "TUIRoomDefine.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * 直播间修改标记位
 */
typedef NS_OPTIONS(NSUInteger, TUILiveModifyFlag) {

    TUILiveModifyFlagNone = 0,

    /// Name: 直播间名称
    TUILiveModifyFlagName = 1 << 0,

    /// Notice: 直播间公告
    TUILiveModifyFlagNotice = 1 << 1,

    /// DisableMessage: 房间内全员禁止消息
    TUILiveModifyFlagDisableMessage = 1 << 2,

    /// Publish: 直播间公开标记
    TUILiveModifyFlagPublish = 1 << 5,

    /// TakeSeatMode: 直播间内上麦模式
    TUILiveModifyFlagTakeSeatMode = 1 << 6,

    /// CoverUrl: 直播间封面
    TUILiveModifyFlagCoverUrl = 1 << 7,

    /// BackgroundUrl: 直播间背景.
    TUILiveModifyFlagBackgroundUrl = 1 << 8,

    /// Category: 直播间分类
    TUILiveModifyFlagCategory = 1 << 9,

    /// ActivityStatus: 直播间活跃状态，支持自定义设置
    TUILiveModifyFlagActivityStatus = 1 << 10,

    /// SeatLayoutTemplateId: 直播间麦位布局模板 ID
    TUILiveModifyFlagSeatLayoutTemplateId = 1 << 11,

};

/**
 * 直播统计数据修改标记位
 */
typedef NS_OPTIONS(NSUInteger, TUILiveStatisticsModifyFlag) {

    TUILiveStatisticsModifyFlagNone = 0,

    /// TotalViewers: 累计观看次数
    TUILiveStatisticsModifyFlagTotalViewers = 1 << 0,

    /// TotalGiftsSent: 送礼总个数
    TUILiveStatisticsModifyFlagTotalGiftsSent = 1 << 1,

    /// TotalGiftCoins: 送礼总金额
    TUILiveStatisticsModifyFlagTotalGiftCoins = 1 << 2,

    /// TotalUniqueGiftSenders: 送礼人数
    TUILiveStatisticsModifyFlagTotalUniqueGiftSenders = 1 << 3,

    /// TotalLikesReceived: 点赞总数
    TUILiveStatisticsModifyFlagTotalLikesReceived = 1 << 4,

    /// TotalMessageCount: 消息总数
    TUILiveStatisticsModifyFlagTotalMessageCount = 1 << 5,

};

/**
 * 直播信息
 */
TUIENGINE_EXPORT @interface TUILiveInfo : NSObject

/// 房间ID (创建房间必填参数，最大支持48个字节)。
@property(nonatomic, copy, nonnull) NSString* roomId;

/// 房间名称（创建房间可选参数，默认房间ID，最大支持100个字节）。
@property(nonatomic, copy, nonnull) NSString* name;

/// 房间公告（创建房间可选参数，最大支持100个字节）。
@property(nonatomic, copy, nonnull) NSString* notice;

/// 是否禁止发送消息（创建房间可选参数），默认值：{@link NO}。
@property(nonatomic, assign) BOOL isMessageDisableForAllUser;

/// 直播间是否公开
@property(nonatomic, assign) BOOL isPublicVisible;

/// 云端录制策略，默认跟随控制台配置
@property(nonatomic, assign) TUICloudRecordPolicy cloudRecordPolicy;

/// 是否开启麦位控制。
@property(nonatomic, assign) BOOL isSeatEnabled;

/// 房主开播后自动上麦
@property(nonatomic, assign) BOOL keepOwnerOnSeat;

/// 最大麦位数。
@property(nonatomic, assign) NSInteger maxSeatCount;

/// 上麦模式(只有开启麦位控制后生效)。
@property(nonatomic, assign) TUISeatMode seatMode;

/// 麦位布局模板 ID
/// 1.只有开启麦位控制后生效;
/// 2.seatLayoutTemplateId 和 maxSeatCount 同时设置时，优先以模板支持的麦位数为准。
@property(nonatomic, assign) NSUInteger seatLayoutTemplateId;

/// 直播间封面，最大支持 200 个字节
@property(nonatomic, copy, nonnull) NSString* coverUrl;

/// 直播间背景，最大支持 200 个字节
@property(nonatomic, copy, nonnull) NSString* backgroundUrl;

/// 直播间分类标签，单个房间最大支持3个标记
@property(nonatomic, copy, nonnull) NSArray<NSNumber*>* categoryList;

/// 直播间活跃状态: 用户自定义标记
@property(nonatomic, assign) NSInteger activityStatus;

/// 房主ID: 默认为房间创建者ID（只读）。
@property(nonatomic, readonly, nonnull) NSString* ownerId;

/// 房主昵称: 默认为房间创建者昵称（只读）。
@property(nonatomic, readonly, nonnull) NSString* ownerName;

/// 房主头像URL: 默认为房间创建者头像URL（只读）。
@property(nonatomic, readonly, nonnull) NSString* ownerAvatarUrl;

/// 房间创建时间（只读）。
@property(nonatomic, readonly) NSUInteger createTime;

/// 累计观看次数
@property(nonatomic, assign) NSInteger viewCount;

/// 房间信息(废弃)
@property(nonatomic, strong, readonly) TUIRoomInfo* roomInfo;

@end

/**
 * 直播统计数据
 */
TUIENGINE_EXPORT @interface TUILiveStatisticsData : NSObject

/// 累计观看次数
@property(nonatomic, assign) NSInteger totalViewers;

/// 送礼总个数
@property(nonatomic, assign) NSInteger totalGiftsSent;

/// 送礼总金额
@property(nonatomic, assign) NSInteger totalGiftCoins;

/// 送礼人数
@property(nonatomic, assign) NSInteger totalUniqueGiftSenders;

/// 点赞总数
@property(nonatomic, assign) NSInteger totalLikesReceived;

/// 消息总数
@property(nonatomic, assign) NSInteger totalMessageCount;

/// 直播时长
@property(nonatomic, assign) NSInteger liveDuration;

@end

typedef void (^TUILiveInfoBlock)(TUILiveInfo* _Nonnull liveInfo);
typedef void (^TUILiveInfoListBlock)(NSString* _Nonnull cursor, NSArray<TUILiveInfo*>* _Nonnull liveInfoList);
typedef void (^TUIStopLiveBlock)(TUILiveStatisticsData* _Nonnull statisticData);
typedef void (^TUILiveStatisticsBlock)(TUILiveStatisticsData* _Nonnull statisticData);

@protocol TUILiveListManagerObserver <NSObject>
@optional

/**
 * 直播信息改变回调
 *
 * @param liveInfo   直播间信息
 * @param modifyFlag 改变类型
 */
- (void)onLiveInfoChanged:(TUILiveInfo*)liveInfo modifyFlag:(TUILiveModifyFlag)modifyFlag NS_SWIFT_NAME(onLiveInfoChanged(liveInfo:modifyFlag:));

/**
 * 直播统计数据改变回调
 *
 * @param roomId        房间ID
 * @param statisticData 直播统计数据
 * @param modifyFlag    改变类型
 */
- (void)onLiveStatisticsChanged:(NSString*)roomId statisticData:(TUILiveStatisticsData*)statisticData modifyFlag:(TUILiveStatisticsModifyFlag)modifyFlag NS_SWIFT_NAME(onLiveStatisticsChanged(roomId:statisticData:modifyFlag:));

@end

TUIENGINE_EXPORT @interface TUILiveListManager : NSObject

/**
 * 设置事件回调
 *
 * 您可以通过 TUILiveListManagerObserver 获得直播间事件通知
 * @param observer 监听的实例
 */
- (void)addObserver:(id<TUILiveListManagerObserver>)observer NS_SWIFT_NAME(addObserver(_:));

/**
 * 移除事件回调
 *
 * @param observer 监听的实例。
 */
- (void)removeObserver:(id<TUILiveListManagerObserver>)observer NS_SWIFT_NAME(removeObserver(_:));

/**
 * 主播开播
 *
 * @param liveInfo   直播信息
 * @param onSuccess  成功回调
 * @param onError    失败回调
 */
- (void)startLive:(TUILiveInfo*)liveInfo onSuccess:(TUILiveInfoBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(startLive(liveInfo:onSuccess:onError:));

/**
 * 主播关播
 *
 * @param onSuccess  成功回调
 * @param onError    失败回调
 */
- (void)stopLive:(TUIStopLiveBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(stopLive(onSuccess:onError:));

/**
 * 进入直播间
 *
 * @param roomId 房间 ID
 * @param onSuccess  成功回调
 * @param onError    失败回调
 */
- (void)joinLive:(NSString*)roomId onSuccess:(TUILiveInfoBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(joinLive(roomId:onSuccess:onError:));

/**
 * 离开直播间
 *
 * @param onSuccess  成功回调
 * @param onError    失败回调
 */
- (void)leaveLive:(TUISuccessBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(leaveLive(onSuccess:onError:));

/**
 * 修改直播信息
 *
 * @param liveInfo   直播信息
 * @param modifyFlag 修改标记
 * @param onSuccess  成功回调
 * @param onError    失败回调
 */
- (void)setLiveInfo:(TUILiveInfo*)liveInfo modifyFlag:(TUILiveModifyFlag)modifyFlag onSuccess:(TUISuccessBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(setLiveInfo(_:modifyFlag:onSuccess:onError:));

/**
 * 获取直播信息
 *
 * @param roomId    房间ID
 * @param onSuccess 成功回调
 * @param onError   失败回调
 */
- (void)getLiveInfo:(NSString*)roomId onSuccess:(TUILiveInfoBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(getLiveInfo(_:onSuccess:onError:));

/**
 * 获取直播统计数据
 *
 * @param roomId     房间ID
 * @param onSuccess  成功回调
 * @param onError    失败回调
 */
- (void)getLiveStatistics:(NSString*)roomId onSuccess:(TUILiveStatisticsBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(getLiveStatistics(roomId:onSuccess:onError:));

/**
 * 获取直播列表
 *
 * @note 获取直播间列表，单次拉取最大支持返回 50 个。
 * @param cursor    列表下标
 * @param count     每次拉取个数
 * @param onSuccess 成功回调
 * @param onError   失败回调
 */
- (void)fetchLiveList:(NSString*)cursor count:(NSInteger)count onSuccess:(TUILiveInfoListBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(fetchLiveList(cursor:count:onSuccess:onError:));

/**
 * 开始房间视频流预加载
 *
 * @param roomId 房间ID。
 * @param isMuteAudio 是否静音播放。
 * @param view 视频渲染视图。
 * @param onPlaying 播放回调。
 * @param onLoading 加载回调。
 * @param onError 错误回调。
 */
- (void)startPreloadVideoStream:(NSString*)roomId
                    isMuteAudio:(BOOL)isMuteAudio
                           view:(TUIVideoView* __nullable)view
                      onPlaying:(TUIPlayOnPlayingBlock)onPlaying
                      onLoading:(TUIPlayOnLoadingBlock)onLoading
                        onError:(TUIPlayOnErrorBlock)onError NS_SWIFT_NAME(startPreloadVideoStream(roomId:isMuteAudio:view:onPlaying:onLoading:onError:));

/**
 * 停止房间视频流预加载
 *
 * @param roomId 房间ID。
 */
- (void)stopPreloadVideoStream:(NSString*)roomId NS_SWIFT_NAME(stopPreloadVideoStream(_:));

@end
NS_ASSUME_NONNULL_END
