/**
 * Copyright (c) 2025 Tencent. All rights reserved.
 * Module:   TUILiveGiftManager @ TUIKitEngine
 * Function: 直播 礼物 相关接口
 */

#import <Foundation/Foundation.h>
#import "TUICommonDefine.h"
#import "TUIRoomDefine.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Gift 礼物信息
 */
TUIENGINE_EXPORT @interface TUIGiftInfo : NSObject

/// Gift 礼物ID
@property(nonatomic, copy) NSString *giftId;

/// Gift 礼物名称
@property(nonatomic, copy) NSString *name;

/// Gift 礼物描述
@property(nonatomic, copy) NSString *desc;

/// Gift 礼物图标URL
@property(nonatomic, copy) NSString *iconUrl;

/// Gift 礼物资源URL
@property(nonatomic, copy) NSString *resourceUrl;

/// Gift 礼物等级
@property(nonatomic, assign) NSUInteger level;

/// Gift 礼物价格
@property(nonatomic, assign) NSUInteger coins;

/// Gift 礼物扩展自定义信息
@property(nonatomic, strong) NSDictionary<NSString *, NSString *> *extensionInfo;

@end

/**
 * Gift 分类信息
 */
TUIENGINE_EXPORT @interface TUIGiftCategory : NSObject

/// Gift 分类ID
@property(nonatomic, copy) NSString *categoryId;

/// Gift 分类名称
@property(nonatomic, copy) NSString *name;

/// Gift 分类描述
@property(nonatomic, copy) NSString *desc;

/// Gift 分类扩展自定义信息
@property(nonatomic, strong) NSDictionary<NSString *, NSString *> *extensionInfo;

/// Gift 分类礼物列表
@property(nonatomic, copy) NSArray<TUIGiftInfo *> *giftList;

@end

typedef void (^TUIGetGiftListBlock)(NSArray<TUIGiftCategory *> *_Nonnull giftCategoryList);
typedef void (^TUIGetGiftCountBlock)(NSUInteger totalGiftsSent, NSUInteger totalGiftCoins, NSUInteger totalUniqueGiftSenders);
typedef void (^TUIGetLikesCountBlock)(NSUInteger totalLikesReceived);

@protocol TUILiveGiftObserver <NSObject>
@optional

/**
 * 收到礼物数量变化的通知
 *
 * @param roomId  直播间ID
 * @param totalGiftsSent  礼物数量
 * @param totalGiftCoins  礼物价值
 * @param totalUniqueGiftSenders  礼物发送者数量
 */
- (void)onGiftCountChanged:(NSString *)roomId
            totalGiftsSent:(NSUInteger)totalGiftsSent
            totalGiftCoins:(NSUInteger)totalGiftCoins
    totalUniqueGiftSenders:(NSUInteger)totalUniqueGiftSenders NS_SWIFT_NAME(onGiftCountChanged(roomId:totalGiftsSent:totalGiftCoins:totalUniqueGiftSenders:));

/**
 * 收到礼物消息的通知
 *
 * @param roomId  直播间ID
 * @param giftInfo  礼物信息
 * @param giftCount  礼物数量
 * @param sender  礼物发送者信息
 */
- (void)onReceiveGiftMessage:(NSString *)roomId giftInfo:(TUIGiftInfo *)giftInfo giftCount:(NSUInteger)giftCount sender:(TUIUserInfo *)sender NS_SWIFT_NAME(onReceiveGiftMessage(roomId:giftInfo:giftCount:sender:));

/**
 * 收到点赞消息的通知
 *
 * @param roomId  直播间ID
 * @param totalLikesReceived  点赞数量
 * @param sender  点赞发送者信息
 */
- (void)onReceiveLikesMessage:(NSString *)roomId totalLikesReceived:(NSUInteger)totalLikesReceived sender:(TUIUserInfo *)sender NS_SWIFT_NAME(onReceiveLikesMessage(roomId:totalLikesReceived:sender:));

@end

TUIENGINE_EXPORT @interface TUILiveGiftManager : NSObject

/**
 * 添加事件回调
 *
 * @param observer 监听的实例。
 */
- (void)addObserver:(id<TUILiveGiftObserver>)observer NS_SWIFT_NAME(addObserver(_:));

/**
 * 移除事件回调
 *
 * @param observer 监听的实例。
 */
- (void)removeObserver:(id<TUILiveGiftObserver>)observer NS_SWIFT_NAME(removeObserver(_:));

/**
 * 请求获取礼物列表。
 *
 * @param roomId 直播间ID
 */
- (void)getGiftList:(NSString *)roomId onSuccess:(TUIGetGiftListBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(getGiftList(roomId:onSuccess:onError:));

/**
 * 发送礼物
 *
 * @param roomId 直播间ID
 * @param giftId 礼物ID
 * @param count 礼物数量
 */
- (void)sendGift:(NSString *)roomId giftId:(NSString *)giftId count:(NSUInteger)count onSuccess:(TUISuccessBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(sendGift(roomId:giftId:count:onSuccess:onError:));

/**
 * 发送点赞
 *
 * @param roomId 直播间ID
 * @param count 点赞数量
 */
- (void)sendLike:(NSString *)roomId count:(NSUInteger)count onSuccess:(TUISuccessBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(sendLike(roomId:count:onSuccess:onError:));

/**
 * 房主获取礼物数量
 *
 * @param roomId 直播间ID
 */
- (void)getGiftCountByAnchor:(NSString *)roomId onSuccess:(TUIGetGiftCountBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(getGiftCountByAnchor(roomId:onSuccess:onError:));

/**
 * 获取点赞数量
 *
 * @param roomId 直播间ID
 */
- (void)getLikesCount:(NSString *)roomId onSuccess:(TUIGetLikesCountBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(getLikesCount(roomId:onSuccess:onError:));

@end
NS_ASSUME_NONNULL_END
