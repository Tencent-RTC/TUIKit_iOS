//
//  NetworkManager.swift
//  login
//

import Alamofire
import Foundation

var appLoginBaseUrl: String {
    return LoginEntry.shared.config.httpBaseUrl + "base/v1/"
}

var apaasAppId: String {
    return LoginEntry.shared.config.apaasAppId
}

class NetworkManager {
    typealias HttpCompletionCallBack = (_ model: HttpJsonModel) -> Void

    static func request(baseUrl: URLConvertible,
                        params: Parameters? = nil,
                        success: ((_ data: HttpJsonModel) -> Void)?,
                        failed: ((_ errorCode: Int32, _ errorMessage: String?) -> Void)?) {
        NetworkManager.request(baseUrl, method: .post,
                               parameters: params,
                               encoding: JSONEncoding.default,
                               completionHandler: { (model: HttpJsonModel) in
            if model.errorCode == 0 {
                success?(model)
            } else {
                failed?(model.errorCode, model.errorMessage)
            }
        })
    }

    static func request(_ convertible: URLConvertible, method: HTTPMethod = .get, parameters:
        Parameters? = nil, completionHandler: HttpCompletionCallBack? = nil) {
        request(convertible, method: method, parameters: parameters, encoding: URLEncoding.default, completionHandler: completionHandler)
    }

    static func request(_ convertible: URLConvertible, method: HTTPMethod = .get, parameters:
        Parameters? = nil, encoding: ParameterEncoding, completionHandler: HttpCompletionCallBack? = nil) {
        AF.request(convertible, method: method, parameters: addBaseParametersData(parameters), encoding: encoding)
            .nmResponseJSON { data in
                var result: HttpJsonModel = HttpJsonModel()
                result.errorMessage = LoginLocalize("Demo.TRTC.http.syserror")
                if let respData = data.data, respData.count > 0 {
                    let value = try? JSONSerialization.jsonObject(with: respData, options: .mutableLeaves)
                    #if DEBUG
                        debugPrint("http_result: " + "\(value ?? "")")
                    #else
                    #endif
                    if let res = value as? [String: Any] {
                        if let jsonMOdel = HttpJsonModel.json(res) {
                            result = jsonMOdel
                        }
                    }
                }
                completionHandler?(result)
            }
    }

    private static func addBaseParametersData(_ parameters: Parameters? = nil) -> Parameters? {
        guard var resultParameters = parameters else {
            return nil
        }
        if let userId = LoginManager.shared.getCurrentUser()?.userId {
            if resultParameters["userId"] == nil {
                resultParameters["userId"] = userId
            }
        }
        if let token = LoginManager.shared.getCurrentUser()?.token {
            if resultParameters["token"] == nil {
                resultParameters["token"] = token
            }
        }
        if let apaasUserId = LoginManager.shared.getCurrentUser()?.apaasUserId, !apaasUserId.isEmpty {
            if resultParameters["apaasUserId"] == nil {
                resultParameters["apaasUserId"] = apaasUserId
            }
        }
        if resultParameters["appId"] == nil {
            resultParameters["appId"] = HttpLogicRequest.sdkAppId
        }
        return resultParameters
    }
}

extension DataRequest {
    @discardableResult
    public func nmResponseJSON(completionHandler: @escaping (AFDataResponse<Any>) -> Void) -> Self {
        responseJSON { data in
            #if DEBUG
                debugPrint("url:\(String(describing: self.convertible.urlRequest))")
                debugPrint("trtcParameters:\(String(describing: self.convertible.trtcParameters()))")
            #else
            #endif
            completionHandler(data)
        }
    }
}

extension URLRequestConvertible {
    func trtcParameters() -> Parameters? {
        let mirror = Mirror(reflecting: self)
        for child in mirror.children where child.label == "parameters" {
            return (child.value as? Parameters)
        }
        return nil
    }
}
