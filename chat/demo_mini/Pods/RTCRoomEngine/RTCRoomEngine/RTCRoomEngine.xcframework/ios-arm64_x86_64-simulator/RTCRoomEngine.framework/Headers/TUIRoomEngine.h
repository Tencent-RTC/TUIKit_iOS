/**
 * Copyright (c) 2024 Tencent. All rights reserved.
 * Module:   TUIRoomEngine @ TUIKitEngine
 * Function: TUIRoomEngine 主功能接口
 * Version: <:Version:>
 */

#import <Foundation/Foundation.h>

#import "TUIRoomDefine.h"
#import "TUIRoomObserver.h"
#import "TUILiveConnectionManager.h"
#import "TUILiveBattleManager.h"

NS_ASSUME_NONNULL_BEGIN
@class TRTCCloud;
@class TXDeviceManager;
@class TXBeautyManager;
@class TXAudioEffectManager;
@class TRTCVideoEncParam;
@class TRTCScreenCaptureSourceInfo;
@class TXMediaDeviceInfo;

TUIENGINE_EXPORT @interface TUIRoomEngine : NSObject

- (instancetype)init __attribute__((unavailable("use sharedInstance instead.")));
+ (instancetype)new NS_UNAVAILABLE;

/**
 * 获取 TUIRoomEngine 单例实例。
 *
 * 功能描述:
 * - 创建并返回 TUIRoomEngine 的全局共享实例(单例模式)。
 * - 适用于会议和直播两种房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * - 使用单例模式可避免重复创建引擎实例，节省资源。
 * 返回值说明:
 * - 返回 TUIRoomEngine 的单例实例。
 * <pre>
 * // Objective-C 调用示例
 * TUIRoomEngine *engine = [TUIRoomEngine sharedInstance];
 * // Swift 调用示例
 * let engine = TUIRoomEngine.sharedInstance()
 * </pre>
 *
 * @note
 * - 多次调用会返回同一个实例。
 */
+ (instancetype)sharedInstance NS_SWIFT_NAME(sharedInstance());

/**
 * 销毁 TUIRoomEngine 单例实例。
 *
 * 功能描述:
 * - 销毁 TUIRoomEngine 的全局共享实例。
 * - 释放引擎占用的所有资源。
 * - 调用后如需再次使用需要重新获取 sharedInstance。
 * <pre>
 * // Objective-C 调用示例
 * [TUIRoomEngine destroySharedInstance];
 * // Swift 调用示例
 * TUIRoomEngine.destroySharedInstance()
 * </pre>
 *
 * @note
 * - 为了避免销毁单例对象后引发未知异常，此接口不建议在程序运行期间调用。
 * - 调用此方法前请确保已退出所有房间。
 * - 调用此方法后所有引擎功能将不可用。
 * - 适用于会议和直播两种房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 */
+ (void)destroySharedInstance NS_SWIFT_NAME(destroySharedInstance());

/**
 * 1.1 登录接口，初始化用户信息后才能进入房间并进行操作。
 *
 * 功能描述:
 * - 初始化用户信息，建立与腾讯云实时音视频服务的连接。
 * - 适用于会议和直播两种房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * - 若用户在线时被踢下线，SDK会通过 {@link TUIRoomObserver} 中的 {@link onKickedOffLine} 回调通知。
 * <pre>
 * // Objective-C 调用示例
 * [TUIRoomEngine loginWithSDKAppId:1400000001
 *                           userId:@"user123"
 *                          userSig:@"xxxxxx"
 *                        onSuccess:^{
 *                            // 登录成功处理
 *                        }
 *                          onError:^(int code, NSString *message) {
 *                            // 登录失败处理
 *                        }];
 * // Swift 调用示例
 * TUIRoomEngine.login(sdkAppId: 1400000001,
 *                       userId: "user123",
 *                      userSig: "xxxxxx",
 *                    onSuccess: {
 *                           // 登录成功处理
 *                    },
 *                      onError: { code, message in
 *                           // 登录失败处理
 *                   })
 * </pre>
 *
 * 参数说明:
 * @param sdkAppId 它是腾讯云用于区分客户的唯一标识，进入腾讯云实时音视频 [控制台](https://console.cloud.tencent.com/rav)创建应用，即可看到 SDKAppId。
 * @param userId 用户唯一标识，用于区分不同用户。
 * @param userSig 用户签名，用于腾讯云流量的认证。
 * @param onSuccess(iOS) 登录成功的回调。
 * @param onError(iOS) 登录失败的回调。
 * @return(HarmonyOS) Promise<void> 返回一个 Promise 对象:
 * - 成功时：Promise 会 resolve，无返回值。
 * - 失败时：Promise 会 reject，返回错误对象 `{ code: number, message: string }`，其中 code 为错误码，message 为错误信息描述。
 * @note
 * - 必须先调用此接口登录成功后才能进行其他操作。
 * - 同一个 SDKAppId 下的 userId 必须唯一。
 * - userSig 需要由您的业务服务器生成。
 */
