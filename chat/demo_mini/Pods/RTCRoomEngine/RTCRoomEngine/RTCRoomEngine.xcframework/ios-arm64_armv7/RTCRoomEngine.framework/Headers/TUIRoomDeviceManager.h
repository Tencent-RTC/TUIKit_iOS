/**
 * Copyright (c) 2024 Tencent. All rights reserved.
 * Module:   TUIRoomDeviceManager @ TUIKitEngine
 * Function: 设备测试、管理相关接口
 */

#import <Foundation/Foundation.h>
#import "TUICommonDefine.h"

NS_ASSUME_NONNULL_BEGIN

#if TARGET_OS_MAC && !TARGET_OS_IPHONE

/**
 * 设备类型
 */
typedef NS_ENUM(NSInteger, TUIMediaDeviceType) {

    /// 未定义的设备类型
    TUIMediaDeviceTypeUnknown = -1,

    /// 麦克风类型设备
    TUIMediaDeviceTypeAudioInput = 0,

    /// 扬声器类型设备
    TUIMediaDeviceTypeAudioOutput = 1,

    /// 摄像头类型设备
    TUIMediaDeviceTypeVideoCamera = 2,

};

/**
 * 设备操作
 */
typedef NS_ENUM(NSInteger, TUIMediaDeviceState) {

    /// 设备已被插入
    TUIMediaDeviceStateAdd = 0,

    /// 设备已被移除
    TUIMediaDeviceStateRemove = 1,

    /// 设备已启用
    TUIMediaDeviceStateActive = 2,

};

#endif

#if TARGET_OS_IPHONE

/**
 * 音频路由（即声音的播放模式）
 */
typedef NS_ENUM(NSInteger, TUIAudioRoute) {

    /// Speakerphone：使用扬声器播放（即“免提”），扬声器位于手机底部，声音偏大，适合外放音乐。
    TUIAudioRouteSpeakerphone = 0,

    /// Earpiece：使用听筒播放，听筒位于手机顶部，声音偏小，适合需要保护隐私的通话场景。
    TUIAudioRouteEarpiece = 1,

};

#endif

#if TARGET_OS_MAC && !TARGET_OS_IPHONE

/**
 * 设备信息
 */
TUIENGINE_EXPORT @interface TUIDeviceInfo : NSObject

/// 设备 ID
@property(nonatomic, copy, nonnull) NSString* deviceId;

/// 设备名称
@property(nonatomic, copy, nonnull) NSString* deviceName;

/// 设备属性
@property(nonatomic, copy, nonnull) NSString* deviceProperties;

typedef void (^TUIDeviceListBlock)(NSArray<TUIDeviceInfo*>* _Nonnull list);
typedef void (^TUIDeviceInfoBlock)(TUIDeviceInfo* _Nullable deviceInfo);

@end

#endif

#if !TARGET_OS_IPHONE && TARGET_OS_MAC

@protocol TUIRoomDeviceManagerObserver <NSObject>
@optional

/**
 * 本地设备添加事件
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。当本地设备（包括摄像头、麦克风以及扬声器）添加时，SDK 便会抛出此事件回调。
 * @param deviceId 设备 ID。
 * @param type 设备类型。
 * @param state 通断状态，0：设备已添加；1：设备已被移除；2：设备已启用。
 */
- (void)onDeviceChanged:(NSString*)deviceId type:(TUIMediaDeviceType)type state:(TUIMediaDeviceState)state NS_SWIFT_NAME(onDeviceChanged(deviceId:type:state:));

/**
 * 测试摄像头画面渲染成功回调
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。当本地测试摄像头画面渲染成功时，SDK 便会抛出此事件回调。
 * @param width 画面的宽度。
 * @param height 画面的高度。
 */
- (void)onTestCameraVideoFrameRendered:(NSInteger)width height:(NSInteger)height NS_SWIFT_NAME(onTestCameraVideoFrameRendered(width:height:));

/**
 * 测试麦克风时的音量回调
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。当本地测试麦克风时，SDK 便会抛出此事件回调。
 * @param volume 麦克风采集到的音量值，取值范围0 - 100。
 */
- (void)onTestMicVolume:(NSInteger)volume NS_SWIFT_NAME(onTestMicVolume(volume:));

/**
 * 测试扬声器时的音量回调
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。当本地测试扬声器时，SDK 便会抛出此事件回调。
 * @param volume SDK 提交给扬声器去播放的声音的音量，取值范围0 - 100。
 */
- (void)onTestSpeakerVolume:(NSInteger)volume NS_SWIFT_NAME(onTestSpeakerVolume(volume:));

@end
#endif

/////////////////////////////////////////////////////////////////////////////////
//
//                    设备管理相关接口
//
/////////////////////////////////////////////////////////////////////////////////

TUIENGINE_EXPORT @interface TUIRoomDeviceManager : NSObject

#if TARGET_OS_IPHONE

/**
 * 判断当前是否为前置摄像头（仅支持移动端）
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 */
- (BOOL)isFrontCamera NS_SWIFT_NAME(isFrontCamera());

