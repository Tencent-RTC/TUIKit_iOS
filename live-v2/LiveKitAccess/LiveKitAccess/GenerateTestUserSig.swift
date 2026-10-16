import CommonCrypto
import Foundation
import zlib

// This helper is for local SDK access testing only. Do not ship SECRETKEY in a production app.
class GenerateTestUserSig {

    /**
     * Tencent Cloud SDKAppID. Set it to the SDKAppID of your account.
     * <p>
     * You can view your `SDKAppId` after creating an application in the [Tencent Cloud IM console](https://console.cloud.tencent.com/avc).
     * SDKAppID uniquely identifies a Tencent Cloud account.
     */
    static let SDKAPPID: Int32 = 0




    /**
     * Signature validity period, which should not be set too short
     * <p>
     * Unit: Second
     * Default value: 604800 (seven days)
     */
    private static let EXPIRETIME: Int64 = 604800

    /**
     * Follow the steps below to obtain the key required for UserSig calculation.
     * <p>
     * Step 1. Log in to the [IM console](https://console.cloud.tencent.com/avc). If you don't have an application yet, create one.
     * Step 2. Click your application and find “Basic Information”.
     * Step 3. Click “Display Key” to view the key used for UserSig calculation.
     * Copy and paste the key to the variable below.
     * <p>
     * Note: This method is for testing only. Before commercial launch,
     * please migrate the UserSig calculation code and key to your backend server
     * to prevent key disclosure and traffic stealing.
     * Documentation: https://cloud.tencent.com/document/product/269/32688#Server
     */
    private static let SECRETKEY = ""

    static let TENCENT_EFFECT_LICENSE_URL = ""
    static let TENCENT_EFFECT_LICENSE_KEY = ""

    class func genTestUserSig(_ userID: String) -> String {
        guard SDKAPPID > 0, !SECRETKEY.isEmpty, !userID.isEmpty else { return "" }

        let currentTime = Int64(Date().timeIntervalSince1970)
        let document: [String: Any] = [
            "TLS.ver": "2.0",
            "TLS.identifier": userID,
            "TLS.sdkappid": SDKAPPID,
            "TLS.expire": EXPIRETIME,
            "TLS.time": currentTime,
            "TLS.sig": hmacSHA256(userID: userID, currentTime: currentTime),
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: document, options: .sortedKeys) else {
            return ""
        }
        return compress(jsonData).map(base64URL) ?? ""
    }

    private class func hmacSHA256(userID: String, currentTime: Int64) -> String {
        let content = """
        TLS.identifier:\(userID)
        TLS.sdkappid:\(SDKAPPID)
        TLS.time:\(currentTime)
        TLS.expire:\(EXPIRETIME)

        """
        guard let keyData = SECRETKEY.data(using: .utf8),
              let contentData = content.data(using: .utf8) else {
            return ""
        }

        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        keyData.withUnsafeBytes { keyBytes in
            contentData.withUnsafeBytes { contentBytes in
                CCHmac(
                    CCHmacAlgorithm(kCCHmacAlgSHA256),
                    keyBytes.baseAddress,
                    keyData.count,
                    contentBytes.baseAddress,
                    contentData.count,
                    &digest
                )
            }
        }
        return Data(digest).base64EncodedString()
    }

    private class func compress(_ data: Data) -> Data? {
        let sourceLength = uLong(data.count)
        var destinationLength = compressBound(sourceLength)
        var destination = [UInt8](repeating: 0, count: Int(destinationLength))

        let result = data.withUnsafeBytes { sourceBytes in
            destination.withUnsafeMutableBytes { destinationBytes in
                compress2(
                    destinationBytes.bindMemory(to: Bytef.self).baseAddress,
                    &destinationLength,
                    sourceBytes.bindMemory(to: Bytef.self).baseAddress,
                    sourceLength,
                    Z_BEST_SPEED
                )
            }
        }
        guard result == Z_OK else { return nil }
        return Data(destination.prefix(Int(destinationLength)))
    }

    private class func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "*")
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "=", with: "_")
    }
}
