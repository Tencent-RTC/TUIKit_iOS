/////////////////////////////////////////////////////////////////////
//
//                     腾讯云通信服务 IMSDK
//
//  模块名称：V2TIMManager+LiveActivity
//
//  消息 LiveActivity 推送接口
//
/////////////////////////////////////////////////////////////////////

#import "V2TIMManager.h"

@class V2TIMLiveActivityConfig;

V2TIM_EXPORT @interface V2TIMManager (LiveActivity)

/**
 *  1.1 设置 LiveActivity 远端推送配置。
 *
 *  有两种使用场景：
 *  1、远程启动（push-to-start，iOS 17.2+）：App 未打开时，由服务器远程拉起一个新的 LiveActivity。
 *     - 需设置：attributesType（活动类型名） + token（push-to-start token） + businessID
 *     - 无需设置 activityID（此时实例尚未创建）
 *
 *  2、远程更新 / 结束（update / end，iOS 16.1+）：对已存在的 LiveActivity 实例进行刷新或结束。
 *     - 需设置：activityID（实例标识） + token（update token） + businessID
 *     - 无需设置 attributesType
 *
 *  @note 当 config 为 nil 时，清除所有的远端推送配置。
 */
- (void)setLiveActivity:(V2TIMLiveActivityConfig * _Nullable)config succ:(_Nullable V2TIMSucc)succ fail:(_Nullable V2TIMFail)fail NS_SWIFT_NAME(setLiveActivity(config:succ:fail:));


@end


V2TIM_EXPORT @interface V2TIMLiveActivityConfig : NSObject

/**
 * ActivityAttributes 类型名（如 @"MatchAttributes"），必须与客户端创建活动的类名完全一致。
 * 仅远程启动（push-to-start）场景必填；远程更新 / 结束场景无需设置。
 */
@property (nonatomic, strong, nullable) NSString *attributesType;

/**
 * LiveActivity 实例的唯一标识。
 * 仅远程更新 / 结束场景必填；远程启动（push-to-start）场景无需设置。
 */
@property(nonatomic,strong) NSString *activityID;

/**
 * LiveActivity token。
 * 远程启动场景传 push-to-start token；远程更新 / 结束场景传 update token。
 */
@property (nonatomic, strong, nullable) NSData *token;

/**
 * IM 控制台上传的 P8 证书 ID
 */
@property (nonatomic, assign) int businessID;

@end
