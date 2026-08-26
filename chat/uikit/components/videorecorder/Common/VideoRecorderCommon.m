// Copyright (c) 2024 Tencent. All rights reserved.
// Author: eddardliu

#import "VideoRecorderCommon.h"
#import "VideoRecorderNSArray+Functional.h"

#define ChatEngineLanguageKey @"AtomicXLanguageKey"
#define BundleResourceUrlPrefix  @"file:///asset/"

@interface NSString (TUIHexColorPrivate)
- (NSUInteger)_hexValue;
@end

@implementation NSString (TUIHexColorPrivate)
- (NSUInteger)_hexValue {
    NSUInteger result = 0;
    sscanf([self UTF8String], "%lx", &result);
    return result;
}
@end

@implementation VideoRecorderCommon

@dynamic assetsBundle;

+ (NSBundle *)assetsBundle {
    NSBundle *modleBundle = [self modleNSBundle];
    if (!modleBundle) {
        NSLog(@"error: can not find ChatUIKitBundle");
        return nil;
    }
    NSURL *videoRecorderURL = [modleBundle URLForResource:@"VideoRecorder"
                                            withExtension:@"bundle"];
    
    if (!videoRecorderURL) {
        NSLog(@"error: can not find VideoRecorder.bundle");
        return nil;
    }
    
    NSBundle *videoRecorderBundle = [NSBundle bundleWithURL:videoRecorderURL];
    if (!videoRecorderBundle) {
        NSLog(@"error: can not load VideoRecorder.bundle");
        return nil;
    }
    
    return videoRecorderBundle;
}

+ (NSBundle *)stringBundle {
    NSBundle *modleBundle = [self modleNSBundle];
    if (!modleBundle) {
        NSLog(@"error: can not find ChatUIKitBundle");
        return nil;
    }
    
    NSURL *videoRecorderLocalizableURL = [modleBundle URLForResource:@"VideoRecorderLocalizable"
                                            withExtension:@"bundle"];
    
    if (!videoRecorderLocalizableURL) {
        NSLog(@"error: can not find VideoRecorderLocalizable.bundle");
        return nil;
    }
    
    NSBundle *videoRecorderLocalizableBundle = [NSBundle bundleWithURL:videoRecorderLocalizableURL];
    if (!videoRecorderLocalizableBundle) {
        NSLog(@"error: can not load VideoRecorderLocalizable.bundle");
        return nil;
    }
        
    return videoRecorderLocalizableBundle;
}

+ (NSBundle *)modleNSBundle {
    NSBundle *mainBundle = [NSBundle bundleForClass:[self class]];
    NSURL *atomicBundleURL = [mainBundle URLForResource:@"ChatUIKitBundle" withExtension:@"bundle"];
    if (!atomicBundleURL) {
        return nil;
    }
    NSBundle *atomicBundle = [NSBundle bundleWithURL:atomicBundleURL];
    return atomicBundle;
}

+ (UIImage *)bundleImageByName:(NSString *)name {
    if (self.modleNSBundle == nil) {
        return nil;
    }
    return [UIImage imageNamed:name inBundle:self.modleNSBundle compatibleWithTraitCollection:nil];
}

+ (UIImage *)bundleRawImageByName:(NSString *)name {
    if (self.assetsBundle == nil) {
        return nil;
    }
    NSString *path = [NSString stringWithFormat:@"%@/%@", [self assetsBundle].resourcePath, name];
    return [UIImage imageWithContentsOfFile:path];
}

+ (NSString *)localizedStringForKey:(NSString *)key {
    NSString *lang = [self getPreferredLanguage];
    NSString *path = [self.stringBundle pathForResource:lang ofType:@"lproj"];
    if (path == nil) {
        path = [self.stringBundle pathForResource:@"en" ofType:@"lproj"];
    }
    NSBundle *langBundle = [NSBundle bundleWithPath:path];
    NSString *value = [langBundle localizedStringForKey:key value:nil table:nil];
    return value ?: key;
}

+ (UIColor *)colorFromHex:(NSString *)hex {
    return [VideoRecorderCommon tui_colorWithHex:hex];
}

