//
//  SampleHandler.m
//  ReplayKit2Upload
//
//  Created by rushanting on 2018/3/26.
//  Copyright © 2018年 Tencent. All rights reserved.
//

#import "SampleHandler.h"
#import "ReplayKit2Define.h"
#import "ReplayKitLocalized.h"
#import <Accelerate/Accelerate.h>
#import <ReplayKit/ReplayKit.h>
#import <TXLiteAVSDK_ReplayKitExt/TXLiteAVSDK_ReplayKitExt.h>
#import <UserNotifications/UserNotifications.h>

static NSString *gRtmpUrl;
static SampleHandler *gDelegate; // retain delegate
static NSString *gResolution;

@interface SampleHandler () <TXReplayKitExtDelegate>

@end

@implementation SampleHandler

- (instancetype)init {
  self = [super init];

#if kReplayKitUseAppGroup

  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(handleReplayKit2PushStopNotification:)
             name:@"Cocoa_ReplayKit2_Push_Stop"
           object:nil];

  CFNotificationCenterAddObserver(
      CFNotificationCenterGetDarwinNotifyCenter(),
      (__bridge const void *)(self), onDarwinReplayKit2PushStart,
      kDarvinNotificationNamePushStart, NULL,
      CFNotificationSuspensionBehaviorDeliverImmediately);

  CFNotificationCenterAddObserver(
      CFNotificationCenterGetDarwinNotifyCenter(),
      (__bridge const void *)(self), onDarwinReplayKit2PushStop,
      kDarvinNotificaiotnNamePushStop, NULL,
      CFNotificationSuspensionBehaviorDeliverImmediately);

  CFNotificationCenterAddObserver(
      CFNotificationCenterGetDarwinNotifyCenter(),
      (__bridge const void *)(self), onDarwinReplayKit2RotateChange,
      kDarvinNotificaiotnNameRotationChange, NULL,
      CFNotificationSuspensionBehaviorDeliverImmediately);
  CFNotificationCenterAddObserver(
      CFNotificationCenterGetDarwinNotifyCenter(),
      (__bridge const void *)(self), onDarwinReplayKit2ResolutionChange,
      kDarvinNotificaiotnNameResolutionChange, NULL,
      CFNotificationSuspensionBehaviorDeliverImmediately);
#else

#endif
  return self;
}

- (void)dealloc {
#if kReplayKitUseAppGroup
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  CFNotificationCenterRemoveObserver(
      CFNotificationCenterGetDarwinNotifyCenter(),
      (__bridge const void *)(self), kDarvinNotificationNamePushStart, NULL);
  CFNotificationCenterRemoveObserver(
      CFNotificationCenterGetDarwinNotifyCenter(),
      (__bridge const void *)(self), kDarvinNotificaiotnNamePushStop, NULL);
  CFNotificationCenterRemoveObserver(
      CFNotificationCenterGetDarwinNotifyCenter(),
      (__bridge const void *)(self), kDarvinNotificaiotnNameRotationChange,
      NULL);
  CFNotificationCenterRemoveObserver(
      CFNotificationCenterGetDarwinNotifyCenter(),
      (__bridge const void *)(self), kDarvinNotificaiotnNameResolutionChange,
      NULL);
#endif
}

static void onDarwinReplayKit2PushStart(CFNotificationCenterRef center,
                                        void *observer, CFStringRef name,
                                        const void *object,
                                        CFDictionaryRef userInfo) {
  dispatch_after(
      dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)),
      dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter]
            postNotificationName:@"Cocoa_ReplayKit2_Push_Start"
                          object:nil];
      });
}

static void onDarwinReplayKit2PushStop(CFNotificationCenterRef center,
                                       void *observer, CFStringRef name,
                                       const void *object,
                                       CFDictionaryRef userInfo) {

  [[NSNotificationCenter defaultCenter]
      postNotificationName:@"Cocoa_ReplayKit2_Push_Stop"
                    object:nil];
}

static void onDarwinReplayKit2RotateChange(CFNotificationCenterRef center,
                                           void *observer, CFStringRef name,
                                           const void *object,
                                           CFDictionaryRef userInfo) {
  // 用剪贴板传值会有同步问题，加些延迟去避免。正式应用建议配置appgroup,使用NSUserDefault的方式传值
  dispatch_after(
      dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)),
      dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter]
            postNotificationName:@"Cocoa_ReplayKit2_Rotate_Change"
                          object:nil];
      });
}

static void onDarwinReplayKit2ResolutionChange(CFNotificationCenterRef center,
                                               void *observer, CFStringRef name,
                                               const void *object,
                                               CFDictionaryRef userInfo) {
  dispatch_after(
      dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)),
      dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter]
            postNotificationName:@"Cocoa_ReplayKit2_Resolution_Change"
                          object:nil];
      });
}

