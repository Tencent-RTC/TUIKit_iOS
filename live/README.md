# TUILiveKit for iOS

UIKit live streaming components backed directly by AtomicXCore.

## Requirements

- iOS 14+
- Swift 5
- AtomicXCore 5.2.0 (or a compatible local source build)
- Host app must declare the `audio` background mode (`UIBackgroundModes` → `audio`, i.e. Target → Signing & Capabilities → Background Modes → Audio, AirPlay, and Picture in Picture). Without it iOS suspends the app and its audio session when the app leaves the foreground, so the audience stops hearing the room even though the component never stops playback. This applies to plain viewing and to being on a CoGuest seat; while on a seat the component still mutes the local microphone on background and restores it on foreground, which is independent of the downlink.

## Public entry points

```swift
let listView = LiveListView(liveID: "live_001")
let pusherView = PusherView(liveID: "live_001")
listView.onClose = {
    // Pop or dismiss the audience view controller.
}
pusherView.onExit = {
    // Pop or dismiss the host view controller.
}
```

`LiveListView` is the public audience entry: a vertical paging feed container aligned with the Android `livelistview`. Each feed cell renders a single live room through the internal `PlayerView`, aligned with the Android `playerview`. The two-column grid selection list lives in the `LiveKitAccess` access app, not in the component library.

LiveList and Pusher have their first AtomicXCore call chains connected. LiveList and Player share a cancellable, memory-cached image loader for live covers and avatars. The iOS access app is located in `LiveKitAccess`, matching the Android directory semantics while following iOS naming conventions.

Pusher provides the local UI flow Prepare (including its internal 3 / 2 / 1 Countdown) → Living → Summary. Entering Pusher requests camera and microphone access and opens local devices through `DeviceStore`. Countdown completion advances the UI to Living and calls `AtomicPusher.startPush`. If the start request fails before the first successful connection, Pusher returns to Prepare, shows the error, and retains the title draft, cover, settings, and existing preview without stopping or releasing the SDK again. Errors after a successful connection do not trigger this rollback. Empty live IDs or IDs exceeding 48 UTF-8 bytes stay in Prepare with an error. Ending calls `AtomicPusher.stopPush`, waits for `liveEnded`, then displays Summary and cleans up. Safe retries while an old SDK destroy request is still pending require the [SDK session isolation fix](../../../docs/live/ATOMIC_PUSHER_START_FAILURE_SDK_FIX.md).

The root view binds `AtomicLiveView` to `AtomicPusher.shared`. Push statistics come from `PusherState`; audio sample rate still comes from `LiveSeatStore`. Once connected, the host sets application-based seating and applies the selected CoGuest layout. Server endings and kick events stop local activity and display a localized reason in Summary; repeated or late events cannot settle the same session twice. Summary reads the current session’s `AtomicPusher.liveEnded.summary`. After a local stop, the event subscription stays active until final statistics arrive or the view exits. Missing statistics display `--`; local time is not used as a fallback.

Account kick notifications also end an active host session. The access app defers its login navigation while the host reads Summary and returns to login through the existing `onExit` callback. Other host apps should coordinate their account navigation similarly. A kick during Prepare exits through `onExit` immediately.

In Prepare, tapping the cover opens a built-in picker for five fixed network covers (`live_cover1.png` through `live_cover5.png`). The selected URL is kept for the current `PusherView` instance and supplied as both `PusherInfo.coverURL` and `PusherInfo.backgroundURL` when starting the live stream. This flow does not access the photo library, upload media, persist a selection, or require host configuration.

The Living CoGuest panel subscribes to AtomicXCore `CoGuestStore` and supports seat-layout updates, accepting applications, inviting or cancelling invitations, ending an audience connection, and rendering CoGuest seats through `AtomicLiveViewChangeAdapter` creation/update callbacks.

The Pusher audience list and its management drawer live under `Pusher/Living/Audience`. `PusherLivingView` owns the room-scoped audience feature store, so viewer state, entry events, refresh, IM follow/unfollow, AtomicXCore comment mute/unmute, and removal stay inside the Living feature instead of passing through the root Pusher state. These are Pusher-only capabilities; Player keeps its separate audience list implementation.

