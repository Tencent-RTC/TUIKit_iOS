# TUIKit\_iOS

[English](README.md) | 简体中文

## 概述

TUIKit\_iOS 是一款功能强大的 UI 组件库，它基于腾讯云 `AtomicXCore` SDK 构建。`AtomicXCore` 整合了腾讯云实时音视频（TRTC）、即时通信（IM）、音视频通话（TUICallEngine） 和房间管理（TUIRoomEngine） 的核心能力，提供了状态驱动的（State-driven）API 设计。

TUIKit\_iOS 在 `AtomicXCore` 提供的核心能力之上，为您提供了一套预制的用户界面（UI），使您无需关心复杂的后端逻辑和状态管理，即可快速为您的 iOS 应用集成视频互动直播、语音聊天室、音视频通话等功能。

## 功能特性

TUIKit\_iOS 基于 `AtomicXCore` 提供了以下核心业务场景的完整 UI 实现：

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

  * **即时通讯 (Chat):**

      * **会话管理:** 支持会话列表的拉取和管理。
      * **消息收发:** 支持 C2C（单聊） 和 Group（群聊） 场景，支持文本、图片、语音、视频等多种消息类型。
      * **联系人管理:** 支持好友和黑名单管理。
      * **群组管理:** 支持群资料、群成员和群设置管理。

## 快速开始

### 1\. 环境准备

  * Xcode 14.0 或更高版本
  * iOS 14.0 或更高版本
  * CocoaPods（请确保已安装）

### 2\. 克隆仓库

```bash
git clone https://github.com/Tencent-RTC/TUIKit_iOS.git
```

### 3\. 安装依赖

`TUIKit_iOS` 依赖 `AtomicXCore`，而 `AtomicXCore` 依赖于 `RTCRoomEngine`。您需要使用 CocoaPods 来安装这些依赖。

```bash
cd TUIKit_iOS/application
pod install
```

### 4\. 运行项目

使用 Xcode 打开生成的 `.xcworkspace` 文件，配置您的腾讯云 SDKAppID、UserID 和 UserSig（通常在 `GenerateTestUserSig` 文件中配置），然后编译并运行。

## 架构

`TUIKit_iOS` 的架构设计遵循分层原则：

1.  **TUIKit\_iOS (UI 层):**

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
