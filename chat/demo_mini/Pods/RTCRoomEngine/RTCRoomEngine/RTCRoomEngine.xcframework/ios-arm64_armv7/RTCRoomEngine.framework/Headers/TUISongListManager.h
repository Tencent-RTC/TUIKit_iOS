/**
 * Copyright (c) 2025 Tencent. All rights reserved.
 * Module:   TUISongListManager @ TUIKitEngine
 * Function: 歌曲列表管理相关接口，用于管理直播间点歌列表。
 */

#import <Foundation/Foundation.h>
#import "TUICommonDefine.h"
#import "TUIRoomDefine.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * 歌曲列表变化原因
 */
typedef NS_ENUM(NSUInteger, TUISongListChangeReason) {
    /// 未知原因
    TUISongListChangeReasonUnknown = 0,
    
    /// 添加歌曲
    TUISongListChangeReasonAdd = 1,
    
    /// 删除歌曲
    TUISongListChangeReasonRemove = 2,
    
    /// 顺序变化（置顶等操作）
    TUISongListChangeReasonOrderChanged = 3,
};

/**
 * 歌曲信息
 */
TUIENGINE_EXPORT @interface TUISongInfo : NSObject

/// 歌曲ID
@property(nonatomic, copy, nonnull) NSString* songId;

/// 歌曲名称
@property(nonatomic, copy, nonnull) NSString* songName;

/// 歌手名称
@property(nonatomic, copy, nonnull) NSString* artistName;

/// 歌曲封面URL
@property(nonatomic, copy, nonnull) NSString* coverUrl;

/// 歌曲时长（秒）
@property(nonatomic, assign) NSUInteger duration;

/// 点歌人信息
@property(nonatomic, strong, nonnull) TUIUserInfo* requester;

@end

/**
 * 歌曲列表查询结果
 */
TUIENGINE_EXPORT @interface TUISongListResult : NSObject

/// 游标（用于分页查询）
@property(nonatomic, copy, nonnull) NSString* cursor;

/// 总数量
@property(nonatomic, assign) NSUInteger totalCount;

/// 歌曲列表
@property(nonatomic, copy, nonnull) NSArray<TUISongInfo*>* songList;

@end

typedef void (^TUISongListCallback)(TUISongListResult* _Nonnull result);

/**
 * 歌曲列表观察者协议
 */
@protocol TUISongListManagerObserver <NSObject>
@optional

/**
 * 等待播放列表变化回调
 *
 * @param reason       变化原因（添加、删除、顺序变化）
 * @param changedSongs 发生变化的歌曲列表
 */
- (void)onWaitingListChanged:(TUISongListChangeReason)reason 
                changedSongs:(NSArray<TUISongInfo*>*)changedSongs 
    NS_SWIFT_NAME(onWaitingListChanged(reason:changedSongs:));

/**
 * 已播放列表变化回调
 *
 * @param addedSongs 新增的已播放歌曲列表
 */
- (void)onPlayedListChanged:(NSArray<TUISongInfo*>*)addedSongs 
    NS_SWIFT_NAME(onPlayedListChanged(addedSongs:));

@end

/**
 * 歌曲列表管理器
 */
TUIENGINE_EXPORT @interface TUISongListManager : NSObject

/**
 * 添加事件观察者
 *
 * 通过 TUISongListManagerObserver 获取歌曲列表变化事件通知
 * @param observer 观察者实例
 */
- (void)addObserver:(id<TUISongListManagerObserver>)observer 
    NS_SWIFT_NAME(addObserver(_:));

/**
 * 移除事件观察者
 *
 * @param observer 观察者实例
 */
- (void)removeObserver:(id<TUISongListManagerObserver>)observer 
    NS_SWIFT_NAME(removeObserver(_:));

/**
 * 获取等待播放列表
 *
 * @param cursor    分页游标（首次查询传空字符串或 nil）
 * @param count     每次获取数量（1-20）
 * @param onSuccess 成功回调
 * @param onError   失败回调
 */
- (void)getWaitingList:(nullable NSString*)cursor
                 count:(NSUInteger)count
             onSuccess:(TUISongListCallback)onSuccess
               onError:(TUIErrorBlock)onError 
    NS_SWIFT_NAME(getWaitingList(cursor:count:onSuccess:onError:));

/**
 * 获取已播放列表
 *
 * @param cursor    分页游标（首次查询传空字符串或 nil）
 * @param count     每次获取数量（1-20）
 * @param onSuccess 成功回调
 * @param onError   失败回调
 */
- (void)getPlayedList:(nullable NSString*)cursor
                count:(NSUInteger)count
            onSuccess:(TUISongListCallback)onSuccess
              onError:(TUIErrorBlock)onError 
    NS_SWIFT_NAME(getPlayedList(cursor:count:onSuccess:onError:));

/**
 * 添加歌曲到播放列表
 *
 * @param songList  歌曲列表（最多10首）
 * @param onSuccess 成功回调
 * @param onError   失败回调
 */
- (void)addSong:(NSArray<TUISongInfo*>*)songList
      onSuccess:(TUISuccessBlock)onSuccess
        onError:(TUIErrorBlock)onError 
    NS_SWIFT_NAME(addSong(songList:onSuccess:onError:));

/**
 * 从播放列表删除歌曲
 *
 * @param songIdList 歌曲ID列表（最多50个）
 * @param onSuccess  成功回调
 * @param onError    失败回调
 */
- (void)removeSong:(NSArray<NSString*>*)songIdList
         onSuccess:(TUISuccessBlock)onSuccess
           onError:(TUIErrorBlock)onError 
    NS_SWIFT_NAME(removeSong(songIdList:onSuccess:onError:));

/**
 * 将指定歌曲置顶为下一首播放
 *
 * @param targetSongId 目标歌曲ID
 * @param onSuccess    成功回调
 * @param onError      失败回调
 */
- (void)setNextSong:(NSString*)targetSongId
          onSuccess:(TUISuccessBlock)onSuccess
            onError:(TUIErrorBlock)onError 
    NS_SWIFT_NAME(setNextSong(targetSongId:onSuccess:onError:));

/**
 * 播放下一首歌曲
 *
 * @param onSuccess 成功回调
 * @param onError   失败回调
 */
- (void)playNextSong:(TUISuccessBlock)onSuccess
             onError:(TUIErrorBlock)onError 
    NS_SWIFT_NAME(playNextSong(onSuccess:onError:));

@end

NS_ASSUME_NONNULL_END