Pusher Living also receives gifts from AtomicXCore `GiftStore`. Every gift immediately displays a two-channel normal entry keyed by sender ID and gift ID. `iconURL` supplies the gift image; supported `.svga` and `.mp4` values in `resourceURL` additionally play through one serial effect channel. SVGA and packed Alpha MP4 share a canvas filling the gift overlay; the Kit preserves AspectFit for SVGA and AspectFill with right-side Alpha for MP4. Player and Pusher share `GiftBarrageStore`, which settles one local `LiveGiftBarrage` per sender-and-gift combo two seconds after the last event. Each Living host forwards it to `BarrageUIStore` for the comment timeline. Pending combos are discarded on pause, clean screen, backgrounding or leaving; restoring collection only accepts new events. Gift barrages are never encoded or sent as custom messages. The live status panel and Summary use SDK statistics; no separate gift statistics are accumulated in the UI. Pusher does not expose a gift-sending panel.

Gift internals are grouped by responsibility under `Common/Gift`: `Send` contains `GiftSendPanelView` (the single public sending component), the gift grid and the send-combo button. The panel owns the catalog subscription, refresh, sending, floating combo and session generation; hosts only call `present(liveID:receiverID:)` / `dismiss()` and may consume `onPresentationChanged` for comment avoidance. Sending no longer reserves a local gift display item: presentation relies on the SDK receipt event. The catalog loads on first presentation, so a loading state can appear. `Display` contains `GiftDisplayView`, `GiftNoticeView` for gift receipt notices, and `GiftAnimationView` for queued SVGA/MP4 playback. `GiftBarrageStore` remains at the Gift root. These internal names and file moves do not change host APIs or gift behavior. See [gift file responsibilities](../CODE_MAP.md#礼物) for the complete map.

The active Player feed item joins its live room and leaves it when switching items or leaving the screen. It provides the first complete audience flow skeleton: vertical paging between live rooms, comments, gifts, likes, audience count, a More entry, interactive right-swipe clean screen with left-swipe restore, and `onClose` for returning to the host list. Comment, gift, like, and audience data use AtomicXCore stores; the current skeleton intentionally does not claim final Ardot visual parity. Its CoGuest flow supports voice/video applications, cancelling an application, accepting or rejecting a host invitation, microphone and camera control, collapsing the control bar, disconnecting, and cleanup after kicks or live-room termination. The next feed item is muted-preloaded through the playback layer; a product Preview page is not implemented yet.

The current Prepare and Countdown visuals follow the structured nodes in the Ardot file “LiveKit视觉交互”. Countdown is an internal Prepare subflow, so its visual component lives under `Pusher/Prepare`; the other Pusher-specific phase views live under `Pusher/Living` and `Pusher/Summary`, while the cross-phase video layer lives under `Pusher/Video`. Content shared by the Prepare and Living "more" drawers lives under `Pusher/Settings`. Directory names must match what they actually hold, so capabilities with a single owner normally stay in the owner's directory; `Common/Gift/Send` is the explicit temporary exception described above. Bottom drawers using `Common/Theme/BottomSheetView` share its dimming layer, sheet background, height constraint and slide animations; the gift-sending panel retains its existing presentation implementation.

## Optional MP4 plugin (SwiftPM)

TUILiveKit and TCGiftPlayerKit do not depend on TCEffectPlayerKit. Apps that need transparent MP4 gifts explicitly add and link the `TCEffectPlayerKit` product, keep `$(inherited) -ObjC` in Other Linker Flags for Debug and Release, and configure the license. The plugin registers automatically through Objective-C `+load`; AppDelegate needs no plugin import or registration call. See [Gift Kit integration](../TCGiftPlayerKit/README.md#swiftpm). Without the plugin, MP4 effects do not play and Live advances to the next queued gift; SVGA and gift receipt notices remain available. The sample apps explicitly integrate the plugin.

## Local CocoaPods integration

```ruby
pod 'AtomicXCore', '5.2.0'
pod 'TEBeautyKit/S1-07', :podspec => 'https://mediacloud-76607.gzc.vod.tencent-cloud.com/TencentEffect/iOS/TEBeautyKit/4.2.0.21/TEBeautyKit.podspec'
pod 'TEBeautyKitWrapper', :path => '/path/to/atomic_uikit/ios/TEBeautyKit'
pod 'TCGiftPlayerKit/Beauty', :path => '/path/to/atomic_uikit/ios/live/TCGiftPlayerKit'
pod 'TCEffectPlayerKit/Beauty', :path => '/path/to/atomic_uikit/ios/TCEffectPlayerKit'
pod 'TCMediaX', :podspec => 'https://mediacloud-76607.gzc.vod.tencent-cloud.com/MediaX/iOS/podspec/release/3.3/3.3.256/TCMediaX.podspec'
pod 'TCEffectPlayer', :podspec => 'https://mediacloud-76607.gzc.vod.tencent-cloud.com/MediaX/iOS/podspec/release/3.3/3.3.256/TCEffectPlayer.podspec'
pod 'TUILiveKit', :path => '/path/to/atomic_uikit/ios/live/TUILiveKit'
```

`TCGiftPlayerKit` lives under `ios/live/TCGiftPlayerKit`, alongside `TUILiveKit` and `LiveKitAccess`, because it serves the Live product. `TUILiveKit` depends on `TCGiftPlayerKit/Core` and calls one typed gift player for both formats. Select one integration:

- `TCGiftPlayerKit/Beauty` (shown above for CocoaPods hosts): SVGA plus MP4 through `TCEffectPlayerKit/Beauty`, with `TEBeautyKit/S1-07` 4.2.0.21 and `TEBeautyKitWrapper`. TencentEffect supplies the license framework; do not also install the standalone `YTCommonXMagic` Pod or the Default subspec. The wrapper remains at `ios/TEBeautyKit`.
- `TCGiftPlayerKit/Default`: SVGA plus MP4 through `TCEffectPlayerKit/Default` for hosts without the advanced beauty SDK. Select Default for both player Kit Pods, omit both beauty Pods and specify the standalone MediaX `YTCommonXMagic` 1.3.1 podspec: `https://mediacloud-76607.gzc.vod.tencent-cloud.com/MediaX/iOS/podspec/release/YTCommonXMagic_1.3.1/YTCommonXMagic.podspec`. The public package with the same name lacks the required `TELicenseCheck` symbol. Never select both Default and Beauty.
- `TCGiftPlayerKit/Core`: SVGA only, without the MP4 SDK or its license package. MP4 playback reports failure and Live continues to the next gift.

`TCEffectPlayerKit` retains its independent MP4 SDK adapter and TUICore services under `ios/TCEffectPlayerKit`; it does not depend on the Gift Kit. `TCGiftPlayerKit` delegates MP4 playback to those services. With local Pods, declare both Kit paths and match their Default or Beauty subspecs, as shown above. Core-only integrations omit `TCEffectPlayerKit` and the MP4 SDK/license Pods.

Initialize the selected beauty and gift-player integrations in the host before playback; keep credentials in the host application:

```swift
import TCGiftPlayerKit
import TEBeautyKitWrapper // Only for the Beauty combination.

TUIBeautyKit.initialize(licenseUrl: effectLicenseURL, licenseKey: effectLicenseKey)
TCGiftPlayer.configureLicense(url: effectLicenseURL, key: effectLicenseKey)
```

The same `giftPlayer.play` / `stop` interface handles SVGA and MP4. Preparation, download caching, format selection and MP4 authorization retries are internal to the Kit; Live owns gift order, next-item prefetch and its 30-second preparation/playback deadlines. There is no pause/resume API. Host-live pause, clean screen, backgrounding and leaving the room stop the current effect and discard pending effects; restoring presentation does not resume old animations. See the [Kit API](../TCGiftPlayerKit/README.md) for direct use and cancellable prefetch.

The access app retries `TUIBeautyKit.initialize` and `TCGiftPlayer.configureLicense` when networking becomes available. Hosts choosing Default or Core without beauty omit the wrapper import and initialization. `TEBeautyKitWrapper` supplies the SDK panel and frame-processing services. Live uses `TRTCCloud.sharedInstance()` internally for camera preprocessing while AtomicXCore retains camera and streaming ownership. Advanced beauty uses the existing beauty entry points and falls back to BaseBeautyStore when authorization, resources, or callback registration are unavailable. Closing the panel retains effects; settings are stored per sdkAppID/userID. The SDK comparison button is hidden because it would also change outgoing video. See [advanced beauty integration](../../TEBeautyKit/README.md) for automatic SwiftPM dependency resolution and required main-bundle resources.

SVGA uses the Kit’s Swift + Metal renderer; CocoaPods builds read shaders from `TCGiftPlayerKitBundle`, while the SwiftPM `binaryTarget` embeds them in the binary. No SVGAPlayer Pod is required. It supports SVGA 2.x bitmap animation and matte masks, but not SVGA 1.x JSON, embedded audio, vector shapes or clipPath.

The host application must provide camera and microphone usage descriptions and complete AtomicXCore login before creating live components. `LiveKitAccess` uses the same local `GenerateTestUserSig` pattern as the Android access app and automatically logs in with locally filled debug values. Client-side SECRETKEY is for SDK smoke testing only and must not be shipped in production.

## Localization

TUILiveKit currently provides English and Simplified Chinese in its own `TUILiveKitBundle`. Component text follows the system language or the per-app language selected in iOS Settings; the host application does not need to copy TUILiveKit strings into `Bundle.main`. Unsupported languages fall back to the bundle's English development localization. Runtime language switching is not part of the current public API.

### Override component text

Add `TUILiveKitLocalized.strings` to the host **App target**, localized in directories such as `en.lproj` and `zh-Hans.lproj`. Ensure the file is included in the App's resources. Only include keys you want to replace; existing keys are listed in [English resources](Resources/en.lproj/Localizable.strings) and [Simplified Chinese resources](Resources/zh-Hans.lproj/Localizable.strings).

For example, `en.lproj/TUILiveKitLocalized.strings` can contain:

```strings
"tuilivekit.player.coguest.apply" = "Request to join";
"tuilivekit.player.coguest.voice" = "Join with audio";
"tuilivekit.player.coguest.video" = "Join with video";
```

For each key, TUILiveKit first reads the host App's `TUILiveKitLocalized` table using iOS Bundle localization rules. If that table does not resolve the key, it falls back to the component's `Localizable` table, then to the key itself. An explicitly empty string is a valid override. Without an override file, built-in text remains unchanged. Configure the override file for the languages supported by your App; language selection and language fallback follow each bundle's standard rules.

`localizedFormat` uses the same lookup. Preserve the number and types of format arguments such as `%@` and `%ld` in replacement text. Overrides apply to component text routed through `LiveKitResources`; SDK-provided gift names and error messages are outside this mechanism. No initialization call or Pod resource edits are needed. This does not add runtime language switching or refresh text already displayed on screen.

Gift catalog names still come from AtomicXCore. The internal `LiveKitResources.giftLanguageCode` centralizes the existing App-language mapping to `zh-Hans`, `zh-Hant` or `en` for gift sending, display and barrage subscriptions; this does not add translated gift-name resources or a host configuration API.

See `../CODE_MAP.md` for the current directory map, entry call chains, state ownership, and unfinished boundaries.

The Pusher simulation console and `isDebugSimulationEnabled` extension have been removed. Remove that configuration from host applications.

## Unified Toast

All iOS component and `LiveKitAccess` Toast messages use the same window-centered presentation:

```swift
import TUILiveKit

LiveToast.show("提示文案")
LiveToast.show("需要更长时间阅读的提示", duration: 3)
```

The method accepts calls from any thread and performs UIKit work on the main queue. It uses the sole foreground-active scene's visible normal key window, centers the brand-blue Toast, wraps long text within safe-area margins, replaces the existing Toast in that window, and dismisses it after two seconds by default. Empty text is ignored; invalid durations fall back to two seconds. The Toast does not intercept touches and is removed when its scene becomes inactive. No window or an ambiguous foreground scene causes the message to be discarded rather than queued for another page.

Multi-window hosts should explicitly select their scene with `LiveToast.show("提示", in: windowScene)`. This argument selects a scene, never a layout container. Business code remains responsible for ignoring stale callbacks. If a message must disappear when its originating flow ends, retain the optional presentation handle and call `dismiss()`; this only removes that presentation and cannot remove a newer replacement:

```swift
let toast = LiveToast.show("提示文案")
// When leaving the flow:
toast.dismiss()
```

`LiveToastView` is a private drawing implementation. Callers must not create separate Toast labels, layout constraints, animations, or dismissal timers.