+ (NSArray<NSString *> *)sortedBundleResourcesIn:(NSString *)directory withExtension:(NSString *)ext {
    if (VideoRecorderCommon.assetsBundle == nil) {
        return nil;
    }
    
    NSArray<NSString *> *res = [VideoRecorderCommon.assetsBundle pathsForResourcesOfType:ext inDirectory:directory];
    NSString *basePath = VideoRecorderCommon.assetsBundle.resourcePath;
    res = [res video_recorder_map:^NSString *(NSString *path) {
      return [path substringFromIndex:basePath.length + 1];
    }];
    return [res sortedArrayUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
      return [a compare:b];
    }];
}

+ (NSURL *)getURLByResourcePath:(NSString *)path {
    if (path == nil || VideoRecorderCommon.assetsBundle == nil) {
        return nil;
    }
    
    if (![path hasPrefix:BundleResourceUrlPrefix]) {
        NSURL *url = [NSURL URLWithString:path];
        if (url.scheme == nil) {
            return [NSURL fileURLWithPath:path];
        }
        return url;
    }
    NSURL *bundleUrl = [VideoRecorderCommon.assetsBundle resourceURL];
    NSURL *url = [[NSURL alloc] initWithString:[path substringFromIndex:BundleResourceUrlPrefix.length] relativeToURL:bundleUrl];
    return url;
}

+ (UIImage *__nullable)dynamicImage:(NSString *)imageKey defaultImageName:(NSString *)image {
    if (VideoRecorderCommon.modleNSBundle == nil) {
        return nil;
    }
    
    
    return [UIImage imageNamed:image inBundle:VideoRecorderCommon.modleNSBundle compatibleWithTraitCollection:nil];
}

+ (UIColor *)dynamicColor:(NSString *)colorKey  defaultColor:(NSString *)hex {
    return [VideoRecorderCommon tui_colorWithHex:hex];
}

+ (UIColor *)tui_colorWithHex:(NSString *)hex {
    if ([hex isEqualToString:@""]) {
        return [UIColor clearColor];
    }

    // Remove `#` and `0x`
    if ([hex hasPrefix:@"#"]) {
        hex = [hex substringFromIndex:1];
    } else if ([hex hasPrefix:@"0x"]) {
        hex = [hex substringFromIndex:2];
    }

    // Invalid if not 3, 6, or 8 characters
    NSUInteger length = [hex length];
    if (length != 3 && length != 6 && length != 8) {
        return [[UIColor alloc] init];
    }

    // Make the string 8 characters long for easier parsing
    if (length == 3) {
        NSString *r = [hex substringWithRange:NSMakeRange(0, 1)];
        NSString *g = [hex substringWithRange:NSMakeRange(1, 1)];
        NSString *b = [hex substringWithRange:NSMakeRange(2, 1)];
        hex = [NSString stringWithFormat:@"%@%@%@%@%@%@ff", r, r, g, g, b, b];
    } else if (length == 6) {
        hex = [hex stringByAppendingString:@"ff"];
    }

    CGFloat red = [[hex substringWithRange:NSMakeRange(0, 2)] _hexValue] / 255.0f;
    CGFloat green = [[hex substringWithRange:NSMakeRange(2, 2)] _hexValue] / 255.0f;
    CGFloat blue = [[hex substringWithRange:NSMakeRange(4, 2)] _hexValue] / 255.0f;
    CGFloat alpha = [[hex substringWithRange:NSMakeRange(6, 2)] _hexValue] / 255.0f;

    return [UIColor colorWithRed:red green:green blue:blue alpha:alpha];
}

+ (NSString *)getPreferredLanguage {
    NSString* gCustomLanguage = [NSUserDefaults.standardUserDefaults objectForKey:ChatEngineLanguageKey];
    if (gCustomLanguage != nil && gCustomLanguage.length > 0) {
        return gCustomLanguage;
    }

    // Follow system changes by default
    NSString *language = [NSLocale preferredLanguages].firstObject;
    if ([language hasPrefix:@"en"]) {
        language = @"en";
    } else if ([language hasPrefix:@"zh"]) {
        if ([language rangeOfString:@"Hans"].location != NSNotFound) {
            // Simplified Chinese
            language = @"zh-Hans";
        } else {
            // Traditional Chinese
            language = @"zh-Hant";
        }
    } else if ([language hasPrefix:@"ar"]) {
        language = @"ar";
    }
    else {
        language = @"en";
    }

    return language;
}

@end