/**
 * 切换前置或后置摄像头（仅支持移动端）
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 */
- (void)switchCamera:(BOOL)frontCamera NS_SWIFT_NAME(switchCamera(_:));

/**
 * 查询是否支持自动识别人脸位置（仅支持移动端）
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 */
- (BOOL)isAutoFocusEnabled NS_SWIFT_NAME(isAutoFocusEnabled());

/**
 * 开启自动对焦功能（仅支持移动端）
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * 开启后，SDK 会自动检测画面中的人脸位置，并将摄像头的焦点始终对焦在人脸位置上。
 */
- (void)enableCameraAutoFocus:(BOOL)enabled NS_SWIFT_NAME(enableCameraAutoFocus(_:));

/**
 * 开启/关闭闪光灯，也就是手电筒模式（仅支持移动端）
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 */
- (void)enableCameraTorch:(BOOL)enabled NS_SWIFT_NAME(enableCameraTorch(_:));

/**
 * 设置音频路由（仅支持移动端）
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * 手机有两个音频播放设备：一个是位于手机顶部的听筒，一个是位于手机底部的立体声扬声器。
 * 设置音频路由为听筒时，声音比较小，只有将耳朵凑近才能听清楚，隐私性较好，适合用于接听电话。
 * 设置音频路由为扬声器时，声音比较大，不用将手机贴脸也能听清，因此可以实现“免提”的功能。
 */
- (void)setAudioRoute:(TUIAudioRoute)route NS_SWIFT_NAME(setAudioRoute(_:));

#endif

#if !TARGET_OS_IPHONE && TARGET_OS_OSX

/**
 * 设置事件回调
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * 您可以通过 TUIRoomDeviceManagerObserver 获得各类事件通知。
 * @param observer 监听的实例。
 */
- (void)setObserver:(id<TUIRoomDeviceManagerObserver>)observer NS_SWIFT_NAME(setObserver(_:));

/**
 * 开始摄像头测试（仅支持桌面端）
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。在测试过程中可以使用 {@link $setCurrentDevice$} 接口切换摄像头。
 */
- (void)startCameraDeviceTest:(TUIVideoView* __nullable)view NS_SWIFT_NAME(startCameraDeviceTest(view:));

/**
 * 结束摄像头测试（仅支持桌面端）
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 */
- (void)stopCameraDeviceTest NS_SWIFT_NAME(stopCameraDeviceTest());

/**
 * 开始麦克风测试（仅支持桌面端）
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * 该接口可以测试麦克风是否能正常工作，测试到的麦克风采集音量的大小，会以回调的形式通知给您，其中 volume 的取值范围为0 - 100。
 * @param interval 麦克风音量的回调间隔。
 * @param playback 是否开启回播麦克风声音，开启后用户测试麦克风时会听到自己的声音。
 */
- (void)startMicDeviceTest:(NSInteger)interval playback:(BOOL)playback NS_SWIFT_NAME(startMicDeviceTest(interval:playback:));

/**
 * 结束麦克风测试（仅支持桌面端）
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 */
- (void)stopMicDeviceTest NS_SWIFT_NAME(stopMicDeviceTest());

/**
 * 开始扬声器测试（仅支持桌面端）
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * 该接口通过播放指定的音频文件，用于测试播放设备是否能正常工作。如果用户在测试时能听到声音，说明播放设备能正常工作。
 * @param filePath 声音文件的路径。
 */
- (void)startSpeakerDeviceTest:(NSString*)filePath NS_SWIFT_NAME(startSpeakerDeviceTest(filePath:));

/**
 * 结束扬声器测试（仅支持桌面端）
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 */
- (void)stopSpeakerDeviceTest NS_SWIFT_NAME(stopSpeakerDeviceTest());

/**
 * 获取设备列表（仅支持桌面端）
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * @param type  设备类型，指定需要获取哪种设备的列表。详见 {@link $TUIMediaDeviceType$} 定义。
 */
- (void)getDevicesList:(TUIMediaDeviceType)type callback:(TUIDeviceListBlock)callback NS_SWIFT_NAME(getDevicesList(type:callback:));

/**
 * 设置当前要使用的设备（仅支持桌面端）
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * @param type 设备类型，详见 {@link $TUIMediaDeviceType$} 定义。
 * @param deviceId 设备ID，您可以通过接口 {@link getDevicesList} 获得设备 ID。
 */
- (void)setCurrentDevice:(TUIMediaDeviceType)type deviceId:(NSString*)deviceId NS_SWIFT_NAME(setCurrentDevice(type:deviceId:));

/**
 * 获取当前正在使用的设备（仅支持桌面端）
 *
 * @note 此函数支持会议房间类型和直播房间类型({@link TUIRoomTypeConference} & {@link TUIRoomTypeLive})。
 * @param type 设备类型，详见 {@link $TUIMediaDeviceType$} 定义。
 */
- (void)getCurrentDevice:(TUIMediaDeviceType)type callback:(TUIDeviceInfoBlock)callback NS_SWIFT_NAME(getCurrentDevice(type:callback:));

#endif

@end
NS_ASSUME_NONNULL_END
