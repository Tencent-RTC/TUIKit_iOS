//
//  ReportNetworkService.swift
//  privacy
//
//  Report 模块独立的网络请求服务
//  参考 v2 中 InterpretationRequestManager 的实现模式：
//    - LoginEntry.shared.config.httpBaseUrl 获取 baseUrl
//    - LoginManager.shared.getCurrentUser() 获取鉴权信息
//    - Alamofire 发起 POST 请求
//

import Foundation
import Alamofire
import Login

private var reportBaseUrl: String {
    return LoginEntry.shared.config.httpBaseUrl + "base/v1/reports/report_room"
}

/// Report 模块独立的网络请求服务
enum ReportNetworkService {

    /// 举报房间
    /// - Parameters:
    ///   - targetRoomId: 房间 ID
    ///   - ownerId: 房主 userId
    ///   - reason: 举报原因
    ///   - description: 详情描述
    ///   - success: 成功回调（主线程）
    ///   - failed: 失败回调（主线程），参数为 (errorCode, errorMessage)
    static func reportRoom(targetRoomId: String,
                           ownerId: String,
                           reason: String,
                           description: String,
                           success: (() -> Void)?,
                           failed: ((_ errorCode: Int32, _ errorMessage: String) -> Void)?) {

        var params: [String: Any] = [
            "targetRoomId": targetRoomId,
            "targetUserId": ownerId,
            "reason": reason,
            "description": description,
        ]

        // 附加鉴权参数（与 v2 其他模块一致）
        if let userId = LoginManager.shared.getCurrentUser()?.userId {
            params["userId"] = userId
        }
        if let token = LoginManager.shared.getCurrentUser()?.token {
            params["token"] = token
        }
        if let apaasAppId = LoginManager.shared.getCurrentUser()?.apaasAppId {
            params["apaasAppId"] = apaasAppId
        }

        AF.request(reportBaseUrl,
                   method: .post,
                   parameters: params,
                   encoding: JSONEncoding.default)
        .responseData { response in
            switch response.result {
            case .success(let data):
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    DispatchQueue.main.async { failed?(-1, "Invalid JSON response") }
                    return
                }
                let errorCode = json["errorCode"] as? Int32 ?? -1
                let errorMessage = json["errorMessage"] as? String ?? "Unknown error"
                DispatchQueue.main.async {
                    if errorCode == 0 {
                        success?()
                    } else {
                        failed?(errorCode, errorMessage)
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    failed?(-1, error.localizedDescription)
                }
            }
        }
    }
}
