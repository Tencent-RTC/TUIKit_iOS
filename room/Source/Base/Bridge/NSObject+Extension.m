//
//  NSObject+Extension.m
//  TUIRoomKit
//
//  Created by adamsfliu on 2026/8/10.
//  Copyright © 2026 Tencent. All rights reserved.
//

#import "NSObject+Extension.h"

@implementation NSObject (RoomKitExtension)

+ (void)load {
#pragma GCC diagnostic ignored "-Wundeclared-selector"
    if ([self respondsToSelector:@selector(roomSwiftLoad)]) {
        [self performSelector:@selector(roomSwiftLoad)];
    }
}

@end
