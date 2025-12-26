//
// Copyright (c) 2024 Tencent.
//
//  VideoAdvanceExtension.m
//  VideoAdvance
//
//  Created by jackyixue on 2024/12/9.
//

#import "VideoAdvanceExtension.h"

#import "VideoAdvanceConstant.h"

#import <TUICore/TUICore.h>
#import <RTCRoomEngine/TUIRoomEngine.h>
#import "TRTCCloud.h"

@interface VideoAdvanceExtension() <TUIServiceProtocol>

@end

@implementation VideoAdvanceExtension

+ (void)load {
    [TUICore registerService:TUICore_VideoAdvanceService object:[VideoAdvanceExtension sharedInstance]];
}

+ (instancetype)sharedInstance {
    static VideoAdvanceExtension *service = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        service = [[self alloc] init];
    });
    return service;
}

#pragma mark - TUIServiceProtocol
- (id)onCall:(NSString *)method param:(NSDictionary *)param {
    if ([method isEqualToString:TUICore_VideoAdvanceService_EnableUltimate]) {
        NSNumber *enableValue = param[TUICore_VideoAdvanceService_PARAM_ENABLE];
        if (enableValue && [enableValue isKindOfClass:[NSNumber class]]) {
            [self enableUltimate:enableValue.boolValue];
        }
    }
    if ([method isEqualToString:TUICore_VideoAdvanceService_EnableH265]) {
        NSNumber *enableValue = param[TUICore_VideoAdvanceService_PARAM_ENABLE];
        if (enableValue && [enableValue isKindOfClass:[NSNumber class]]) {
            [self enableH265:enableValue.boolValue];
        }
    }
    if ([method isEqualToString:TUICore_VideoAdvanceService_EnableHDR]) {
        NSNumber *enableValue = param[TUICore_VideoAdvanceService_PARAM_ENABLE];
        if (enableValue && [enableValue isKindOfClass:[NSNumber class]]) {
            [self enableHDR:enableValue.boolValue];
        }
    }
    if ([method isEqualToString:TUICore_VideoAdvanceService_EnableBFrame]) {
        NSNumber *enableValue = param[TUICore_VideoAdvanceService_PARAM_ENABLE];
        if (enableValue && [enableValue isKindOfClass:[NSNumber class]]) {
            [self enableBFrame:enableValue.boolValue];
        }
    }
    if ([method isEqualToString:TUICore_VideoAdvanceService_EnableMultiPlaybackQuality]) {
        NSNumber *enableValue = param[TUICore_VideoAdvanceService_PARAM_ENABLE];
        if (enableValue && [enableValue isKindOfClass:[NSNumber class]]) {
            [self enableMultiPlaybackQuality:enableValue.boolValue];
        }
    }
    if ([method isEqualToString:TUICore_VideoAdvanceService_EnableSwitchMultiPlayback]) {
        NSNumber *enableValue = param[TUICore_VideoAdvanceService_PARAM_ENABLE];
        if (enableValue && [enableValue isKindOfClass:[NSNumber class]]) {
            [self enableSwitchMultiPlayback:enableValue.boolValue];
        }
    }
    return nil;
}

#pragma mark - Private
- (void)enableMultiPlaybackQuality:(BOOL)enable {
    [self callEngineExperimentalAPI:@"enableMultiPlaybackQuality"
                       params:@{
        @"enable": [NSNumber numberWithInt:enable?1:0],
    }];
}

- (void)enableSwitchMultiPlayback:(BOOL)enable {
    NSDictionary *config = @{
        @"key": @"Liteav.engine.set.live.qos.audience.strategy.version",
        @"value": [NSNumber numberWithInt:enable?1:0]
    };
    [self callTRTCExperimentalAPI:@"setPrivateConfig" params:@{@"configs": @[config]}];
}

- (void)enableUltimate:(BOOL)enable {
    [self callTRTCExperimentalAPI:@"setUltimateVideoQualityConfig"
                       params:@{
        @"config": [NSNumber numberWithInt:enable?3:0],
    }];
}

- (void)enableH265:(BOOL)enable {
    [self callTRTCExperimentalAPI:@"enableHevcEncode"
                       params:@{
        @"enable": [NSNumber numberWithInt:enable?1:0],
    }];
}

- (void)enableHDR:(NSInteger)renderType {
    BOOL enable = renderType != 0;
    [self callTRTCExperimentalAPI:@"enableSDR2HDR"
                       params:@{
        @"enable": [NSNumber numberWithInt:enable?1:0],
        @"renderType": [NSNumber numberWithLong:renderType],
    }];
}

- (void)enableBFrame:(BOOL)enable {
    NSArray *configs = @[
        @{
            @"key": @"Liteav.engine.qos.b.frame.gop.strategy",
            @"value": [NSNumber numberWithInt:enable?1:0],
        }
    ];
    [self callEngineExperimentalAPI:@"setPrivateConfig"
                       params:@{
        @"configs": configs,
    }];
}

- (void)callTRTCExperimentalAPI:(NSString *)api params:(NSDictionary *)params {
    NSDictionary *jsonDict = @{
        @"api": api,
        @"params": params,
    };
    NSError *error = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:jsonDict options:0 error:&error];
    if (!jsonData || error) {
        NSLog(@"VideoAdvanceExtension callTRTCExperimentalAPI JSON error: %@", error.localizedDescription);
        return;
    }
    NSString *jsonStr = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    NSLog(@"VideoAdvanceExtension callTRTCExperimentalAPI: %@", jsonStr);
    [[self getTRTCCloud] callExperimentalAPI:jsonStr];
}

- (void)callEngineExperimentalAPI:(NSString *)api params:(NSDictionary *)params {
    NSDictionary *jsonDict = @{
        @"api": api,
        @"params": params,
    };
    NSError *error = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:jsonDict options:0 error:&error];
    if (!jsonData || error) {
        NSLog(@"VideoAdvanceExtension callEngineExperimentalAPI JSON error: %@", error.localizedDescription);
        return;
    }
    NSString *jsonStr = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    NSLog(@"VideoAdvanceExtension callEngineExperimentalAPI: %@", jsonStr);
    [[TUIRoomEngine sharedInstance] callExperimentalAPI:jsonStr callback:^(NSString * _Nonnull jsonData) {
        
    }];
}

- (TRTCCloud *)getTRTCCloud {
    return [[TUIRoomEngine sharedInstance] getTRTCCloud];
}

@end
