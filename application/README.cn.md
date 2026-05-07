# RTCube

[English](README.md) | 简体中文

## 概述

RTCube 是一款功能强大的 UI 组件库，它基于腾讯云 `AtomicXCore` SDK 构建。`AtomicXCore` 整合了腾讯云实时音视频（TRTC）、即时通信（IM）、音视频通话（TUICallEngine） 和房间管理（TUIRoomEngine） 的核心能力，提供了状态驱动的（State-driven）API 设计。

RTCube 在 `AtomicXCore` 提供的核心能力之上，为您提供了一套预制的用户界面（UI），使您无需关心复杂的后端逻辑和状态管理，即可快速为您的 iOS 应用集成视频互动直播、语音聊天室、音视频通话等功能。

## 功能特性

RTCube 基于 `AtomicXCore` 提供了以下核心业务场景的完整 UI 实现：

  * **视频/语音直播 (Live Streaming):**

      * **直播列表管理:** 拉取直播列表。
      * **开播与观看:** 创建直播间、加入直播。
      * **麦位管理:** 支持麦位管理，观众上麦/下麦。
      * **主播连麦 (Co-hosting):** 支持主播与主播（跨房）连麦。
      * **主播 PK (Battle):** 支持主播间 PK 互动。
      * **互动功能:**
          * **礼物:** 支持发送和接收礼物。
          * **点赞:** 支持直播间点赞。
          * **弹幕:** 支持发送和接收弹幕消息。

  * **音视频通话 (Calling):**

      * **基础通话:** 支持 1v1 及多人音视频通话。
      * **通话管理:** 支持接听、拒绝、挂断。
      * **设备管理:** 支持通话中的摄像头和麦克风控制。
      * **通话记录:** 支持查询和删除通话记录。

  * **多人会议 (Room):**

      * **快速会议:** 支持一键创建/加入多人会议。
      * **邀请入会:** 支持邀请成员加入当前会议。
      * **会中管控:** 支持主持人对成员的音视频、麦位、成员列表进行管理。
      * **共享屏幕:** 支持会中屏幕共享。

## 快速开始

### 1. 环境准备

  * Xcode 14.0 或更高版本
  * iOS 14.0 或更高版本
  * CocoaPods（请确保已安装）

### 2. 克隆仓库

```bash
git clone https://github.com/Tencent-RTC/TUIKit_iOS.git
```

### 3. 安装依赖

`RTCube` 依赖 `TUILiveKit`、`TUICallKit`、`TUIRoomKit` 等多个组件库。您需要使用 CocoaPods 来安装这些依赖。

```bash
cd TUIKit_iOS/application
pod install
```

### 4. 运行项目

使用 Xcode 打开生成的 `RTCube.xcworkspace` 文件，在 `application/Debug/GenerateTestUserSig.swift` 中配置您的腾讯云 `SDKAPPID`、`UserID` 和 `UserSig`，然后编译并运行 `RTCubeLab` scheme。

## 架构

`RTCube` 的架构设计遵循分层原则：

1.  **TUILiveKit / TUICallKit / TUIRoomKit (UI 层):**

      * 提供预制的、可复用的 UI 组件。
      * 负责视图（View）的展示和用户交互。
      * 订阅 `AtomicXCore` 中的 `Store` 来获取状态并更新 UI。
      * 调用 `AtomicXCore` 中的 `Store` 方法来响应用户操作。

2.  **AtomicXCore (核心层):**

      * **Stores:** (如 `LiveListStore`, `CallListStore`, `ConversationListStore`) 负责管理业务逻辑和状态（State）。
      * **Core Views:** (如 `LiveCoreView`, `ParticipantView`) 提供了驱动视频渲染的无 UI 视图容器。
      * **Engine 封装:** 封装了底层的 `RTCRoomEngine`, `TUICallEngine` 和 `IMSDK`，提供统一的 API。

3.  **Tencent Cloud SDK (引擎层):**

      * `RTCRoomEngine` & `TUICallEngine`: 提供底层的实时音视频能力。
      * `IMSDK`: 提供即时通讯能力。

## 文档

* [AtomicXCore 文档](https://tencent-rtc.github.io/TUIKit_iOS/documentation/atomicxcore)
* [官方文档 - 快速集成指南](https://cloud.tencent.com/document/product/647/106536)

## 许可证

本项目遵循 [MIT 许可证](https://www.google.com/search?q=LICENSE)。

-----
