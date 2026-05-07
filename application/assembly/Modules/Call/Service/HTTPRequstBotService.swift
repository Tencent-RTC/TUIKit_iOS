//
//  HTTPRequstBotService.swift
//  main
//

import UIKit
import Alamofire
import TUICore
import Login

class HTTPRequstBotService: NSObject {

    private var parameters: Dictionary<String, String?> = {
        let parameters = ["userId": LoginManager.shared.getCurrentUser()?.userId,
                          "token": LoginManager.shared.getCurrentUser()?.token,
                          "apaasAppId": LoginManager.shared.getCurrentUser()?.apaasAppId]
        return parameters
    }()

    private static var baseUrl: String {
        return LoginEntry.shared.config.httpBaseUrl
    }

    static func requestWattingCall(success: @escaping () -> Void,
                                   failed: @escaping (_ message: String) -> Void)
    {
        let waittingCallURL = baseUrl + "base/v1/virtual_call/waiting_caller"
        let botService = HTTPRequstBotService()
        if let language = TUIGlobalization.getPreferredLanguage() {
            if !language.contains("zh") {
                botService.parameters.updateValue("en", forKey: "lang")
            }
        }
        if let jsonData = try? JSONSerialization.data(withJSONObject: botService.parameters, options: []),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            printClog("[AppCall][requestWattingCall] resultJson\(jsonString)")
        } else {
            print("Failed to convert dictionary to JSON.")
        }
        AF.request(waittingCallURL,
                   method: .post,
                   parameters: botService.parameters as Parameters,
                   encoding: JSONEncoding.default).responseData
        { response in
            switch response.result {
            case .success(let data):
                do {
                    let json = try JSONSerialization.jsonObject(with: data, options: [])
                    if let jsonObject = json as? [String: Any] {
                        printClog("[AppCall][requestWattingCall] resultJson\(jsonObject)")
                        success()
                    } else {
                        failed("invalid json")
                    }
                } catch let error {
                    failed("json err: \(error)")
                }
            case .failure(let error):
                failed("request failed: \(error)")
            }
        }
    }

    static func requestInitCallBot(success: @escaping (_ botListData: [String: Any]) -> Void,
                                   failed: @escaping (_ message: String) -> Void)
    {
        let botService = HTTPRequstBotService()
        let botQueryUrl = baseUrl + "base/v1/auth_users/virtual_users_query"
        if let jsonData = try? JSONSerialization.data(withJSONObject: botService.parameters, options: []),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            printClog("[AppCall][requestInitCallBot] resultJson\(jsonString)")
        } else {
            print("Failed to convert dictionary to JSON.")
        }
        AF.request(botQueryUrl, method: .post,
                   parameters: botService.parameters as Parameters,
                   encoding: JSONEncoding.default).responseData
        { response in
            switch response.result {
            case .success(let data):
                do {
                    let json = try JSONSerialization.jsonObject(with: data, options: [])

                    if let jsonObject = json as? [String: Any] {
                        printClog("[AppCall][requestInitCallBot] resultJson\(jsonObject)")
                        success(jsonObject)
                    } else {
                        failed("invalid json")
                    }
                } catch let error {
                    failed("json err: \(error)")
                }
            case .failure(let error):
                failed("request failed: \(error)")
            }
        }
    }
}

extension HTTPRequstBotService {
    static func printClog(_ log: String) {
        debugPrint(log)
//        TRTCCloud.sharedInstance().apiLog(log)
    }
}