- (void)handleReplayKit2PushStopNotification:(NSNotification *)noti {
  [self sendLocalNotificationToHostAppWithTitle:
            replayKitLocalize(
                @"ReplayKitUpload.SampleHandler.tencentcloudpushstream")
                                            msg:replayKitLocalize(
                                                    @"ReplayKitUpload."
                                                    @"SampleHandler."
                                                    @"pushstreamstop")
                                       userInfo:nil];
}

- (void)sendLocalNotificationToHostAppWithTitle:(NSString *)title
                                            msg:(NSString *)msg
                                       userInfo:(NSDictionary *)userInfo {
  UNUserNotificationCenter *center =
      [UNUserNotificationCenter currentNotificationCenter];

  UNMutableNotificationContent *content =
      [[UNMutableNotificationContent alloc] init];
  content.title = [NSString localizedUserNotificationStringForKey:title
                                                        arguments:nil];
  content.body = [NSString localizedUserNotificationStringForKey:msg
                                                       arguments:nil];
  content.sound = [UNNotificationSound defaultSound];
  content.userInfo = userInfo;

  // 在 设定时间 后推送本地推送
  UNTimeIntervalNotificationTrigger *trigger =
      [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:0.1f
                                                         repeats:NO];

  UNNotificationRequest *request =
      [UNNotificationRequest requestWithIdentifier:@"ReplayKit2Demo"
                                           content:content
                                           trigger:trigger];

  // 添加推送成功后的处理！
  [center addNotificationRequest:request
           withCompletionHandler:^(NSError *_Nullable error){

           }];
}

- (void)broadcastStartedWithSetupInfo:
    (NSDictionary<NSString *, NSObject *> *)setupInfo {
  [self
      sendLocalNotificationToHostAppWithTitle:
          replayKitLocalize(
              @"ReplayKitUpload.SampleHandler.tencentcloudpushstream")
                                          msg:replayKitLocalize(
                                                  @"ReplayKitUpload."
                                                  @"SampleHandler.replaystart")
                                     userInfo:@{
                                       kReplayKit2UploadingKey :
                                           kReplayKit2Uploading
                                     }];

  [[TXReplayKitExt sharedInstance] setupWithAppGroup:kReplayKit2AppGroupId
                                            delegate:self];
}

- (void)broadcastPaused {
  // User has requested to pause the broadcast. Samples will stop being
  // delivered.
  NSLog(@"broadcastPaused");

  [self sendLocalNotificationToHostAppWithTitle:
            replayKitLocalize(
                @"ReplayKitUpload.SampleHandler.tencentcloudpushstream")
                                            msg:replayKitLocalize(
                                                    @"ReplayKitUpload."
                                                    @"SampleHandler.replaystop")
                                       userInfo:nil];
}

- (void)broadcastResumed {
  // User has requested to resume the broadcast. Samples delivery will resume.
  NSLog(@"broadcastResumed");

  [self sendLocalNotificationToHostAppWithTitle:
            replayKitLocalize(
                @"ReplayKitUpload.SampleHandler.tencentcloudpushstream")
                                            msg:replayKitLocalize(
                                                    @"ReplayKitUpload."
                                                    @"SampleHandler."
                                                    @"replayrestored")
                                       userInfo:nil];
}

- (void)broadcastFinished {
  // User has requested to finish the broadcast.
  NSLog(@"broadcastFinished");
  [self
      sendLocalNotificationToHostAppWithTitle:
          replayKitLocalize(
              @"ReplayKitUpload.SampleHandler.tencentcloudpushstream")
                                          msg:replayKitLocalize(
                                                  @"ReplayKitUpload."
                                                  @"SampleHandler.replayend")
                                     userInfo:@{
                                       kReplayKit2UploadingKey : kReplayKit2Stop
                                     }];

  [[TXReplayKitExt sharedInstance] broadcastFinished];
}

- (void)processSampleBuffer:(CMSampleBufferRef)sampleBuffer
                   withType:(RPSampleBufferType)sampleBufferType {
  @synchronized(self) {
    [[TXReplayKitExt sharedInstance] sendSampleBuffer:sampleBuffer
                                             withType:sampleBufferType];
  }
}

- (void)onNetStatus:(NSDictionary *)param {
}

#pragma mark - TXReplayKitExtDelegate
- (void)broadcastFinished:(TXReplayKitExt *)broadcast
                   reason:(TXReplayKitExtReason)reason {
  NSString *tip = @"";
  switch (reason) {
  case TXReplayKitExtReasonRequestedByMain:
    tip = replayKitLocalize(@"ReplayKitUpload.SampleHandler.screenshareend");
    break;
  case TXReplayKitExtReasonDisconnected:
    tip = replayKitLocalize(
        @"ReplayKitUpload.SampleHandler.applicationtodisconnect");
    break;
  case TXReplayKitExtReasonVersionMismatch:
    tip = replayKitLocalize(@"ReplayKitUpload.SampleHandler.integrationerror");
    break;
  }

  NSError *error =
      [NSError errorWithDomain:NSStringFromClass(self.class)
                          code:0
                      userInfo:@{NSLocalizedFailureReasonErrorKey : tip}];
  [self finishBroadcastWithError:error];
}
@end