+ (void)loginWithSDKAppId:(NSInteger)sdkAppId userId:(NSString *)userId userSig:(NSString *)userSig onSuccess:(TUISuccessBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(login(sdkAppId:userId:userSig:onSuccess:onError:));

/**
 * 1.2 退出登录接口，释放资源并离开房间。
 *
 * 功能描述:
 * - 主动退出当前登录状态。
 * - 释放引擎占用的所有资源。
 * - 如果当前在房间内，会自动执行离开房间操作。
 * - 调用后如需再次使用需要重新调用 login 接口。
 * <pre>
 * // Objective-C 调用示例
 * [TUIRoomEngine logout:^{
 *     // 退出成功处理
 * } onError:^(int code, NSString *message) {
 *     // 退出失败处理
 * }];
 * // Swift 调用示例
 * TUIRoomEngine.logout {
 *     // 退出成功处理
 * } onError: { code, message in
 *     // 退出失败处理
 * }
 * </pre>
 *
 * 参数说明:
 * @param onSuccess 退出成功的回调。
 * @param onError 退出失败的回调，包含错误码和错误信息。
 * @note
 * - 调用此方法前请确保已完成所有必要的清理工作。
 * - 调用此方法后所有引擎功能将不可用。
 * - 适用于会议和直播两种房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * - 如果网络异常导致退出失败，建议重试或提示用户检查网络。
 */
+ (void)logout:(TUISuccessBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(logout(onSuccess:onError:));

/**
 * 1.3 设置本地用户名称和头像。
 *
 * 功能描述:
 * - 设置本地用户的昵称和头像 URL。
 * - 修改后的信息会同步到房间内其他用户。
 * - 适用于会议和直播两种房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * <pre>
 * // Objective-C 调用示例
 * [TUIRoomEngine setSelfInfoWithUserName:@"John"
 *                              avatarUrl:@"https://avatar.url"
 *                              onSuccess:^{
 *                                  // 设置成功处理
 *                              }
 *                                onError:^(int code, NSString *message) {
 *                                  // 设置失败处理
 *                              }];
 *  // Swift 调用示例
 * TUIRoomEngine.setSelfInfo(userName: "John",
 *                          avatarUrl: "https://avatar.url",
 *                          onSuccess: {
 *                              // 设置成功处理
 *                          },
 *                            onError: { code, message in
 *                              // 设置失败处理
 *                          })
 * </pre>
 *
 * 参数说明:
 * @param userName 用户昵称。
 * @param avatarURL 用户头像 URL 地址。
 * @param onSuccess 设置成功的回调。
 * @param onError 设置失败的回调，包含错误码和错误信息。
 * @note
 * - 头像 URL 需要是可访问的有效地址。
 * - 昵称和头像修改后会延迟至少10分钟同步到房间内其他用户。
 */
+ (void)setSelfInfoWithUserName:(NSString *)userName avatarUrl:(NSString *)avatarURL onSuccess:(TUISuccessBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(setSelfInfo(userName:avatarUrl:onSuccess:onError:));

/**
 * 1.4 获取本地用户登录的基本信息。
 *
 * 功能描述:
 * - 获取当前登录用户的详细信息。
 * - 包含用户 ID 、昵称、头像 URL 等基本信息。
 * - 适用于会议和直播两种房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * 返回值说明:
 * - 返回TUILoginUserInfo对象({@link TUILoginUserInfo})。
 * <pre>
 * // Objective-C 调用示例
 * TUILoginUserInfo *userInfo = [TUIRoomEngine getSelfInfo];
 * // Swift 调用示例
 * let userInfo = TUIRoomEngine.getSelfInfo()
 * </pre>
 *
 * @note
 * - 必须在登录成功后调用, 返回的是本地缓存的用户信息。
 */
+ (TUILoginUserInfo *)getSelfInfo NS_SWIFT_NAME(getSelfInfo());

/**
 * 1.5 设置当前登录用户的详细信息。
 *
 * 功能描述:
 * - 设置当前登录用户的基本信息，包括用户 ID 、昵称、头像 URL 等。
 * - 修改后的信息会同步到房间内其他用户。
 * - 支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * <pre>
 * // Objective-C 调用示例
 * TUILoginUserInfo *userInfo = [[TUILoginUserInfo alloc] init];
 * userInfo.userId = @"user123";
 * userInfo.userName = @"John";
 * userInfo.avatarUrl = @"https://avatar.url";
 * [TUIRoomEngine setSelfInfo:userInfo onSuccess:^{
 *   // 设置成功处理
 * } onError:^(int code, NSString *message) {
 *   // 设置失败处理
 * }];
 * // Swift 调用示例
 * let userInfo = TUILoginUserInfo()
 * userInfo.userId = "user123"
 * userInfo.userName = "John"
 * userInfo.avatarUrl = "https://avatar.url"
 * TUIRoomEngine.setSelfInfo(userInfo: userInfo, onSuccess: {
 *   // 设置成功处理
 * }, onError: { code, message in
 *   // 设置失败处理
 * })
 * </pre>
 *
 * 参数说明:
 * @param userInfo 用户信息对象({@link TUILoginUserInfo})。
 * @param callback 调用接口的回调，用于通知接口调用的成功或者失败。
 * @return(HarmonyOS) Promise<void> 返回一个 Promise 对象:
 * - 成功时：Promise 会 resolve，无返回值。
 * - 失败时：Promise 会 reject，返回错误对象 `{ code: number, message: string }`，其中 code 为错误码，message 为错误信息描述。
 * @note
 * - 必须在登录成功后调用。
 * - 头像URL需要是可访问的有效地址。
 * - 昵称和头像修改后会延迟至少10分钟同步到房间内其他用户。
 */
+ (void)setSelfInfo:(TUILoginUserInfo *)userInfo onSuccess:(TUISuccessBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(setSelfInfo(userInfo:onSuccess:onError:));

/**
 * 1.6 设置事件回调。
 *
 * 功能描述:
 * - 注册一个观察者对象以接收房间内的各种事件通知。
 * - 支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * - 通过 TUIRoomObserver 获得各类事件通知（例如：错误码，远端用户进房，音视频状态参数等）。
 * <pre>
 * // Objective-C 调用示例
 * TUIRoomEngine *engine = [TUIRoomEngine sharedInstance];
 * [engine addObserver:self];
 * // Swift 调用示例
 * let engine = TUIRoomEngine.sharedInstance()
 * engine.addObserver(self)
 * </pre>
 *
 * 参数说明:
 * @param observer 遵循TUIRoomObserver协议的对象实例。
 * @note
 * - 必须在进入房间前调用。
 * - 添加的 observer 对象需要自行管理生命周期。
 * - 避免重复添加同一个 observer 。
 * - 退出房间后不会自动移除 observer ，需手动调用 removeObserver 。
 */
- (void)addObserver:(id<TUIRoomObserver>)observer NS_SWIFT_NAME(addObserver(_:));

/**
 * 1.7 移除事件回调。
 *
 * 功能描述:
 * - 注销之前注册的观察者对象，停止接收房间内的各种事件通知。
 * - 支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * <pre>
 * // Objective-C 调用示例
 * TUIRoomEngine *engine = [TUIRoomEngine sharedInstance];
 * [engine removeObserver:self];
 * // Swift 调用示例
 * let engine = TUIRoomEngine.sharedInstance()
 * engine.removeObserver(self)
 * </pre>
 *
 * 参数说明:
 * @param observer 待移除的监听回调实例。
 * @note
 * - 移除不存在的 observer 可能会产生错误。
 * - 建议在观察者对象销毁前调用此方法。
 */
- (void)removeObserver:(id<TUIRoomObserver>)observer NS_SWIFT_NAME(removeObserver(_:));

/////////////////////////////////////////////////////////////////////////////////
//
//                   房间相关主动接口
//
/////////////////////////////////////////////////////////////////////////////////

/**
 * 2.1 创建房间。
 *
 * 功能描述:
 * - 创建一个新的房间，支持会议和直播两种房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * - 房间创建者自动成为房主。
 * - 需要提供房间信息参数来初始化房间设置。
 * <pre>
 * // Objective-C 调用示例
 * TUIRoomInfo *roomInfo = [[TUIRoomInfo alloc] init];
 * roomInfo.roomId = @"room123";
 * roomInfo.roomType = TUIRoomTypeConference;
 * roomInfo.name = @"Conference Room";
 *
 * [[TUIRoomEngine sharedInstance] createRoom:roomInfo onSuccess:^{
 *     // 创建房间成功
 * } onError:^(TUIError code, NSString * _Nonnull message) {
 *     // 创建房间失败
 * }];
 *
 * // Swift 调用示例
 * let roomInfo = TUIRoomInfo()
 * roomInfo.roomId = "room123"
 * roomInfo.roomType = .conference
 * roomInfo.name = "Conference Room"
 *
 * TUIRoomEngine.sharedInstance().createRoom(roomInfo, onSuccess: {
 *     // 创建房间成功
 * }, onError: { code, message in
 *     // 创建房间失败
 * })
 * </pre>
 *
 * 参数说明:
 * @param roomInfo 房间信息，可以初始化房间的一些设置。
 * @param onSuccess(iOS) 成功回调。
 * @param onError(iOS) 失败回调（包含错误码和错误信息）。
 * @param callback(Android/Win) 调用接口的回调，用于通知接口调用的成功或者失败, 失败回调会包含错误码和错误信息。
 * @return(HarmonyOS) Promise<void> 返回一个 Promise 对象:
 * - 成功时：Promise 会 resolve，无返回值。
 * - 失败时：Promise 会 reject，返回错误对象 `{ code: number, message: string }`，其中 code 为错误码，message 为错误信息描述。
 * @note
 * - 创建房间前需要先调用 login 方法登录。
 * - 创建不同类型的房间，会议类型 {@link TUIRoomTypeConference} / 直播类型 {@link TUIRoomTypeLive} 会影响后续的功能使用。
 * - 房间创建成功后，创建者自动成为房主。
 * - 同一用户在同一时间只能创建一个房间。
 */
- (void)createRoom:(TUIRoomInfo *)roomInfo onSuccess:(TUISuccessBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(createRoom(_:onSuccess:onError:));

/**
 * 2.2 解散房间。
 *
 * 功能描述:
 * - 解散当前所在的房间。
 * - 房间解散后，所有成员将被强制退出。
 * - 支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * <pre>
 * // Objective-C 调用示例
 * [[TUIRoomEngine sharedInstance] destroyRoom:^{
 *     // 解散房间成功
 * } onError:^(TUIError code, NSString * _Nonnull message) {
 *     // 解散房间失败
 * }];
 *
 * // Swift 调用示例
 * TUIRoomEngine.sharedInstance().destroyRoom {
 *     // 解散房间成功
 * } onError: { code, message in
 *     // 解散房间失败
 * }
 * </pre>
 *
 * 参数说明:
 * @param onSuccess(iOS) 成功回调。
 * @param onError(iOS) 失败回调（包含错误码和错误信息）。
 * @param callback(Android/Win) 调用接口的回调，用于通知接口调用的成功或者失败，失败回调会包含错误码和错误信息。
 * @return(HarmonyOS) Promise<void> 返回一个 Promise 对象:
 * - 成功时：Promise 会 resolve，无返回值。
 * - 失败时：Promise 会 reject，返回错误对象 `{ code: number, message: string }`，其中 code 为错误码，message 为错误信息描述。
 * @note
 * - 只有房主可以调用此接口。
 * - 房间解散后，SDK 会通过 {@link TUIRoomObserver} 中的 {@link onRoomDismissed} 回调通知房间内用户。
 * - 调用此接口前请确保已处理完所有房间内事务。
 * - 解散房间后无法恢复，如需继续使用需要重新创建房间。
 */
- (void)destroyRoom:(TUISuccessBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(destroyRoom(onSuccess:onError:));

/**
 * 2.3 进入房间。
 *
 * 功能描述:
 * - 此接口后期版本会将会废弃, 不建议使用。
 * - 进入房间建议使用 `2.4 enterRoom(String roomId, TUIRoomDefine.RoomType roomType` 或者 `2.5 enterRoom(String roomId, TUIRoomDefine.RoomType roomType, TUIRoomDefine.EnterRoomOptions` 接口。
 * <pre>
 * // Objective-C 调用示例
 * [[TUIRoomEngine sharedInstance] enterRoom:@"roomId123" onSuccess:^(TUIRoomInfo * _Nullable roomInfo) {
 *     // 进入房间成功
 * } onError:^(TUIError code, NSString * _Nonnull message) {
 *     // 进入房间失败
 * }];
 *
 * // Swift 调用示例
 * TUIRoomEngine.sharedInstance().enterRoom("roomId123") { roomInfo in
 *   // 进入房间成功
 * } onError: { code, message in
 *   // 进入房间失败
 * }
 * </pre>
 *
 * 参数说明:
 * @param roomId 房间 ID。
 * @param onSuccess(iOS) 成功回调。
 * @param onError(iOS) 失败回调（包含错误码和错误信息）。
 * @param callback(Android/Win) 调用接口的回调，用于通知接口调用的成功或者失败，失败回调会包含错误码和错误信息。
 * @note
 * - 单设备允许同时进入的房间数限制 1 个,超过限制后，会退出最早加入的房间。
 * - 同账号多设备登录，只允许一个设备进入相同 ID 的会议房间，其他设备进入时，会踢掉较早进入的设备。
 * - 进入房间后，SDK 会通过 {@link TUIRoomObserver} 中的 {@link onRemoteUserEnterRoom} 回调通知房间内用户。
 */
- (void)enterRoom:(NSString *)roomId onSuccess:(TUIRoomInfoBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(enterRoom(_:onSuccess:onError:));

/**
 * 2.4 进入房间。
 *
 * 功能描述:
 * - 进入指定的房间，支持会议和直播两种房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * <pre>
 * // Objective-C 调用示例
 * [[TUIRoomEngine sharedInstance] enterRoom:@"roomId123"
 *                                     roomType:TUIRoomTypeConference
 *                                 onSuccess:^(TUIRoomInfo * _Nullable roomInfo) {
 *     // 进入房间成功
 * } onError:^(TUIError code, NSString * _Nonnull message) {
 *     // 进入房间失败
 * }];
 *
 * // Swift 调用示例
 * TUIRoomEngine.sharedInstance().enterRoom("roomId123", roomType: .conference) { roomInfo in
 *     // 进入房间成功
 * } onError: { code, message in
 *     // 进入房间失败
 * }
 * </pre>
 *
 * 参数说明:
 * @param roomId 房间ID，需要保证唯一性。
 * @param roomType 房间类型（会议/直播）。
 * @param onSuccess(iOS) 成功回调。
 * @param onError(iOS) 操作失败回调（包含错误码和错误信息）。
 * @param callback(Android/Win) 调用接口的回调，用于通知接口调用的成功或者失败，失败回调会包含错误码和错误信息。
 * @note
 * - 单设备允许同时进入的房间数限制, 会议类型 {@link TUIRoomTypeConference} ：1个，直播类型 {@link TUIRoomTypeLive} ：live: 3个。超过限制后，会退出最早加入的房间。
 * - 同账号多设备登录，只允许一个设备进入相同 ID 的会议房间，其他设备进入时，会踢掉较早进入的设备。
 * - 进入房间之后，SDK 会通过 {@link TUIRoomObserver} 中的 {@link onRemoteUserEnterRoom} 回调通知房间内用户。
 */
- (void)enterRoom:(NSString *)roomId roomType:(TUIRoomType)roomType onSuccess:(TUIRoomInfoBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(enterRoom(_:roomType:onSuccess:onError:));

/**
 * 2.5 进入房间。
 *
 * 功能描述:
 * - 进入指定的房间，支持会议和直播两种房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * - 支持通过`options`传入更多进房参数，例如房间密码等。
 * <pre>
 * // Objective-C 调用示例
 * TUIEnterRoomOptions *options = [[TUIEnterRoomOptions alloc] init];
 * options.password = @"***";
 * [[TUIRoomEngine sharedInstance] enterRoom:@"roomId123"
 *                                     roomType:TUIRoomTypeConference
 *                                   options:options
 *                                 onSuccess:^(TUIRoomInfo * _Nullable roomInfo) {
 *     // 进入房间成功
 * } onError:^(TUIError code, NSString * _Nonnull message) {
 *     // 进入房间失败
 * }];
 *
 * // Swift 调用示例
 * let options = TUIEnterRoomOptions()
 * options.password = "***"
 * TUIRoomEngine.sharedInstance().enterRoom("roomId123",
 *                                          roomType: .conference,
 *                                          options: options) { roomInfo in
 *     // 进入房间成功
 * } onError: { code, message in
 *     // 进入房间失败
 * }
 * </pre>
 *
 * 参数说明:
 * @param roomId 房间 ID。
 * @param roomType 房间类型。
 * @param options 进房参数, 类型为({@link TUIEnterRoomOptions})。
 * @param onSuccess(iOS) 成功回调。
 * @param onError(iOS) 失败回调（包含错误码和错误信息）。
 * @param callback(Android/Win) 调用接口的回调，用于通知接口调用的成功或者失败，失败回调会包含错误码和错误信息。
 * @return(HarmonyOS) Promise<TUIRoomInfo> 返回一个 Promise 对象:
 * - 成功时：Promise 会 resolve，返回 {@link TUIRoomInfo} 对象，包含房间信息。
 * - 失败时：Promise 会 reject，返回错误对象 `{ code: number, message: string }`，其中 code 为错误码，message 为错误信息描述。
 * @note
 * - 单设备允许同时进入的房间数限制, 会议类型 {@link TUIRoomTypeConference} ：1个，直播类型 {@link TUIRoomTypeLive} ：live: 3个。超过限制后，会退出最早加入的房间。
 * - 同账号多设备登录，只允许一个设备进入相同 ID 的会议房间，其他设备进入时，会踢掉较早进入的设备。
 * - 进入房间之后，SDK 会通过 {@link TUIRoomObserver} 中的 {@link onRemoteUserEnterRoom} 回调通知房间内用户。
 */
- (void)enterRoom:(NSString *)roomId roomType:(TUIRoomType)roomType options:(TUIEnterRoomOptions *)options onSuccess:(TUIRoomInfoBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(enterRoom(_:roomType:options:onSuccess:onError:));

/**
 * 2.6 离开房间。
 *
 * 功能描述:
 * - 退出当前所在的房间。
 * - 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * - 退出后会自动停止所有音视频流推送。
 * <pre>
 * // Objective-C 调用示例
 * [[TUIRoomEngine sharedInstance] exitRoom:YES onSuccess:^{
 *     // 退出房间成功
 * } onError:^(TUIError code, NSString * _Nonnull message) {
 *     // 退出房间失败
 * }];
 *
 * // Swift 调用示例
 * TUIRoomEngine.sharedInstance().exitRoom(syncWaiting: true) {
 *   print("退出房间成功")
 * } onError: { code, message in
 *   print("退出房间失败: \(message)")
 * }
 * </pre>
 *
 * 参数说明:
 * @param syncWaiting 是否同步等待接口返回。
 * @param onSuccess(iOS) 成功回调。
 * @param onError(iOS) 失败回调（包含错误码和错误信息）。
 * @param callback(Android/Win) 调用接口的回调，用于通知接口调用的成功或者失败，失败回调会包含错误码和错误信息。
 * @return(HarmonyOS) Promise<void> 返回一个 Promise 对象:
 * - 成功时：Promise 会 resolve，无返回值。
 * - 失败时：Promise 会 reject，返回错误对象 `{ code: number, message: string }`，其中 code 为错误码，message 为错误信息描述。
 * @note
 * - 离开房间之后，SDK 会通过 {@link TUIRoomObserver} 中的 {@link onRemoteUserLeaveRoom} 回调通知房间内用户。
 */
- (void)exitRoom:(BOOL)syncWaiting onSuccess:(TUISuccessBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(exitRoom(syncWaiting:onSuccess:onError:));

/**
 * 2.7 获取当前进入的房间信息。
 *
 * 功能描述:
 * - 获取当前所在房间的详细信息，包括房间 ID、房间名称、房间类型等。
 * - 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * <pre>
 * // Objective-C 调用示例
 * [[TUIRoomEngine sharedInstance] fetchRoomInfo:^(TUIRoomInfo * _Nullable roomInfo) {
 *     // 获取房间信息成功
 * } onError:^(TUIError code, NSString * _Nonnull message) {
 *     // 获取房间信息失败
 * }];
 *
 * // Swift 调用示例
 * TUIRoomEngine.sharedInstance().fetchRoomInfo { roomInfo in
 *     // 获取房间信息成功
 * } onError: { code, message in
 *     // 获取房间信息失败
 * }
 * </pre>
 *
 * 参数说明:
 * @param onSuccess(iOS) 成功获取到房间信息回调，回调会包含 {@link TUIRoomInfo} 房间信息。
 * @param onError(iOS) 失败回调（包含错误码和错误信息）。
 * @param callback(Android/Win) 调用接口的回调，用于通知接口调用的成功或者失败，若成功则会返回包含 {@link TUIRoomInfo} 房间信息，若失败则会包含错误码和错误信息。
 * @return(HarmonyOS) Promise<TUIRoomInfo> 返回一个 Promise 对象:
 * - 成功时：Promise 会 resolve，返回 {@link TUIRoomInfo} 对象，包含房间信息。
 * - 失败时：Promise 会 reject，返回错误对象 `{ code: number, message: string }`，其中 code 为错误码，message 为错误信息描述。
 * @note
 * - 必须在进入房间后调用。
 * - 返回的房间信息包含房间的基本配置和当前状态。
 * - 如果当前未进入任何房间会返回错误。
 */
- (void)fetchRoomInfo:(TUIRoomInfoBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(fetchRoomInfo(onSuccess:onError:));

/**
 * 2.8 获取指定的房间信息。
 *
 * 功能描述:
 * - 获取指定房间的详细信息，包括房间ID、房间名称、房间类型等。
 * - 适用于会议和直播两种房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * <pre>
 * // Objective-C 调用示例
 * [[TUIRoomEngine sharedInstance] fetchRoomInfo:@"roomId" roomType:TUIRoomTypeConference onSuccess:^(TUIRoomInfo * _Nullable roomInfo) {
 *   // 获取房间信息成功
 * } onError:^(TUIError code, NSString * _Nonnull message) {
 *   // 获取房间信息失败
 * }];
 *
 * // Swift 调用示例
 * TUIRoomEngine.sharedInstance().fetchRoomInfo(roomId: "roomId", roomType: .conference) { roomInfo in
 *   // 获取房间信息成功
 * } onError: { code, message in
 *   // 获取房间信息失败
 * }
 * </pre>
 *
 * 参数说明:
 * @param roomId 要查询的房间ID。
 * @param roomType 房间类型（会议/直播）
 * @param onSuccess(iOS) 成功获取到房间信息回调，回调会包含 {@link TUIRoomInfo} 房间信息。
 * @param onError(iOS) 失败回调（包含错误码和错误信息）。
 * @param callback(Android/Win) 调用接口的回调，用于通知接口调用的成功或者失败，若成功则会返回包含 {@link TUIRoomInfo} 房间信息，若失败则会包含错误码和错误信息。
 * @return(HarmonyOS) Promise<TUIRoomInfo> 返回一个 Promise 对象:
 * - 成功时：Promise 会 resolve，返回 {@link TUIRoomInfo} 对象，包含房间信息。
 * - 失败时：Promise 会 reject，返回错误对象 `{ code: number, message: string }`，其中 code 为错误码，message 为错误信息描述。
 * @note
 * - 可在进入房间前调用。
 * - 返回的房间信息包含房间的基本配置和当前状态。
 * - 如果获取的房间不存在会返回错误。
 */
- (void)fetchRoomInfo:(NSString *)roomId roomType:(TUIRoomType)roomType onSuccess:(TUIRoomInfoBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(fetchRoomInfo(roomId:roomType:onSuccess:onError:));

/**
 * 2.9 更新房间名称（只有管理员或房主能够调用）。
 *
 * 功能描述:
 * - 修改当前房间的名称，适用于会议和直播两种房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * - 房间名称更新后，SDK 会通过 {@link TUIRoomObserver} 中的 {@link onRoomNameChanged} 回调通知房间内所有用户。
 * <pre>
 * // Objective-C 调用示例
 * [[TUIRoomEngine sharedInstance] updateRoomNameByAdmin:@"New Room" onSuccess:^{
 *   // 更新房间名称成功
 * } onError:^(TUIError code, NSString * _Nonnull message) {
 *   // 更新房间名称失败
 * }];
 * // Swift 调用示例
 * TUIRoomEngine.sharedInstance().updateRoomNameByAdmin(roomName: "New Room") {
 *   // 更新房间名称成功
 * } onError: { code, message in
 *   // 更新房间名称失败
 * }
 * </pre>
 *
 * 参数说明:
 * @param roomName 新的房间名称。
 * @param onSuccess(iOS) 成功更新房间名称的回调。
 * @param onError(iOS) 失败回调（包含错误码和错误信息）。
 * @param callback(Android/Win) 调用接口的回调，用于通知接口调用的成功或者失败，若失败则会包含错误码和错误信息。
 * @return(HarmonyOS) Promise<void> 返回一个 Promise 对象:
 * - 成功时：Promise 会 resolve，无返回值。
 * - 失败时：Promise 会 reject，返回错误对象 `{ code: number, message: string }`，其中 code 为错误码，message 为错误信息描述。
 * @note
 * - 只有管理员或房主可以调用此接口。
 * - 房间名称修改成功后，房间内所有用户都会收到 {@link onRoomNameChanged} 回调。
 * - 如果房间名称包含非法字符或长度超过限制，会返回错误码。
 */
- (void)updateRoomNameByAdmin:(NSString *)roomName onSuccess:(TUISuccessBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(updateRoomNameByAdmin(roomName:onSuccess:onError:));

/**
 * 2.10 更新房间麦位模式（只有管理员或房主能够调用）。
 *
 * 功能描述:
 * - 修改房间的麦位管理模式，支持自由上麦和申请上麦两种模式。
 * - 适用于会议和直播两种房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * - 麦位模式更新后，SDK 会通过 {@link TUIRoomObserver} 中的 {@link onRoomSeatModeChanged} 回调通知房间内所有用户。
 * <pre>
 *  // Objective-C 调用示例
 * [[TUIRoomEngine sharedInstance] updateRoomSeatModeByAdmin:TUISeatModeApplyToTake onSuccess:^{
 *   // 更新房间麦位模式成功
 * } onError:^(TUIError code, NSString * _Nonnull message) {
 *   // 更新房间麦位模式失败
 * }];
 * // Swift 调用示例
 * TUIRoomEngine.sharedInstance().updateRoomSeatModeByAdmin(.applyToTake) {
 *   // 更新房间麦位模式成功
 * } onError: { code, message in
 *   // 更新房间麦位模式失败
 * }
 * </pre>
 *
 * 参数说明:
 * @param seatMode {@link TUISeatModeFreeToTake}: 自由上麦模式，观众可以自由上麦无需申请。
 *                 {@link TUISeatModeApplyToTake}: 申请上麦模式，观众需要管理员/房主同意才能上麦。
 * @param onSuccess(iOS) 成功更新房间麦位模式的回调。
 * @param onError(iOS) 失败回调（包含错误码和错误信息）。
 * @param callback(Android/Win) 调用接口的回调，用于通知接口调用的成功或者失败，若失败则会包含错误码和错误信息。
 * @return(HarmonyOS) Promise<void> 返回一个 Promise 对象:
 * - 成功时：Promise 会 resolve，无返回值。
 * - 失败时：Promise 会 reject，返回错误对象 `{ code: number, message: string }`，其中 code 为错误码，message 为错误信息描述。
 * @note
 * - 只有管理员或房主可以调用此接口。
 * - 模式变更后，房间内所有用户都会收到 {@link onRoomSeatModeChanged} 回调。
 * - 自由上麦模式适用于互动性强的场景，申请上麦模式适用于需要控制发言权的场景。
 */
- (void)updateRoomSeatModeByAdmin:(TUISeatMode)seatMode onSuccess:(TUISuccessBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(updateRoomSeatModeByAdmin(_:onSuccess:onError:));

/**
 * 2.11 更新房间密码（管理员或房主专用）。
 *
 * 功能描述:
 * - 修改当前房间的访问密码，仅适用于会议房间类型({@link TUIRoomTypeConference})。
 * - 密码更新后，新加入房间的用户需要提供新密码才能进入。
 * <pre>
 * // Objective-C 调用示例
 * [[TUIRoomEngine sharedInstance] updateRoomPasswordByAdmin:@"NewPassword" onSuccess:^{
 *   // 更新房间密码成功
 * } onError:^(TUIError code, NSString *message) {
 *   // 更新房间密码失败
 * }];
 * // Swift 调用示例
 * TUIRoomEngine.sharedInstance().updateRoomPasswordByAdmin("NewPassword") {
 *   // 更新房间密码成功
 * } onError: { code, message in
 *   // 更新房间密码失败
 * }
 * </pre>
 *
 * 参数说明:
 * @param password 新的房间密码，长度建议8-16位，可包含字母、数字和特殊字符。
 * @param onSuccess(iOS) 成功更新房间密码的回调。
 * @param onError(iOS) 失败回调（包含错误码和错误信息）。
 * @param callback(Android/Win) 调用接口的回调，用于通知接口调用的成功或者失败，若失败则会包含错误码和错误信息。
 * @return(HarmonyOS) Promise<void> 返回一个 Promise 对象:
 * - 成功时：Promise 会 resolve，无返回值。
 * - 失败时：Promise 会 reject，返回错误对象 `{ code: number, message: string }`，其中 code 为错误码，message 为错误信息描述。
 * @note
 * - 只有管理员或房主可以调用此接口。
 * - 密码修改后不影响已在房间内的用户。
 * - 会议房间类型({@link TUIRoomTypeConference})专用功能，直播房间类型({@link TUIRoomTypeLive})不支持。
 */
- (void)updateRoomPasswordByAdmin:(NSString *)password onSuccess:(TUISuccessBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(updateRoomPasswordByAdmin(_:onSuccess:onError:));

/**
 * 2.12 获取房间自定义信息。
 *
 * 功能描述:
 * - 获取房间的自定义元数据信息，这些信息是房间创建时或管理员设置的键值对。
 * - 仅适用于直播房间类型({@link TUIRoomTypeLive})。
 * <pre>
 * // Objective-C 调用示例
 * [[TUIRoomEngine sharedInstance] getRoomMetadata:@[@"key1", @"key2"] onSuccess:^(NSDictionary<NSString *,NSString *> * _Nonnull metadata) {
 *   // 获取房间自定义信息成功
 * } onError:^(TUIError code, NSString * _Nonnull message) {
 *   // 获取房间自定义信息失败
 * }];
 * // Swift 调用示例
 * TUIRoomEngine.sharedInstance().getRoomMetadata(["key1", "key2"]) { metadata in
 *   // 获取房间自定义信息成功
 * } onError: { code, message in
 *   // 获取房间自定义信息失败
 * }
 * </pre>
 *
 * 参数说明:
 * @param keys 要查询的元数据键列表，如果传入空列表则获取所有元数据。
 * @param onSuccess(iOS) 成功回调，返回包含元数据的信息。
 * @param onError(iOS) 失败回调，包含错误码和错误信息。
 * @param callback(Android) 调用接口的回调，用于通知接口调用的成功或者失败，若成功则返回包含元数据的信息，若失败则会包含错误码和错误信息。
 * @return(HarmonyOS) Promise<Map<string, string>> 返回一个 Promise 对象:
 * - 成功时：Promise 会 resolve，返回 Map<string, string> 对象，包含查询到的元数据键值对。
 * - 失败时：Promise 会 reject，返回错误对象 `{ code: number, message: string }`，其中 code 为错误码，message 为错误信息描述。
 * @note
 * - 仅直播房间类型({@link TUIRoomTypeLive})支持此功能。
 * - 返回的元数据是键值对形式，值都是字符串类型。
 * - 调用此接口需要用户已在房间内。
 */
- (void)getRoomMetadata:(NSArray<NSString *> *)keys onSuccess:(TUIRoomMetadataResponseBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(getRoomMetadata(_:onSuccess:onError:));

/**
 * 2.13 设置房间自定义信息（直播房间专用）。
 *
 * 功能描述:
 * - 设置或更新房间的自定义元数据键值对，适用于直播房间类型({@link TUIRoomTypeLive})。
 * - 如果指定的键已存在，则更新其值；如果不存在，则添加新的键值对。
 * - 元数据更新后，SDK 会通过 {@link TUIRoomObserver} 中的 {@link onRoomMetadataChanged} 回调通知房间内所有用户。
 * <pre>
 * // Objective-C 调用示例
 * NSDictionary *metadata = @{@"key1": @"value1", @"key2": @"value2"};
 * [[TUIRoomEngine sharedInstance] setRoomMetadataByAdmin:metadata onSuccess:^{
 *   // 设置房间自定义信息成功
 * } onError:^(TUIError code, NSString *message) {
 *   // 设置房间自定义信息失败
 * }];
 * // Swift 调用示例
 * let metadata = ["key1": "value1", "key2": "value2"]
 * TUIRoomEngine.sharedInstance().setRoomMetadataByAdmin(metadata) {
 *   // 设置房间自定义信息成功
 * } onError: { code, message in
 *   // 设置房间自定义信息失败
 * }
 * </pre>
 *
 * 参数说明:
 * @param metadata 要设置的自定义元数据键值对，键和值都必须是字符串类型。
 * @param onSuccess(iOS) 设置成功回调。
 * @param onError(iOS) 失败回调，包含错误码和错误信息。
 * @param callback(Android) 调用接口的回调，用于通知接口调用的成功或者失败，若失败则会包含错误码和错误信息。
 * @return(HarmonyOS) Promise<void> 返回一个 Promise 对象:
 * - 成功时：Promise 会 resolve，无返回值。
 * - 失败时：Promise 会 reject，返回错误对象 `{ code: number, message: string }`，其中 code 为错误码，message 为错误信息描述。
 * @note
 * - 只有管理员或房主可以调用此接口。
 * - 元数据更新后，房间内所有用户都会收到 {@link onRoomMetadataChanged} 回调。
 * - 键长度不能超过 50 字节，值长度不超过 200 字节。
 * - 此功能仅适用于直播房间类型({@link TUIRoomTypeLive})。
 */
- (void)setRoomMetadataByAdmin:(NSDictionary<NSString *, NSString *> *)metadata onSuccess:(TUISuccessBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(setRoomMetadataByAdmin(_:onSuccess:onError:));

/////////////////////////////////////////////////////////////////////////////////
//
//                   本地用户视图渲染、视频管理
//
/////////////////////////////////////////////////////////////////////////////////

/**
 * 3.1 设置本地用户视频渲染的视图控件
 *
 * 功能描述:
 * - 设置本地用户视频画面的渲染视图，用于在本地显示摄像头采集的视频画面。
 * - 支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * - 调用此接口后，本地摄像头的视频画面将渲染到指定的视图控件上。
 * <pre>
 * // Objective-C 调用示例
 * UIView *videoView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 300, 300)];
 * [[TUIRoomEngine sharedInstance] setLocalVideoView:videoView];
 * // Swift 调用示例
 * let videoView = UIView(frame: CGRect(x: 0, y: 0, width: 300, height: 300))
 * TUIRoomEngine.sharedInstance().setLocalVideoView(view: videoView)
 * </pre>
 *
 * 参数说明:
 * @param view 视频渲染视图。
 * @note
 * - 此接口可在进入房间之前调用。
 * - 建议在打开本地摄像头前设置好渲染视图，以确保视频画面能够正常显示。
 * - 此接口仅影响本地视频的渲染，不影响视频的推送状态。
 */
- (void)setLocalVideoView:(TUIVideoView *__nullable)view NS_SWIFT_NAME(setLocalVideoView(view:));

/**
 * 3.2 打开本地摄像头
 *
 * 功能描述:
 * - 打开本地摄像头并开始采集视频画面。
 * - 支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * - 调用此接口后，本地摄像头的视频画面将开始采集，并通过之前设置的渲染视图显示。
 * <pre>
 * // Objective-C 调用示例
 * [[TUIRoomEngine sharedInstance] openLocalCamera:YES quality:TUIVideoQuality1080P onSuccess:^{
 *     // 打开本地摄像头成功
 * } onError:^(TUIError code, NSString *message) {
 *     // 打开本地摄像头失败
 * }];
 * // Swift 调用示例
 * TUIRoomEngine.sharedInstance().openLocalCamera(isFront: true, quality: .quality1080P) {
 *   // 打开本地摄像头成功
 * } onError: { code, message in
 *   // 打开本地摄像头失败
 * }
 * </pre>
 *
 * 参数说明:
 * @param isFront  {@link YES}: 前置 {@link NO}: 后置。
 * @param quality 视频质量设置，具体参考 {@link TUIVideoQuality}。
 * @param onSuccess(iOS) 打开摄像头成功回调。
 * @param onError(iOS) 打开摄像头失败回调，包含错误码和错误信息。
 * @param callback(Android) 调用接口的回调，用于通知接口调用的成功或者失败，若失败则会包含错误码和错误信息。
 * @return(HarmonyOS) Promise<void> 返回一个 Promise 对象:
 * - 成功时：Promise 会 resolve，无返回值。
 * - 失败时：Promise 会 reject，返回错误对象 `{ code: number, message: string }`，其中 code 为错误码，message 为错误信息描述。
 * @note
 * - 调用此接口前需确保已通过 `setLocalVideoView` 设置好渲染视图。
 * - 若摄像头权限未授权，调用此接口会失败。
 * - 摄像头打开后，SDK 会通过 {@link TUIRoomObserver} 中的 {@link $onUserVideoStateChanged$} 回调通知状态变化。
 */
- (void)openLocalCamera:(BOOL)isFront quality:(TUIVideoQuality)quality onSuccess:(TUISuccessBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(openLocalCamera(isFront:quality:onSuccess:onError:));

/**
 * 3.3 关闭本地摄像头
 *
 * 功能描述:
 * - 关闭本地摄像头，停止视频采集和画面推送。
 * - 适用于会议和直播两种房间类型（{@link TUIRoomTypeConference} & {@link TUIRoomTypeLive}）。
 * - 关闭后本地视频画面将不可见，远端用户也无法收到您的视频流。
 * - 调用后 SDK 会通过 {@link TUIRoomObserver} 的 {@link onUserVideoStateChanged} 回调通知房间内所有用户您的摄像头状态变化。
 * <pre>
 * // Objective-C 调用示例
 * [[TUIRoomEngine sharedInstance] closeLocalCamera];
 * // Swift 调用示例
 * TUIRoomEngine.sharedInstance().closeLocalCamera()
 * </pre>
 *
 * @note
 * - 若已设置本地视频渲染视图，关闭摄像头后该视图将不再显示视频画面。
 * - 关闭摄像头不会影响音频采集和推送。
 * - 可在房间内任意时刻调用，支持多次调用。
 */
- (void)closeLocalCamera NS_SWIFT_NAME(closeLocalCamera());

/**
 * 3.4 开始推送本地视频。默认开启
 *
 * 功能描述:
 * - 启动本地视频流推送，将摄像头采集到的视频画面发送到房间内其他用户。
 * - 支持会议和直播两种房间类型（{@link TUIRoomTypeConference} & {@link TUIRoomTypeLive}）。
 * - 若本地摄像头已打开，调用此接口后会立即开始推送视频流。
 * - 推送状态变化后，SDK 会通过 {@link TUIRoomObserver} 的 {@link onUserVideoStateChanged} 回调通知房间内用户。
 * <pre>
 * // Objective-C 调用示例
 * [[TUIRoomEngine sharedInstance] startPushLocalVideo];
 * // Swift 调用示例
 * TUIRoomEngine.sharedInstance().startPushLocalVideo()
 * </pre>
 *
 * @note
 * - 若已调用 `stopPushLocalVideo`，则需再次调用本接口恢复视频推送。
 * - 推送本地视频不会影响本地预览画面。
 */
- (void)startPushLocalVideo NS_SWIFT_NAME(startPushLocalVideo());

/**
 * 3.5 停止推送本地视频
 *
 * 功能描述:
 * - 停止将本地摄像头采集的视频画面推送到房间内其他用户。
 * - 支持会议房间类型和直播房间类型（{@link TUIRoomTypeConference} & {@link TUIRoomTypeLive}）。
 * - 停止推送后，远端用户将无法接收到您的视频流，但本地预览画面不受影响。
 * - 状态变化后，SDK 会通过 {@link TUIRoomObserver} 的 {@link onUserVideoStateChanged} 回调通知房间内用户。
 * <pre>
 * // Objective-C 调用示例
 * [[TUIRoomEngine sharedInstance] stopPushLocalVideo];
 * // Swift 调用示例
 * TUIRoomEngine.sharedInstance().stopPushLocalVideo()
 * </pre>
 *
 * @note
 * - 若需恢复视频推送，可再次调用 `startPushLocalVideo` 接口。
 * - 停止推送本地视频不会关闭摄像头，也不会影响本地视频预览。
 */
- (void)stopPushLocalVideo NS_SWIFT_NAME(stopPushLocalVideo());

/**
 * 3.6 更新本地视频编码质量设置
 *
 * 功能描述:
 * - 调整本地摄像头采集画面的编码质量，包括分辨率、码率、帧率等参数。
 * - 可用于根据网络状况或业务需求灵活切换视频清晰度。
 * - 支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * <pre>
 * // Objective-C 调用示例
 * [[TUIRoomEngine sharedInstance] updateVideoQuality:TUIVideoQuality720P];
 * // Swift 调用示例
 * TUIRoomEngine.sharedInstance().updateVideoQuality(.quality720P)
 * </pre>
 *
 * 参数说明:
 * @param quality 视频质量参数请参考 {@link TUIVideoQuality} 枚举定义。
 * @note
 * - 建议在打开摄像头后调用此接口，实时生效。
 * - 调整视频质量不会影响本地预览画面，仅影响推送到房间内其他用户的视频流质量。
 */
- (void)updateVideoQuality:(TUIVideoQuality)quality NS_SWIFT_NAME(updateVideoQuality(_:));

/**
 * 3.7 设置视频编码器的编码参数
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * @param streamType 视频流的类型，定义可参见 {@link TUIVideoStreamType} 的定义。
 * @param params 视频编码器的编码参数，定义可参见 {@link TUIRoomVideoEncoderParams} 的定义。
 */
- (void)updateVideoQualityEx:(TUIVideoStreamType)streamType params:(TUIRoomVideoEncoderParams *)params NS_SWIFT_NAME(updateVideoQualityEx(streamType:params:));

/**
 * 3.8 设置视频编码器分辨率模式（横屏分辨率 or 竖屏分辨率）
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * @param streamType 视频流的类型，定义可参见 {@link TUIVideoStreamType} 的定义。
 * @param resolutionMode 分辨率模式，定义可参见 {@link TUIResolutionMode} 的定义。
 */
- (void)setVideoResolutionMode:(TUIVideoStreamType)streamType resolutionMode:(TUIResolutionMode)resolutionMode NS_SWIFT_NAME(setVideoResolutionMode(streamType:resolutionMode:));

/**
 * 3.9  设置本地画面被暂停期间的替代图片
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * 仅在调用 stopPushLocalVideo 后支持设置垫片资源进行推流，调用 closeLocalCamera 后不支持设置垫片资源。
 * @param image 替代图片。
 */
- (void)setLocalVideoMuteImage:(nullable TUIImage *)image NS_SWIFT_NAME(setLocalVideoMuteImage(image:));

/**
 * 3.10 开启重力感应模式
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * @note 开启该模式后，当前用户发布出去的视频画面会跟随设备的重力感应方向进行相应的调整，同时本地预览画面保持方向不变。
 * @param enable {@link YES}: 开启 {@link NO}: 关闭
 */
- (void)enableGravitySensor:(BOOL)enable NS_SWIFT_NAME(enableGravitySensor(enable:));

#if TARGET_OS_IPHONE

/**
 * 3.11 开始屏幕分享（该接口仅支持移动端）
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * 开始屏幕共享之后，SDK会通过 {@link TUIRoomObserver} 中的 {@link onUserVideoStateChanged} 回调通知房间内用户。
 */
- (void)startScreenCaptureByReplaykit:(NSString *)appGroup NS_SWIFT_NAME(startScreenCapture(appGroup:))API_AVAILABLE(ios(11.0));

#endif

#if !TARGET_OS_IPHONE && TARGET_OS_MAC

/**
 * 3.11 开始屏幕分享（该接口仅支持桌面端 Mac OS 系统）
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * 开始屏幕共享之后，SDK会通过 {@link TUIRoomObserver} 中的 {@link onUserVideoStateChanged} 回调通知房间内用户。
 * @note 该接口可以抓取整个 Mac OS 系统的屏幕内容，或抓取您指定的某个应用的窗口内容，并将其分享给同房间中的其他用户。
 * @param view 渲染控件所在的父控件，可以设置为空值，表示不显示屏幕分享的预览效果。
 * @param onSuccess 成功回调。
 * @param onError 错误回调。
 */
- (void)startScreenCapture:(TUIVideoView *)view onSuccess:(TUISuccessBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(startScreenCapture(view:onSuccess:onError:));

#endif

/**
 * 3.12  结束屏幕分享
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * 结束屏幕共享之后，SDK会通过 {@link TUIRoomObserver} 中的 {@link onUserVideoStateChanged} 回调通知房间内用户，同时也会通过 {@link onUserScreenCaptureStopped} 回调通知您。
 */
- (void)stopScreenCapture NS_SWIFT_NAME(stopScreenCapture());

#if !TARGET_OS_IPHONE && TARGET_OS_MAC

/**
 * 3.13 枚举可分享的屏幕和窗口（该接口仅支持 Mac OS 系统）
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * 当您在对接桌面端系统的屏幕分享功能时，一般都需要展示一个选择分享目标的界面，这样用户能够使用这个界面选择是分享整个屏幕还是某个窗口通过本接口，您就可以查询到当前系统中可用于分享的窗口的 ID、名称以及缩略图。
 * @return 窗口列表包括屏幕。
 * @note 返回的列表中包含屏幕和应用窗口，屏幕是列表中的第一个元素, 如果用户有多个显示器，那么每个显示器都是一个分享目标。
 */
- (NSArray<TUIShareTarget *> *)getScreenCaptureSources NS_SWIFT_NAME(getScreenCaptureSources());

/**
 * 3.14 选取要分享的屏幕或窗口（该接口仅支持 Mac OS 系统）
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * 当您通过 getScreenCaptureSources 获取到可以分享的屏幕和窗口之后，您可以调用该接口选定期望分享的目标屏幕或目标窗口。
 * 在屏幕分享的过程中，您也可以随时调用该接口以切换分享目标。
 * @param targetId 指定分享源
 */
- (void)selectScreenCaptureTarget:(NSString *)targetId NS_SWIFT_NAME(selectScreenCaptureTarget(_:));

#endif

/////////////////////////////////////////////////////////////////////////////////
//
//                   本地用户音频管理
//
/////////////////////////////////////////////////////////////////////////////////

/**
 * 4.1 打开本地麦克风
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * 在房间内打开本地麦克风后，SDK会通过 {@link TUIRoomObserver} 中的 {@link onUserAudioStateChanged} 回调通知房间内用户。
 * @param quality 音频质量。
 * @param onSuccess 成功回调。
 * @param onError 失败回调。
 */
- (void)openLocalMicrophone:(TUIAudioQuality)quality onSuccess:(TUISuccessBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(openLocalMicrophone(_:onSuccess:onError:));

/**
 * 4.2 关闭本地麦克风
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * 在房间内关闭本地麦克风后，SDK会通过 {@link TUIRoomObserver} 中的 {@link onUserAudioStateChanged} 回调通知房间内用户。
 */
- (void)closeLocalMicrophone NS_SWIFT_NAME(closeLocalMicrophone());

/**
 * 4.3 更新本地音频编码质量设置
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 */
- (void)updateAudioQuality:(TUIAudioQuality)quality NS_SWIFT_NAME(updateAudioQuality(_:));

/**
 * 4.4 暂停发布本地的音频流
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * 在房间内,若您已打开您的麦克风，调用此接口暂停发布本地的音频流后，SDK会通过 {@link TUIRoomObserver} 中的 {@link onUserAudioStateChanged} 回调通知房间内用户。
 */
- (void)muteLocalAudio NS_SWIFT_NAME(muteLocalAudio());

/**
 * 4.5 恢复发布本地的音频流
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * 在房间内,若您已打开您的麦克风，调用此接口恢复发布本地的音频流后，SDK会通过 {@link TUIRoomObserver} 中的 {@link onUserAudioStateChanged} 回调通知房间内用户。
 * @param onSuccess 成功回调。
 * @param onError 失败回调。
 */
- (void)unmuteLocalAudio:(TUISuccessBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(unmuteLocalAudio(onSuccess:onError:));

#if !TARGET_OS_IPHONE && TARGET_OS_MAC

/**
 * 4.6 开启系统声音分享
 *
 * 该接口会采集您设备的音频数据，并将其混入到 SDK 当前的音频数据流中，从而使房间中的其他用户也能听到主播的电脑所播放出的声音。
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * Android 平台下：您需要先使用该接口来开启系统声音采集，当使用屏幕分享接口开启屏幕分享时才会真正生效。
 */
- (void)enableSystemAudioSharing:(BOOL)enable NS_SWIFT_NAME(enableSystemAudioSharing(_ enable:));

#endif

/////////////////////////////////////////////////////////////////////////////////
//
//                   远端用户视图渲染、视频管理
//
/////////////////////////////////////////////////////////////////////////////////

/**
 * 5.1 设置远端用户视频渲染的视图控件
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * @param userId 远端用户ID。
 * @param streamType 视频流的类型，定义可参见 {@link TUIVideoStreamType} 的定义。
 * @param view 视频渲染视图。
 */
- (void)setRemoteVideoView:(NSString *)userId streamType:(TUIVideoStreamType)streamType view:(TUIVideoView *__nullable)view NS_SWIFT_NAME(setRemoteVideoView(userId:streamType:view:));

/**
 * 5.2 开始播放远端用户视频
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * @param userId 用户ID。
 * @param streamType 视频流的类型 详细定义可以参见 {@link TUIVideoStreamType} 的定义。
 * @param onPlaying 播放回调。
 * @param onLoading 加载回调。
 * @param onError 错误回调。
 */
- (void)startPlayRemoteVideo:(NSString *)userId
                  streamType:(TUIVideoStreamType)streamType
                   onPlaying:(TUIPlayOnPlayingBlock)onPlaying
                   onLoading:(TUIPlayOnLoadingBlock)onLoading
                     onError:(TUIPlayOnErrorBlock)onError NS_SWIFT_NAME(startPlayRemoteVideo(userId:streamType:onPlaying:onLoading:onError:));

/**
 * 5.3 停止播放远端用户视频
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * @param userId 用户ID。
 * @param streamType 视频流的类型 详细定义可以参见 {@link TUIVideoStreamType} 的定义。
 */
- (void)stopPlayRemoteVideo:(NSString *)userId streamType:(TUIVideoStreamType)streamType NS_SWIFT_NAME(stopPlayRemoteVideo(userId:streamType:));

/**
 * 5.4 将远端用户静音
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * @param userId 用户ID。
 * @param isMute 是否静音。
 */
- (void)muteRemoteAudioStream:(NSString *)userId isMute:(BOOL)isMute;

/////////////////////////////////////////////////////////////////////////////////
//
//                   房间内用户信息
//
/////////////////////////////////////////////////////////////////////////////////

/**
 * 6.1  获取房间内的成员列表
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * @param nextSequence 分页拉取标志，第一次拉取填0，回调成功 如果callback返回的数据中 nextSequence 不为零，需要分页，传入再次拉取，直至为0。
 * @param onSuccess 成功回调，回调中包含 {@link TUIUserInfo} 数组。
 * @param onError 错误回调。
 */
- (void)getUserList:(NSInteger)nextSequence onSuccess:(TUIUserListResponseBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(getUserList(nextSequence:onSuccess:onError:));

/**
 * 6.2  获取成员信息
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * @param userId 用户ID。
 * @param onSuccess 成功回调，回调中包含 {@link TUIUserInfo} 数组。
 * @param onError 错误回调。
 */
- (void)getUserInfo:(NSString *)userId onSuccess:(TUIUserInfoBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(getUserInfo(_:onSuccess:onError:));

/**
 * 6.3  搜索成员信息
 *
 * @note 此函数支持直播房间类型({@link TUIRoomTypeLive})。
 * @param 搜索参数，详细定义可以参见 {@link $TUIUserSearchParam$} 的定义, param中的cursor为分页获取索引，第一次拉取填 ""，回调成功 如果callback返回的数据中
 * cursor不为""，表示需要分页，请以返回的cursor作为参数再次调用接口拉取，直至返回的cursor为""，表示数据已经全部拉取。
 * @param onSuccess 成功回调，回调中包含 {@link TUIUserInfo} 数组。
 * @param onError 错误回调。
 */
- (void)searchUsers:(TUIUserSearchParam *)param onSuccess:(TUIUserSearchResponseBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(searchUsers(param:onSuccess:onError:));

/**
 * 6.4  获取被禁言的用户列表
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 */
- (void)getBannedUserList:(TUIUserListResponseBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(getBannedUserList(onSuccess:onError:));

/////////////////////////////////////////////////////////////////////////////////
//
//                   房间内用户管理
//
/////////////////////////////////////////////////////////////////////////////////

/**
 * 7.1  修改用户角色（只有管理员或房主能够调用）
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * 修改用户角色后，SDK会通过 {@link TUIRoomObserver} 中的 {@link onUserInfoChanged} 回调通知房间内用户。
 * @param userId 用户ID。
 * @param role 用户角色 详细定义可以参见 {@link TUIRole} 的定义。
 */
- (void)changeUserRole:(NSString *)userId role:(TUIRole)role onSuccess:(TUISuccessBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(changeUserRole(userId:role:onSuccess:onError:));

/**
 * 7.2  修改用户房间内昵称
 *
 * @note 此函数仅支持会议房间类型({@link TUIRoomTypeConference})。
 * 修改用户房间内昵称后，SDK会通过 {@link TUIRoomObserver} 中的 {@link onUserInfoChanged} 回调通知房间内用户。
 * @param userId 要修改的用户ID。
 * @param nameCard 房间内用户昵称，最大支持32个字节。
 * @param onSuccess(iOS) 成功回调。
 * @param onError(iOS) 失败回调（包含错误码和错误信息）。
 * @param callback(Android/Win) 调用接口的回调，用于通知接口调用的成功或者失败，若失败则会包含错误码和错误信息。
 * @return(HarmonyOS) Promise<void> 返回一个 Promise 对象:
 * - 成功时：Promise 会 resolve，无返回值。
 * - 失败时：Promise 会 reject，返回错误对象 `{ code: number, message: string }`，其中 code 为错误码，message 为错误信息描述。
 */
- (void)changeUserNameCard:(NSString *)userId nameCard:(NSString *)nameCard onSuccess:(TUISuccessBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(changeUserNameCard(userId:nameCard:onSuccess:onError:));

/**
 * 7.3  将远端用户踢出房间（只有管理员或房主能够调用）
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * 将远端用户踢出房间后，SDK会通过 {@link TUIRoomObserver} 中的 {@link onKickedOutOfRoom} 回调通知被踢出用户，同时会通过 {@link onRemoteUserLeaveRoom} 通知房间内用户。
 * @param userId 用户ID。
 * @param onSuccess 成功回调。
 * @param onError 错误回调。
 */
- (void)kickRemoteUserOutOfRoom:(NSString *)userId onSuccess:(TUISuccessBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(kickRemoteUserOutOfRoom(_:onSuccess:onError:));

/**
 * 7.4  为用户增加标记（只有房主能够调用）
 *
 * @note 此函数仅支持会议房间类型({@link TUIRoomTypeConference})。
 * @param tag 标记类型。数字类型，大于等于 1000，您可以自定义。
 * @param userList 用户列表。
 * @param onSuccess 成功回调。
 * @param onError 错误回调。
 */
- (void)addCategoryTagForUsers:(NSInteger)tag userList:(NSArray<NSString *> *)userList onSuccess:(TUISuccessBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(addCategoryTagForUsers(tag:userList:onSuccess:onError:));

/**
 * 7.5  为用户移除标记（只有房主能够调用）
 *
 * @note 此函数仅支持会议房间类型({@link TUIRoomTypeConference})。
 * @param tag 标记类型。数字类型，大于等于 1000，您可以自定义。
 * @param userList 用户列表。
 * @param onSuccess 成功回调。
 * @param onError 错误回调。
 */
- (void)removeCategoryTagForUsers:(NSInteger)tag userList:(NSArray<NSString *> *)userList onSuccess:(TUISuccessBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(removeCategoryTagForUsers(tag:userList:onSuccess:onError:));

/**
 * 7.6  根据标记获取房间内用户信息
 *
 * @note 此函数仅支持会议房间类型({@link TUIRoomTypeConference})。
 * @param tag 标记类型。数字类型，大于等于 1000，您可以自定义。
 * @param nextSequence 分页拉取标志，第一次拉取填0，回调成功 如果callback返回的数据中 nextSequence 不为零，需要分页，传入再次拉取，直至为0。
 * @param onSuccess 成功回调。
 * @param onError 错误回调。
 */
- (void)getUserListByTag:(NSInteger)tag nextSequence:(NSInteger)nextSequence onSuccess:(TUIUserListResponseBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(getUserListByTag(tag:nextSequence:onSuccess:onError:));

/**
 * 7.7 设置房间内成员自定义信息
 *
 * @note 此函数仅支持会议房间类型({@link TUIRoomTypeConference})。
 * @param userId 用户userId。
 * @param customInfo 自定义信息。
 */
- (void)setCustomInfoForUser:(NSString *)userId customInfo:(NSDictionary<NSString *, NSData *> *)customInfo onSuccess:(TUISuccessBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(setCustomInfoForUser(userId:customInfo:onSuccess:onError:));

/////////////////////////////////////////////////////////////////////////////////
//
//                   房间内用户发言管理
//
/////////////////////////////////////////////////////////////////////////////////

/**
 * 8.1 控制当前房间内所有用户是否可打开音频流、视频流采集设备的权限状态，例如：全员禁止打开麦克风、全员禁止打开摄像头（目前仅会议场景下可用，并且只有管理员或房主能够调用）
 *
 * @note 此函数仅支持会议房间类型({@link TUIRoomTypeConference})。
 * 接口调用成功后：
 * 若device类型为 {@link MICROPHONE} ，SDK会通过 {@link TUIRoomObserver} 中的 {@link onAllUserMicrophoneDisableChanged} 通知房间内用户。
 * 若device类型为 {@link CAMERA} ，SDK会通过 {@link TUIRoomObserver} 中的 {@link onAllUserCameraDisableChanged} 通知房间内用户。
 * 若device类型为 {@link SCREEN_SHARING} ，SDK会通过 {@link TUIRoomObserver} 中的 {@link onScreenShareForAllUserDisableChanged} 通知房间内用户。
 * @param device 设备. 详细定义参见:{@link TUIMediaDevice}。
 * @param isDisable 是否禁用 。
 * @param onSuccess 操作成功回调。
 * @param onError 操作失败回调。
 */
- (void)disableDeviceForAllUserByAdmin:(TUIMediaDevice)device isDisable:(BOOL)isDisable onSuccess:(TUISuccessBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(disableDeviceForAllUserByAdmin(device:isDisable:onSuccess:onError:));

/**
 * 8.2  请求远端用户打开媒体设备（只有管理员或房主能够调用,device类型不支持SCREEN_SHARING）
 *
 * @note 此函数仅支持会议房间类型({@link TUIRoomTypeConference})。
 * 调用此接口后，SDK会通过 {@lin kTUIRoomObserver} 中的 {@link onRequestReceived} 通知被请求用户。
 * @param userId 用户ID。
 * @param device 媒体设备。详细定义参见:{@link TUIMediaDevice}。
 * @param timeout 超时时间，单位秒，如果设置为 0，SDK 不会做超时检测，也不会触发超时回调。
 * @param onAccepted 邀请被接受的回调。
 * @param onRejected 邀请被拒绝的回调。
 * @param onCancelled 邀请被取消的回调。
 * @param onTimeout 邀请超时未处理的回调。
 * @param onError 邀请发生错误的回调。
 * @return TUIRequest 请求体。
 */
- (TUIRequest *)openRemoteDeviceByAdmin:(NSString *)userId
                                 device:(TUIMediaDevice)device
                                timeout:(NSTimeInterval)timeout
                             onAccepted:(nullable TUIRequestAcceptedBlock)onAccepted
                             onRejected:(nullable TUIRequestRejectedBlock)onRejected
                            onCancelled:(nullable TUIRequestCancelledBlock)onCancelled
                              onTimeout:(nullable TUIRequestTimeoutBlock)onTimeout
                                onError:(nullable TUIRequestErrorBlock)onError NS_SWIFT_NAME(openRemoteDeviceByAdmin(userId:device:timeout:onAccepted:onRejected:onCancelled:onTimeout:onError:));

/**
 * 8.3 关闭远端用户媒体设备（只有管理员或房主能够调用）
 *
 * @note 此函数仅支持会议房间类型({@link TUIRoomTypeConference})。
 * 接口调用成功后：
 * 若device类型为 {@link MICROPHONE} ，SDK会通过 {@link TUIRoomObserver} 中的 {@link onUserAudioStateChanged} 通知房间内用户。
 * 若device类型为 {@link CAMERA} 或 {@link SCREEN_SHARING}，SDK会通过 {@link TUIRoomObserver} 中的 {@link onUserVideoStateChanged} 通知房间内用户。
 * @param userId 用户ID。
 * @param device 媒体设备。详细定义参见:{@link TUIMediaDevice}。
 * @param onSuccess 调用成功回调。
 * @param onError 调用失败回调。
 */
- (void)closeRemoteDeviceByAdmin:(NSString *)userId device:(TUIMediaDevice)device onSuccess:(TUISuccessBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(closeRemoteDeviceByAdmin(userId:device:onSuccess:onError:));

/**
 * 8.4 请求打开本地媒体设备（普通用户可用,device类型不支持SCREEN_SHARING）
 *
 * @note 此函数仅支持会议房间类型({@link TUIRoomTypeConference})。
 * 接口调用成功后,SDK会通过 {@link TUIRoomObserver} 中的 {@link onRequestReceived} 通知被请求用户。
 * @param device 用户ID@param device 媒体设备。详细定义参见:{@link TUIMediaDevice}。
 * @param timeout 超时时间，单位秒，如果设置为 0，SDK 不会做超时检测，也不会触发超时回调。
 * @param onAccepted 邀请被接受的回调。
 * @param onRejected 邀请被拒绝的回调。
 * @param onCancelled 邀请被取消的回调。
 * @param onTimeout 邀请超时未处理的回调。
 * @param onError 邀请发生错误的回调。
 * @return TUIRequest 请求体。
 */
- (TUIRequest *)applyToAdminToOpenLocalDevice:(TUIMediaDevice)device
                                      timeout:(NSTimeInterval)timeout
                                   onAccepted:(nullable TUIRequestAcceptedBlock)onAccepted
                                   onRejected:(nullable TUIRequestRejectedBlock)onRejected
                                  onCancelled:(nullable TUIRequestCancelledBlock)onCancelled
                                    onTimeout:(nullable TUIRequestTimeoutBlock)onTimeout
                                      onError:(nullable TUIRequestErrorBlock)onError NS_SWIFT_NAME(applyToAdminToOpenLocalDevice(device:timeout:onAccepted:onRejected:onCancelled:onTimeout:onError:));

/////////////////////////////////////////////////////////////////////////////////
//
//                    房间内麦位管理
//
/////////////////////////////////////////////////////////////////////////////////

/**
 * 9.1  获取麦位列表
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 */
- (void)getSeatList:(TUISeatListResponseBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(getSeatList(onSuccess:onError:));

/**
 * 9.2  锁定麦位（只有管理员或房主能够调用，包括位置锁定、音频状态锁定和视频状态锁定）
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * @param seatIndex 麦位编号。
 * @param lockParams 锁麦参数。详情参见:{@link $TUISeatLockParam$}。
 */
- (void)lockSeatByAdmin:(NSInteger)seatIndex lockMode:(TUISeatLockParams *)lockParams onSuccess:(TUISuccessBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(lockSeatByAdmin(_:lockMode:onSuccess:onError:));

/**
 * 9.3  上麦（上麦发言模式下，需要申请）
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * 上麦成功后,SDK会通过 {@link TUIRoomObserver} 中的 {@link onSeatListChanged} 通知房间内用户。
 * @note 开启上麦发言模式时，需要向主持人或管理员发起申请才允许上麦。
 *       开启自由发言模式，直播场景可以自由上麦，上麦后开麦发言，会议场景无需调用该接口，即可开麦发言。
 * @param seatIndex 麦位编号。未开启麦位、不关心麦位序列的情况下，填-1即可。
 * @param timeout 超时时间，单位秒，如果设置为 0，SDK 不会做超时检测，也不会触发超时回调。
 * @param extensionInfo 扩展信息。
 * @param onAccepted 邀请被接受的回调。
 * @param onRejected 邀请被拒绝的回调。
 * @param onCancelled 邀请被取消的回调。
 * @param onTimeout 邀请超时未处理的回调。
 * @param onSuccess 邀请发送成功的回调。
 * @param onError 邀请发生错误的回调。
 * @return TUIRequest 请求体。
 */
- (TUIRequest *)takeSeat:(NSInteger)seatIndex
                 timeout:(NSTimeInterval)timeout
           extensionInfo:(NSString *)extensionInfo
              onAccepted:(TUIRequestAcceptedCallback)onAccepted
              onRejected:(TUIRequestRejectedCallback)onRejected
             onCancelled:(TUIRequestCancelledCallback)onCancelled
               onTimeout:(TUIRequestTimeoutCallback)onTimeout
               onSuccess:(TUIRequestSuccessCallback)onSuccess
                 onError:(TUIRequestErrorCallback)onError NS_SWIFT_NAME(takeSeat(seatIndex:timeout:extensionInfo:onAccepted:onRejected:onCancelled:onTimeout:onSuccess:onError:));

/**
 * 9.4  下麦
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * 下麦成功后,SDK会通过 {@link TUIRoomObserver} 中的 {@link onSeatListChanged} 通知房间内用户。
 */
- (void)leaveSeat:(TUISuccessBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(leaveSeat(onSuccess:onError:));

/**
 * 9.5  移麦
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * 移麦成功后,SDK会通过 {@link TUIRoomObserver} 中的 {@link onSeatListChanged} 通知房间内用户。
 */
- (void)moveToSeat:(NSInteger)targetSeatIndex onSuccess:(TUISuccessBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(moveToSeat(targetSeatIndex:onSuccess:onError:));

/**
 * 9.6  主持人/管理员 邀请用户上麦
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * 接口调用成功后,SDK会通过 {@link TUIRoomObserver} 中的 {@link onRequestReceived} 通知被邀请用户。
 * @param seatIndex 麦位编号。未开启麦位、不关心麦位序列的情况下，填-1即可。
 * @param userId 用户ID。
 * @param timeout 超时时间，单位秒，如果设置为 0，SDK 不会做超时检测，也不会触发超时回调。
 * @param extensionInfo 扩展信息。
 * @param onAccepted 邀请被接受的回调。
 * @param onRejected 邀请被拒绝的回调。
 * @param onCancelled 邀请被取消的回调。
 * @param onTimeout 邀请超时未处理的回调。
 * @param onSuccess 邀请发送成功的回调。
 * @param onError 邀请发生错误的回调。
 * @return TUIRequest 请求体。
 */
- (TUIRequest *)takeUserOnSeatByAdmin:(NSInteger)seatIndex
                               userId:(NSString *)userId
                              timeout:(NSTimeInterval)timeout
                        extensionInfo:(NSString *)extensionInfo
                           onAccepted:(TUIRequestAcceptedCallback)onAccepted
                           onRejected:(TUIRequestRejectedCallback)onRejected
                          onCancelled:(TUIRequestCancelledCallback)onCancelled
                            onTimeout:(TUIRequestTimeoutCallback)onTimeout
                            onSuccess:(TUIRequestSuccessCallback)onSuccess
                              onError:(TUIRequestErrorCallback)onError NS_SWIFT_NAME(takeUserOnSeatByAdmin(seatIndex:userId:timeout:extensionInfo:onAccepted:onRejected:onCancelled:onTimeout:onSuccess:onError:));

/**
 * 9.7  主持人/管理员 将用户踢下麦
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * 接口调用成功后,SDK会通过 {@link TUIRoomObserver} 中的 {@link onSeatListChanged} 通知房间内用户。
 * @param seatIndex 麦位编号。未开启麦位、不关心麦位序列的情况下，填-1即可。
 * @param userId 用户ID。
 * @param extensionInfo 扩展信息。
 */
- (void)kickUserOffSeatByAdmin:(NSInteger)seatIndex
                        userId:(NSString *)userId
                 extensionInfo:(NSString *)extensionInfo
                     onSuccess:(TUISuccessBlock)onSuccess
                       onError:(TUIErrorBlock)onError NS_SWIFT_NAME(kickUserOffSeatByAdmin(seatIndex:userId:extensionInfo:onSuccess:onError:));

/**
 * 9.8 移动麦上的用户（仅支持房主或者管理员使用此接口）
 *
 * @note 当目标麦位有人时，支持三种移麦策略：
 * - 中断操作（默认）
 * - 强制替换 - 将原麦位用户踢下麦
 * - 交换位置 - 互换两个用户的麦位
 * @param userId 待移动的麦上用户
 * @param targetSeatIndex 目标麦位的 index
 * @param policy 移动麦上用户时的策略
 */
- (void)moveUserToSeatByAdmin:(NSString *)userId
              targetSeatIndex:(NSInteger)targetSeatIndex
                       policy:(TUIMoveSeatPolicy)policy
                    onSuccess:(TUISuccessBlock)onSuccess
                      onError:(TUIErrorBlock)onError NS_SWIFT_NAME(moveUserToSeatByAdmin(userId:targetSeatIndex:policy:onSuccess:onError:));

/**
 * 9.9  主持人/管理员 获取房间内申请上麦用户的请求列表
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 */
- (void)getSeatApplicationList:(TUIRequestListResponseBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(getSeatApplicationList(onSuccess:onError:));

/**
 * 9.10 查询麦位列表
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 */
- (NSArray<TUISeatFullInfo *> *)querySeatList NS_SWIFT_NAME(querySeatList());

/////////////////////////////////////////////////////////////////////////////////
//
//                   房间内消息
//
/////////////////////////////////////////////////////////////////////////////////

/**
 * 10.1  禁用远端用户的发送文本消息能力（只有管理员或房主能够调用）
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * 禁用远端用户的发送文本消息能力后,SDK会通过 {@link TUIRoomObserver} 中的 {@link onSendMessageForUserDisableChanged} 通知被禁用用户。
 * @param userId 用户ID。
 * @param isDisable 是否禁用。
 * @param onSuccess 成功回调。
 * @param onError 错误回调。
 */
- (void)disableSendingMessageByAdmin:(NSString *)userId isDisable:(BOOL)isDisable onSuccess:(TUISuccessBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(disableSendingMessageByAdmin(userId:isDisable:onSuccess:onError:));

/**
 * 10.2  禁用所有用户的发送文本消息能力（只有管理员或房主能够调用）
 *
 * @note 此函数仅支持会议房间类型({@link TUIRoomTypeConference})。
 * 禁用所有用户的发送文本消息能力后,SDK会通过 {@link TUIRoomObserver} 中的 {@link onSendMessageForAllUserDisableChanged} 通知房间内用户。
 * @param isDisable 是否禁用。
 * @param onSuccess 成功回调。
 * @param onError 错误回调。
 */
- (void)disableSendingMessageForAllUser:(BOOL)isDisable onSuccess:(TUISuccessBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(disableSendingMessageForAllUser(isDisable:onSuccess:onError:));

/**
 * 10.3  发送文本消息
 *
 * @param textMessage 消息对象。
 * @param onSuccess 成功回调。
 * @param onError 错误回调。
 */
- (void)sendTextMessage:(TUIRoomTextMessage *)textMessage onSuccess:(TUISendTextMessageBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(sendTextMessage(textMessage:onSuccess:onError:));

/**
 * 10.4  发送自定义消息
 *
 * @param customMessage 消息对象。
 * @param onSuccess 成功回调。
 * @param onError 错误回调。
 */
- (void)sendCustomMessage:(TUIRoomCustomMessage *)customMessage onSuccess:(TUISendCustomMessageBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(sendCustomMessage(customMessage:onSuccess:onError:));

/////////////////////////////////////////////////////////////////////////////////
//
//                    信令管理
//
/////////////////////////////////////////////////////////////////////////////////

/**
 * 11.1  取消请求
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * 取消请求后,SDK会通过 {@link TUIRoomObserver} 中的 {@link onRequestCancelled} 通知被请求用户。
 * @note 可以使用此接口来取消已发出的请求。
 * @param requestId 请求ID(发送请求的接口返回或者OnRequestReceived事件通知)。
 * @param onSuccess 成功回调。
 * @param onError 失败回调。
 */
- (void)cancelRequest:(NSString *)requestId onSuccess:(TUISuccessBlock)onSuccess onError:(TUIErrorBlock)onError NS_SWIFT_NAME(cancelRequest(_:onSuccess:onError:));

/**
 * 11.2  回复请求
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * @note 在收到信令请求时，可以使用此接口来回复接收到的请求。
 * @param requestId 请求ID(发送请求的接口返回或者OnRequestReceived事件通知)。
 * @param agree 是否同意 YES: 同意请求, NO: 拒绝请求。
 * @param extensionInfo 扩展信息。
 * @param onSuccess 成功回调。
 * @param onError 失败回调。
 */
- (void)responseRemoteRequest:(NSString *)requestId
                        agree:(BOOL)agree
                extensionInfo:(NSString *)extensionInfo
                    onSuccess:(TUISuccessBlock)onSuccess
                      onError:(TUIErrorBlock)onError NS_SWIFT_NAME(responseRemoteRequest(requestId:agree:extensionInfo:onSuccess:onError:));

/////////////////////////////////////////////////////////////////////////////////
//
//                    高级功能
//
/////////////////////////////////////////////////////////////////////////////////

/**
 * 12.1 获得TRTC实例对象
 */
- (TRTCCloud *)getTRTCCloud NS_SWIFT_NAME(getTRTCCloud());

/**
 * 12.2 设置美颜级别
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * @param beautyStyle 美颜风格，取值如下：
 * 0：光滑，磨皮效果比较明显；
 * 1：自然，磨皮效果比较自然，更多地保留了面部细节；
 * 2：优图，磨皮效果介于光滑和自然之间，比光滑保留更多皮肤细节，比自然磨皮程度更高。
 * @param beautyLevel 美颜级别，取值范围 0 - 9； 0 表示关闭，9 表示效果最明显。
 */
- (void)setBeautyLevel:(NSInteger)beautyStyle beautyLevel:(float)beautyLevel NS_SWIFT_NAME(setBeautyLevel(beautyStyle:beautyLevel:));

/**
 * 12.3 设置美白级别
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * @param whitenessLevel 美白级别，取值范围 0 - 9；0 表示关闭，9 表示效果最明显。
 */
- (void)setWhitenessLevel:(float)whitenessLevel NS_SWIFT_NAME(setWhitenessLevel(whitenessLevel:));

/**
 * 12.4 获取插件
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * @param extensionType 插件类型。
 */
- (id)getExtension:(TUIExtensionType)extensionType NS_SWIFT_NAME(getExtension(extensionType:));

/**
 * 12.5 获取设备管理类
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 */
- (TUIRoomDeviceManager *)getMediaDeviceManager NS_SWIFT_NAME(getMediaDeviceManager());

/**
 * 12.6 获取连线管理类
 *
 * @note 此函数支持直播房间类型({@link TUIRoomTypeLive})。
 */
- (TUILiveConnectionManager *)getLiveConnectionManager NS_SWIFT_NAME(getLiveConnectionManager());

/**
 * 12.7 获取 Battle 管理类
 *
 * @note 此函数支持直播房间类型({@link TUIRoomTypeLive})。
 */
- (TUILiveBattleManager *)getLiveBattleManager NS_SWIFT_NAME(getLiveBattleManager());

/////////////////////////////////////////////////////////////////////////////////
//
//                    调试相关
//
/////////////////////////////////////////////////////////////////////////////////

/**
 * 13.1 调用实验性接口
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * @param  jsonStr 接口信息。
 * @return 返回结果
 */
- (id)callExperimentalAPI:(NSString *)jsonStr callback:(TUIExperimentalAPIResponseBlock)callback NS_SWIFT_NAME(callExperimentalAPI(jsonStr:callback:));

/////////////////////////////////////////////////////////////////////////////////
//
//                    State 相关
//
/////////////////////////////////////////////////////////////////////////////////

/**
 * 13.2 语义化的 JSON API.
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 */
- (void)call:(NSString *)api param:(NSString *)jsonParam callback:(TUIJsonAPIResponseBlock)callback NS_SWIFT_NAME(call(api:param:callback:));
- (NSString *)query:(NSString *)api param:(NSString *)jsonParam NS_SWIFT_NAME(query(api:param:));

@end
NS_ASSUME_NONNULL_END
#import "DeprecatedRoomEngineAPI.h"
