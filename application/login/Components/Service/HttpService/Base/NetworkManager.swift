//
//  NetworkManager.swift
//  login
//
//  从 BusinessService 复制的基础网络请求封装
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

    /// 发起网络请求
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
        // 请求出口日志：所有走 NetworkManager 的 HTTP 都会被记录到 clog，便于排查
        // "Debug 登录路径理论上不发 HTTP，但 toast 里出现了 (204) token required"这类问题。
        // 关键字段：URL、tokenEmpty、userIdEmpty——可定位到任何不该走 HTTP 的路径。
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
                // 响应日志：errorCode != 0 时打印完整 url + code + message
                if result.errorCode != 0 {
                    LoginLogger.Login.warn(
                        "NetworkManager.response url=\(urlString) errorCode=\(result.errorCode) errorMessage=\(result.errorMessage)"
                    )
                }
                completionHandler?(result)
            }
    }

    /// 根据 Alamofire 响应判断网络层错误，返回用户友好的默认错误消息
    private static func resolveDefaultErrorMessage(from response: AFDataResponse<Any>) -> String {
        guard let afError = response.error else {
            return LoginLocalize("login_home_sys_error")
        }

        // 判断是否为网络连接类错误（断网、DNS 解析失败、连接被拒等）
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

        // 其他 AFError（如 SSL、编码等），统一按网络错误处理
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

// 为了调试方便，拦截打印了 url 和请求参数
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
