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
        let urlString = (try? convertible.asURL().absoluteString) ?? "<invalid-url>"
        let mergedParams = addBaseParametersData(parameters)
        let tokenInParams = (mergedParams?["token"] as? String) ?? ""
        let userIdInParams = (mergedParams?["userId"] as? String) ?? ""
        LoginLogger.Login.info(
            "NetworkManager.request -> url=\(urlString) method=\(method.rawValue) tokenEmpty=\(tokenInParams.isEmpty) userIdEmpty=\(userIdInParams.isEmpty)"
        )

        AF.request(convertible, method: method, parameters: mergedParams, encoding: encoding)
            .nmResponseJSON { data in
                var result: HttpJsonModel = HttpJsonModel()
                result.errorMessage = Self.resolveDefaultErrorMessage(from: data)
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
                if result.errorCode != 0 {
                    LoginLogger.Login.warn(
                        "NetworkManager.response url=\(urlString) errorCode=\(result.errorCode) errorMessage=\(result.errorMessage)"
                    )
                }
                completionHandler?(result)
            }
    }

    private static func resolveDefaultErrorMessage(from response: AFDataResponse<Any>) -> String {
        guard let afError = response.error else {
            return LoginLocalize("login_home_sys_error")
        }

        if let urlError = afError.underlyingError as? URLError {
            switch urlError.code {
            case .timedOut:
                return LoginLocalize("login_error_network_timeout")
            case .notConnectedToInternet,
                 .networkConnectionLost,
                 .cannotFindHost,
                 .cannotConnectToHost,
                 .dnsLookupFailed:
                return LoginLocalize("login_error_network")
            default:
                return LoginLocalize("login_error_network")
            }
        }

        if case .sessionTaskFailed = afError {
            return LoginLocalize("login_error_network")
        }

        return LoginLocalize("login_home_sys_error")
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
