# TUIKit_iOS

English | [简体中文](README.cn.md)

## Overview

TUIKit_iOS is a powerful UI component library built on top of Tencent Cloud's `AtomicXCore` SDK. `AtomicXCore` integrates the core capabilities of Tencent Cloud Real-Time Communication (TRTC), Instant Messaging (IM), Audio/Video Calling (TUICallEngine), and Room Management (TUIRoomEngine), providing a state-driven API design.

TUIKit_iOS provides a set of pre-built user interfaces (UI) on top of the core capabilities offered by `AtomicXCore`, enabling you to quickly integrate video live streaming, voice chat rooms, audio/video calling, and other features into your iOS applications without worrying about complex backend logic and state management.

## Features

TUIKit_iOS provides complete UI implementations for the following core business scenarios based on `AtomicXCore`:

* **Video/Voice Live Streaming:**

    * **Live Room Management:** Fetch live room lists.
    * **Broadcasting & Watching:** Create live rooms, join live streams.
    * **Seat Management:** Support seat management, audience mic on/off.
    * **Host Co-hosting:** Support cross-room co-hosting between hosts.
    * **Host PK (Battle):** Support PK interactions between hosts.
    * **Interactive Features:**
        * **Gifts:** Support sending and receiving gifts.
        * **Likes:** Support live room likes.
        * **Barrage:** Support sending and receiving barrage messages.

* **Audio/Video Calling:**

    * **Basic Calling:** Support 1v1 and multi-party audio/video calls.
    * **Call Management:** Support answering, rejecting, and hanging up calls.
    * **Device Management:** Support camera and microphone control during calls.
    * **Call History:** Support querying and deleting call records.

* **Instant Messaging (Chat):**

    * **Conversation Management:** Support fetching and managing conversation lists.
    * **Message Sending/Receiving:** Support C2C (one-to-one) and Group chat scenarios, with multiple message types including text, images, voice, video, etc.
    * **Contact Management:** Support friend and blacklist management.
    * **Group Management:** Support group profile, group member, and group settings management.

## Quick Start

### 1. Environment Setup

* Xcode 14.0 or higher
* iOS 14.0 or higher
* CocoaPods (ensure it's installed)

### 2. Clone Repository

```bash
git clone https://github.com/Tencent-RTC/TUIKit_iOS.git
```

### 3. Install Dependencies

`TUIKit_iOS` depends on `AtomicXCore`, which in turn depends on `RTCRoomEngine`. You need to use CocoaPods to install these dependencies.

```bash
cd TUIKit_iOS/application
pod install
```

### 4. Run Project

Open the generated `.xcworkspace` file with Xcode, configure your Tencent Cloud SDKAppID, UserID, and UserSig (usually configured in the `GenerateTestUserSig` file), then compile and run.

## Architecture

The architecture design of `TUIKit_iOS` follows layered principles:

1. **TUIKit_iOS (UI Layer):**

    * Provides pre-built, reusable UI components.
    * Responsible for view presentation and user interaction.
    * Subscribes to `Store` in `AtomicXCore` to get state and update UI.
    * Calls `Store` methods in `AtomicXCore` to respond to user operations.

2. **AtomicXCore (Core Layer):**

    * **Stores:** (such as `LiveListStore`, `CallListStore`, `ConversationListStore`) responsible for managing business logic and state.
    * **Core Views:** (such as `LiveCoreView`, `ParticipantView`) provide UI-less view containers that drive video rendering.
    * **Engine Wrapper:** Encapsulates underlying `RTCRoomEngine`, `TUICallEngine`, and `IMSDK`, providing unified APIs.

3. **Tencent Cloud SDK (Engine Layer):**

    * `RTCRoomEngine` & `TUICallEngine`: Provide underlying real-time audio/video capabilities.
    * `IMSDK`: Provides instant messaging capabilities.

## Documentation

* [AtomicXCore Documentation](https://tencent-rtc.github.io/TUIKit_iOS/documentation/atomicxcore)
* [Official Documentation - Quick Integration Guide](https://trtc.io/document/60455?product=live&menulabel=uikit&platform=ios)

## License

This project is licensed under the [MIT License](LICENSE).

---

## Project Structure

```
TUIKit_iOS/
├── application/           # Demo application
│   ├── App-UIKit.xcodeproj
│   ├── App-UIKit.xcworkspace
│   └── Podfile
├── atomic_x/             # AtomicX UI components
│   ├── Sources/          # Swift source files
│   └── Resources/        # UI resources
├── call/                 # TUICallKit components
├── chat/                 # Chat UI components
├── conference/           # Conference/Room UI components
├── live/                 # Live streaming components
└── devops/              # Build and deployment scripts
```

## Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details on how to submit pull requests, report issues, and contribute to the project.

### Development Workflow

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes following our [coding standards](docs/CODING_STANDARDS.md)
4. Add tests for your changes
5. Ensure all tests pass
6. Commit your changes (`git commit -m 'Add amazing feature'`)
7. Push to the branch (`git push origin feature/amazing-feature`)
8. Open a Pull Request

## Support

- **Documentation:** [Official Documentation](https://tencent-rtc.github.io/TUIKit_iOS/)
- **API Reference:** [AtomicXCore API](https://tencent-rtc.github.io/TUIKit_iOS/documentation/atomicxcore)
- **Issues:** [GitHub Issues](https://github.com/Tencent-RTC/TUIKit_iOS/issues)
- **Community:** [Tencent Cloud Developer Community](https://cloud.tencent.com/developer)

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for a detailed history of changes to this project.

## Acknowledgments

- Built with [Tencent Cloud TRTC](https://cloud.tencent.com/product/trtc)
- UI framework powered by [SnapKit](https://github.com/SnapKit/SnapKit)
- Image loading by [Kingfisher](https://github.com/onevcat/Kingfisher)
