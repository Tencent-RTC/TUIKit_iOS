# TUILiveKit iOS Live v2

UIKit live streaming components and a standalone sample app, using the published AtomicXCore 5.2.0 SDK.

- `TUILiveKit/`: reusable component sources, resources and CocoaPods specification (iOS 14+).
- `LiveKitAccess/`: sample app (iOS 15+), login, live selection and host/viewer entry points.

## Run the sample

1. Set `SDKAPPID` and `SECRETKEY` in `LiveKitAccess/LiveKitAccess/GenerateTestUserSig.swift` for local testing. They are empty in this export. Generate UserSig on your backend in production; never publish a populated secret.
2. Set `TENCENT_EFFECT_LICENSE_URL` and `TENCENT_EFFECT_LICENSE_KEY` to enable licensed MP4 gift effects.
3. Install CocoaPods, then run:

```sh
cd LiveKitAccess
pod install
open LiveKitAccess.xcworkspace
```

Select your own signing team and bundle identifier for a device build. Camera and microphone permissions and background audio are declared by the sample.

## Build without signing

```sh
cd LiveKitAccess
xcodebuild -workspace LiveKitAccess.xcworkspace -scheme LiveKitAccess \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

## Embed the component

Use the public dependency declarations from the sample Podfile, including the official MediaX podspec URLs, and point the TUILiveKit path to this component directory. Initialize AtomicXCore login before entering the sample flow. This new module is independent of the repository's legacy `live/` module; do not include both TUILiveKit implementations in one target.

The component exposes `LiveListView(liveID:)` (vertical viewer feed) and `PusherView(liveID:)` (host flow). The sample owns the two-column live selection list. Preserve background audio capability in your host app for background playback.
