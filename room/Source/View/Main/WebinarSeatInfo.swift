//
//  WebinarSeatInfo.swift
//  TUIRoomKit
//
//  Created by adamsfliu on 2026/4/2.
//

import AtomicXCore
import RTCRoomEngine

struct WebinarSeatInfo: Equatable {
    var index: Int = 0
    var isLocked: Bool = false
    var participant: RoomParticipant = RoomParticipant()
    var region: WebinarRegionInfo = WebinarRegionInfo()
}

struct WebinarRegionInfo: Equatable {
    var x: Int = 0
    var y: Int = 0
    var w: Int = 0
    var h: Int = 0
    var zOrder: Int = 0
}

struct WebinarCanvas {
    var w: Int = 0
    var h: Int = 0
    var templateID: Int = 201
    var fillMode: Int = 0
}

func convertToWebinarSeatInfo(seatFullInfo: TUISeatFullInfo) -> WebinarSeatInfo {
    var seatUserInfo = RoomParticipant()
    seatUserInfo.userID = seatFullInfo.userId ?? ""
    seatUserInfo.userName = seatFullInfo.userName ?? ""
    seatUserInfo.avatarURL = seatFullInfo.userAvatar ?? ""
    seatUserInfo.microphoneStatus = seatFullInfo.userMicrophoneStatus == .opened ? .on : .off
    seatUserInfo.cameraStatus = seatFullInfo.userCameraStatus == .opened ? .on : .off
    
    let regionInfo = WebinarRegionInfo(x: Int(seatFullInfo.x),
                                       y: Int(seatFullInfo.y),
                                       w: Int(seatFullInfo.width),
                                       h: Int(seatFullInfo.height),
                                       zOrder: Int(seatFullInfo.zorder))
  
    return WebinarSeatInfo(index: seatFullInfo.seatIndex, isLocked: seatFullInfo.isSeatLocked, participant: seatUserInfo, region: regionInfo)
}

func convertJsonToWebinarCanvas(jsonString: String) -> WebinarCanvas {
    var roomCanvas = WebinarCanvas()
      do {
          if let data = jsonString.data(using: .utf8),
             let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
              roomCanvas.h = jsonObject["canvasHeight"] as? Int ?? 0
              roomCanvas.w = jsonObject["canvasWidth"] as? Int ?? 0
              roomCanvas.templateID = jsonObject["templateId"] as? Int ?? 0
              roomCanvas.fillMode = jsonObject["canvasFillMode"] as? Int ?? 0
          }
      } catch {
          RoomKitLog.error("convertJsonToWebinarCanvas failed: \(error)")
      }
      return roomCanvas
}

func convertSeatListToString(_ seatList: [TUISeatFullInfo]) -> String {
    guard !seatList.isEmpty else {
        return "seatList is empty"
    }
    var sb = "seatList:\(seatList.count)\n"
    for seat in seatList {
        sb.append(seat.printString())
        sb.append("\n")
    }
    return sb
}

extension TUISeatFullInfo {
    func printString() -> String {
        var result = "SeatFullInfo {"
        result += "  roomId: \(roomId)"
        result += "  seatIndex: \(seatIndex)"
        result += "  isSeatLocked: \(isSeatLocked)"
        result += "  userId: \(userId ?? "")"
        result += "  userName: \(userName ?? "")"
        result += "  userAvatar: \(userAvatar ?? "")"
        result += "  userMicrophoneStatus: \(userMicrophoneStatus)"
        result += "  userCameraStatus: \(userCameraStatus)"
        result += "  userSuspendStatus: \(userSuspendStatus)"
        result += "  x: \(x)"
        result += "  y: \(y)"
        result += "  width: \(width)"
        result += "  height: \(height)"
        result += "  zorder: \(zorder)"
        result += "}"
        return result
    }
}


