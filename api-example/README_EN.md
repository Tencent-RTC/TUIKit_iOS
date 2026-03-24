# AtomicXCore API Example Demo — iOS

English | [中文](./README.md)

## Introduction

This project is an iOS API example demo for the **AtomicXCore SDK**, showcasing all core functionalities from basic streaming to complex interactive live broadcasting through four progressive stages. Built with Swift using UIKit programmatic layout (SnapKit) and Combine reactive state management, it serves as a reference for developers to quickly understand and integrate the AtomicXCore SDK.

## Feature Overview

| Stage | Module | Description |
|:---:|:---|:---|
| 1 | **BasicStreaming** | Live stream creation/joining, camera/microphone management, video rendering |
| 2 | **Interactive** | Barrage messages, gift system (with SVGA animation), likes, beauty filters, audio effects |
| 3 | **MultiConnect** | Audience co-guest requests, anchor invitations, seat management, multi-user video |
| 4 | **LivePK** | Cross-room connection, PK battles, real-time scoring, battle result display |

> Each stage builds upon the previous one, progressively adding new capabilities.

## Tech Stack

| Category | Technology | Version |
|:---:|:---|:---|
| Language | Swift | 5.0 |
| UI Framework | UIKit (Programmatic Layout) | — |
| Layout Engine | SnapKit | ~> 5.6 |
| State Management | Combine | Built-in |
| Core SDK | AtomicXCore | 4.0.3 |
| RTAV SDK | TXLiteAVSDK_Professional (transitive) | 13.1.20476 |
| IM SDK | TXIMSDK_Plus_iOS_XCFramework (transitive) | 8.9.7511 |
| Image Loading | Kingfisher | ~> 8.0 |
| Animation Engine | SVGAPlayer | 2.5.7 |
| Toast | Toast-Swift | ~> 5.1.1 |
| Pull-to-Refresh | MJRefresh | ~> 3.7 |
| Project Generation | XcodeGen | — |
| Dependency Management | CocoaPods | — |
| Minimum Deployment | iOS 16.0 | — |

## Project Architecture

### Architecture Pattern

The project adopts the **MVC + Store** pattern:

- **Store Pattern**: The AtomicXCore SDK exposes state (Combine Publishers) and action methods through various Store objects (e.g., `LoginStore.shared`, `DeviceStore.shared`, `BarrageStore.create(liveID:)`)
- **ViewController Layer**: Directly interacts with Stores, subscribing to state changes via Combine's `.sink` and updating UI on the main thread
- **Reusable Components**: Shared UI components in the `Components/` directory are used across multiple ViewControllers
- **Event Distribution**: Store event publishers (`xxxEventPublisher`) distribute notifications as Combine Publishers

### Store Types & Lifecycle

| Type | Creation | Description | Examples |
|:---:|:---|:---|:---|
| Global Singleton | `.shared` | Shared across the entire app, lifecycle matches the app | `LoginStore.shared`, `DeviceStore.shared`, `BaseBeautyStore.shared`, `AudioEffectStore.shared` |
| Per-Room Instance | `.create(liveID:)` | Independent instance per live room, created on join, destroyed on leave | `BarrageStore.create(liveID:)`, `GiftStore.create(liveID:)`, `CoGuestStore.create(liveID:)` |

### Directory Structure

```
ios/
├── App/                              # App entry point
│   ├── AppDelegate.swift             # @main entry, global Toast configuration
│   └── SceneDelegate.swift           # Window creation, root view controller setup
├── Scenes/                           # Business scene pages (ViewController layer)
│   ├── Login/
│   │   ├── LoginViewController.swift           # User login page
│   │   └── ProfileSetupViewController.swift    # Profile setup (nickname + avatar)
│   ├── FeatureList/
│   │   └── FeatureListViewController.swift     # Feature list home (4 feature cards)
│   ├── BasicStreaming/
│   │   └── BasicStreamingViewController.swift  # Stage 1: Basic streaming
│   ├── Interactive/
│   │   └── InteractiveViewController.swift     # Stage 2: Interactive features
│   ├── MultiConnect/
│   │   └── MultiConnectViewController.swift    # Stage 3: Audience co-guest
│   └── LivePK/
│       └── LivePKViewController.swift          # Stage 4: Live PK battle
├── Components/                       # Reusable UI components
│   ├── AudioEffectSettingView.swift   # Audio effect settings (voice changer/reverb/in-ear monitoring)
│   ├── BarrageView.swift             # Barrage message list + input
│   ├── BeautySettingView.swift       # Beauty filter settings (smooth/whiteness/ruddy)
│   ├── CoHostUserListView.swift      # Cross-room host connection list
│   ├── DeviceSettingView.swift       # Device management (camera/mic/mirror/quality)
│   ├── GiftAnimationView.swift       # Gift animation display (SVGA fullscreen + slide barrage)
│   ├── GiftPanelView.swift           # Gift selection panel (paged grid + send)
│   ├── LikeButton.swift              # Like button (heart particle effects)
│   ├── LocalizedManager.swift        # Localization manager (Chinese/English switch)
│   ├── Role.swift                    # Role enum (anchor/audience)
│   └── SettingPanelController.swift  # Generic half-screen setting panel container
├── Debug/
│   └── GenerateTestUserSig.swift     # Debug-only UserSig local generator
├── Resources/
│   ├── Info.plist                    # App configuration & permission declarations
│   ├── LaunchScreen.storyboard       # Launch screen
│   ├── Assets.xcassets/              # Icons and image assets
│   ├── zh-Hans.lproj/Localizable.strings  # Chinese localization (232 keys)
│   └── en.lproj/Localizable.strings       # English localization (232 keys)
├── Podfile                           # CocoaPods dependency configuration
├── Podfile.lock                      # Dependency version lock
└── project.yml                       # XcodeGen project configuration
```

