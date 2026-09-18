import CommonCrypto
import Foundation
import zlib

@objc
public class GenerateTestUserSig: NSObject {
    public static let sdkAppID: Int32 = 0
    public static let secretKey = ""

    @objc
    public class func genTestUserSig(identifier: String) -> String {
        return genTestUserSig(userID: identifier, sdkAppID: Int(sdkAppID), secretKey: secretKey)
    }

    @objc
    public class func genTestUserSig(userID: String, sdkAppID: Int, secretKey: String) -> String {

        let EXPIRETIME = 604_800
        let current = CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970
        let TLSTime = CLong(floor(current))
        var obj: [String: Any] = [
            "TLS.ver": "2.0",
            "TLS.identifier": userID,
            "TLS.sdkappid": sdkAppID,
            "TLS.expire": EXPIRETIME,
            "TLS.time": TLSTime,
        ]
        let keyOrder = [
            "TLS.identifier",
            "TLS.sdkappid",
            "TLS.time",
            "TLS.expire",
        ]
        var stringToSign = ""
        for key in keyOrder {
            if let value = obj[key] {
                stringToSign += "\(key):\(value)\n"
            }
        }
        print("string to sign: \(stringToSign)")
        guard var sig = hmac(plainText: stringToSign, secretKey: secretKey) else {
            print("hmac error: \(stringToSign)")
            return ""
        }
        obj["TLS.sig"] = sig
        print("sig: \(String(describing: sig))")
        guard let jsonData = try? JSONSerialization.data(withJSONObject: obj, options: .sortedKeys) else {
            print("jsonData error: \(obj)")
            return ""
        }
        let srcLen = uLongf(jsonData.count)
        let upperBound: uLong = compressBound(srcLen)
        let capacity = Int(upperBound)
        let dest = UnsafeMutablePointer<Bytef>.allocate(capacity: capacity)
        var destLen = upperBound
        let ret = jsonData.withUnsafeBytes { result -> Int32 in
            compress2(dest, &destLen, result.bindMemory(to: Bytef.self).baseAddress, srcLen, Z_BEST_SPEED)
        }
        if ret != Z_OK {
            print("[Error] Compress Error \(ret), upper bound: \(upperBound)")
            dest.deallocate()
            return ""
        }
        let count = Int(destLen)
        let result = base64URL(data: Data(bytesNoCopy: dest, count: count, deallocator: .free))
        return result
    }

    class func hmac(plainText: String, secretKey: String) -> String? {
        guard let cKey = secretKey.cString(using: String.Encoding.ascii) else {
            print("hmac secretKey error: \(secretKey)")
            return nil
        }
        print("hmac secretKey: \(secretKey)")
        print("hmac cKey: \(cKey)")
        guard let cData = plainText.cString(using: String.Encoding.ascii) else {
            print("hmac plainText error: \(plainText)")
            return nil
        }
        print("hmac plainText: \(plainText)")
        print("hmac cData: \(cData)")
        let cKeyLen = secretKey.lengthOfBytes(using: .ascii)
        let cDataLen = plainText.lengthOfBytes(using: .ascii)
        var cHMAC = [CUnsignedChar](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        cHMAC.withUnsafeMutableBufferPointer { buffer in
            CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA256), cKey, cKeyLen, cData, cDataLen, buffer.baseAddress)
        }
        let data = Data(cHMAC)
        print("cHMAC.count: \(String(describing: cHMAC.count))")
        print("data: \(String(describing: data))")
        let result = data.base64EncodedString(options: [])
        return result
    }

    class func base64URL(data: Data) -> String {
        let result = data.base64EncodedString(options: Data.Base64EncodingOptions(rawValue: 0))
        var final = ""
        for char in result {
            switch char {
            case "+":
                final += "*"
            case "/":
                final += "-"
            case "=":
                final += "_"
            default:
                final += "\(char)"
            }
        }
        return final
    }
}
