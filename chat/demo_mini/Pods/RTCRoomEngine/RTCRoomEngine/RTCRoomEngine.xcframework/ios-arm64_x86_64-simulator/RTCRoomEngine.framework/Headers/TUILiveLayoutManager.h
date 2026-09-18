/**
 * Copyright (c) 2024 Tencent. All rights reserved.
 * Module:   TUILiveLayoutManager @ TUIKitEngine
 * Function: 直播画面装饰相关接口
 */

#import <Foundation/Foundation.h>
#import "TUICommonDefine.h"
#import "TUIRoomDefine.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * 麦位的 UI 布局信息
 */
TUIENGINE_EXPORT @interface TUISeatLayout : NSObject

/// 当前使用的麦位布局模板的 ID
@property(nonatomic, assign, readonly) NSUInteger templateId;

/// 画布的宽度
@property(nonatomic, assign, readonly) NSUInteger canvasWidth;

/// 画布的高度
@property(nonatomic, assign, readonly) NSUInteger canvasHeight;

/// 麦位列表
@property(nonatomic, copy, readonly, nonnull) NSArray<TUISeatFullInfo *> *seatList;

@end

@protocol TUILiveLayoutObserver <NSObject>

@optional

/**
 * 麦位布局发生变化的通知.（从 3.3 版本开始支持）
 *
 * @param roomId 房间 ID
 * @param layout 最新的布局信息
 */
- (void)onSeatLayoutChanged:(NSString *)roomId layout:(TUISeatLayout *)layout NS_SWIFT_NAME(onSeatLayoutChanged(roomId:layout:));

/**
 * 直播画面布局发生改变 (从 3.3 版本开始废弃，请使用 onSeatLayoutChanged 代替)
 *
 * @param roomId 房间ID
 * @param layoutInfo 最新的画面布局信息
 */
- (void)onLiveVideoLayoutChanged:(NSString *)roomId
                      layoutInfo:(NSString *)layoutInfo NS_SWIFT_NAME(onLiveVideoLayoutChanged(roomId:layoutInfo:)) __attribute__((deprecated("Deprecated in version 3.3 and later, use onSeatLayoutChanged(roomId:layout:) instead.")));

@end

TUIENGINE_EXPORT @interface TUILiveLayoutManager : NSObject

/**
 * 添加事件回调
 *
 * @param observer 监听的实例。
 */
- (void)addObserver:(id<TUILiveLayoutObserver>)observer NS_SWIFT_NAME(addObserver(_:));

/**
 * 移除事件回调
 *
 * @param observer 监听的实例。
 */
- (void)removeObserver:(id<TUILiveLayoutObserver>)observer NS_SWIFT_NAME(removeObserver(_:));

/**
 * 自定义设置视频流布局
 *
 * @param roomID 房间ID。
 * @param layoutInfo 布局Json信息。
 */
- (void)setLiveStreamLayoutInfo:(NSString *)roomID layoutInfo:(NSString *)layoutInfo onSuccess:(TUISuccessBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(setLiveStreamLayoutInfo(roomID:layoutInfo:onSuccess:onError:));

@end
NS_ASSUME_NONNULL_END
