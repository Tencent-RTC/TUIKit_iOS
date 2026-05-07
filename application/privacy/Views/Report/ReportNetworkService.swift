//
//  ReportNetworkService.swift
//  privacy
//

import Foundation
import Alamofire
import Login

private var reportBaseUrl: String {
    return LoginEntry.shared.config.httpBaseUrl + "base/v1/reports/report_room"
}

enum ReportNetworkService {

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