### App Flow

```
LaunchScreen.storyboard (Launch screen)
  │
  ▼
SceneDelegate → LoginViewController (Enter UserID → SDK login)
  │
  ├─ No nickname ──→ ProfileSetupViewController (Set nickname + avatar)
  │                       │
  │                       ▼
  └─ Has nickname ──→ FeatureListViewController (4 feature cards)
                          │
                          ├─ Select role (Anchor / Audience) + Room ID
                          │
                          ├──→ BasicStreamingViewController  (Stage 1)
                          ├──→ InteractiveViewController     (Stage 2)
                          ├──→ MultiConnectViewController    (Stage 3)
                          └──→ LivePKViewController          (Stage 4)
```

Navigation details:
- Uses `UINavigationController` for page stack management
- After successful login, `setViewControllers` replaces the entire navigation stack (no back to login)
- All live scene pages disable the swipe-back gesture (`interactivePopGestureRecognizer?.isEnabled = false`)
- Role selection via `UIAlertController` ActionSheet
- Audience room ID input via `UIAlertController` with TextField

## AtomicXCore SDK API Reference

### Stage 1: BasicStreaming

| Store | Key APIs | Function |
|:---|:---|:---|
| `LoginStore` | `login()`, `setSelfInfo()`, `state.loginState` | User login & state management |
| `LiveListStore` | `createLive()`, `joinLive()`, `endLive()`, `leaveLive()` | Live room lifecycle management |
| `DeviceStore` | `openLocalCamera()`, `openLocalMicrophone()`, `switchCamera()` | Local device control |
| `LiveCoreView` | `pushView` / `playView` modes | Video rendering component |

### Stage 2: Interactive

| Store | Key APIs | Function |
|:---|:---|:---|
| `BarrageStore` | `sendTextMessage()`, `state.messageList` | Barrage message send/receive |
| `GiftStore` | `sendGift()`, `refreshUsableGifts()`, `giftEventPublisher` | Gift system |
| `LikeStore` | `sendLike()`, `likeEventPublisher` | Like interaction |
| `BaseBeautyStore` | `setSmoothLevel()`, `setWhitenessLevel()`, `setRuddyLevel()` | Beauty filter adjustment |
| `AudioEffectStore` | `setAudioChangerType()`, `setAudioReverbType()`, `enableInEarMonitoring()` | Audio effect control |

### Stage 3: MultiConnect — Audience Co-Guest

| Store | Key APIs | Function |
|:---|:---|:---|
| `CoGuestStore` | `applyForSeat()`, `inviteToSeat()`, `acceptApplication()` | Co-guest request management |
| `LiveSeatStore` | `openRemoteCamera()`, `openRemoteMicrophone()`, `kickUserOutOfSeat()` | Seat & remote device management |
| `LiveAudienceStore` | `fetchAudienceList()` | Audience list |
| `VideoViewDelegate` | `createCoGuestView(userInfo:)` | Co-guest video overlay delegate |

### Stage 4: LivePK — PK Battle

| Store | Key APIs | Function |
|:---|:---|:---|
| `CoHostStore` | `requestHostConnection()`, `acceptHostConnection()`, `exitHostConnection()` | Cross-room connection management |
| `BattleStore` | `requestBattle()`, `acceptBattle()`, `exitBattle()`, `state.battleScoreMap` | PK battle management & real-time scoring |
| `LiveListStore` | `fetchLiveList()` | Fetch available live rooms for connection |

## Requirements

- **macOS**: Ventura 13.0 or later
- **Xcode**: 15.0 or later
- **CocoaPods**: 1.14.0 or later
- **XcodeGen** (optional): For generating Xcode project from `project.yml`
- **Minimum Deployment Target**: iOS 16.0
- **Supported Devices**: iPhone + iPad

## Quick Start

### 1. Clone the Repository

```bash
git clone <repository-url>
cd atomic-api-example/ios
```

### 2. Install Dependencies

```bash
pod install
```

### 3. Configure SDK Credentials

Edit `Debug/GenerateTestUserSig.swift` and fill in your Tencent Cloud credentials:

```swift
static let SDKAPPID: Int = 0          // Replace with your SDKAPPID
static let SECRETKEY = ""             // Replace with your SECRETKEY
```

> ⚠️ **Security Notice**: `SECRETKEY` is for local debugging only. In production, UserSig must be generated by your backend server. Never embed SECRETKEY in client release builds.

### 4. Open the Project

```bash
open AtomicXCoreExample.xcworkspace
```

> Note: Use `.xcworkspace` instead of `.xcodeproj` to ensure CocoaPods dependencies are properly loaded.

### 5. Build & Run

Select a target device or simulator in Xcode and click Run to build and launch the app.

## Permissions

The app requires the following permissions (declared in `Info.plist`):

| Permission | Purpose |
|:---|:---|
| `NSCameraUsageDescription` | Camera access for live streaming |
| `NSMicrophoneUsageDescription` | Microphone access for live streaming |
| `NSLocalNetworkUsageDescription` | Local network access for live communication |

## Localization

The project supports Chinese/English bilingual switching. Tap the globe icon in the top-right corner of the login page to switch languages:

- `Resources/zh-Hans.lproj/Localizable.strings` — Simplified Chinese
- `Resources/en.lproj/Localizable.strings` — English

Localization is managed through the `LocalizedManager` singleton:
- `String.localized` extension property for convenient localized text access
- Language preference persisted via `UserDefaults`
- Language switch automatically resets `rootViewController` to refresh the entire UI
