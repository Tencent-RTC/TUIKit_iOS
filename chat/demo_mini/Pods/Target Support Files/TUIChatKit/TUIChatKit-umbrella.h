#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "AudioRecordSignatureChecker.h"
#import "VideoRecorderCommon.h"
#import "VideoRecorderImageUtil.h"
#import "VideoRecorderNSArray+Functional.h"
#import "ReflectUtil.h"
#import "SystemVideoRecordCore.h"
#import "UGCReflectVideoRecordCore.h"
#import "VideoRecordCore.h"
#import "VideoRecorderBeautyManager.h"
#import "VideoRecorderConfigInternal.h"
#import "VideoRecorderEncodeConfig.h"
#import "VideoRecorderReflectUtil.h"
#import "VideoRecorderTypeDef.h"
#import "VideoRecordSignatureChecker.h"
#import "VideoRecorderCircleProgressView.h"
#import "VideoRecorderIconLabelButtonView.h"
#import "VideoRecorderRecordButtonView.h"
#import "VideoRecorderSplitterView.h"
#import "VideoRecorderTabPanelView.h"
#import "VideoRecorderBeautifyEffectItem.h"
#import "VideoRecorderBeautifyEffectPanelView.h"
#import "VideoRecorderBeautifyEffectViewCell.h"
#import "VideoRecorderBeautifySettings.h"
#import "VideoRecorderBeautifyView.h"
#import "VideoRecorderAuthorizationPrompterController.h"
#import "VideoRecorderController.h"
#import "VideoRecorderControlView.h"
#import "VideoRecorderPreviewView.h"

FOUNDATION_EXPORT double TUIChatKitVersionNumber;
FOUNDATION_EXPORT const unsigned char TUIChatKitVersionString[];

