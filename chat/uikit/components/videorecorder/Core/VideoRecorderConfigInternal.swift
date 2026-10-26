import UIKit

final class VideoRecorderConfigInternal {
    private static let defaultConfigFile = "video_recorder_config"

    private static let defaultThemeColor = "#147AFF"

    private static let defaultVideoQuality = 2

    private static let defaultMaxRecordDurationMs = 15000

    private static let defaultMinRecordDurationMs = 2000

    private static let defaultRecordMode = 0

    private static let instance = VideoRecorderConfigInternal()

    private var jsonDicFromConfigFile: [String: Any]?

    private var jsonDicFromSetting: [String: Any]?

    static func sharedInstance() -> VideoRecorderConfigInternal {
        return instance
    }

    private init() {
        guard let modleNSBundle = VideoRecorderCommon.modleNSBundle,
              let path = modleNSBundle.path(forResource: Self.defaultConfigFile, ofType: "json"),
              let jsonData = FileManager.default.contents(atPath: path) else {
            return
        }
        print("jsonData : \(jsonData)")
        jsonDicFromConfigFile = Self.parseJsonDictionary(jsonData, failureLog: "[VideoRecorder] Json parse failed")
    }

    func setCustomConfig(_ jsonString: String?) {
        guard let jsonString = jsonString else { return }
        guard let jsonData = jsonString.data(using: .utf8) else {
            print("Error converting string to data")
            return
        }
        jsonDicFromSetting = Self.parseJsonDictionary(jsonData, failureLog: "[VideoRecorderConfig setConfig]  Json parse failed")
    }

    func isSupportRecordAspect() -> Bool {
        return getBoolFromDic("support_record_aspect", defaultValue: true)
    }

    func isSupportRecordTorch() -> Bool {
        return getBoolFromDic("support_record_torch", defaultValue: true)
    }

    func getThemeColor() -> UIColor {
        let colorName = getStringFromDic("primary_theme_color", defaultValue: Self.defaultThemeColor)
        return VideoRecorderCommon.tui_colorWithHex(colorName)
    }

    func getVideoQuality() -> Int {
        return getIntFromDic("video_quality", defaultValue: Self.defaultVideoQuality)
    }

    func isDefaultFrontCamera() -> Bool {
        return getBoolFromDic("is_default_front_camera", defaultValue: false)
    }

    func getMaxRecordDurationMs() -> Int {
        return getIntFromDic("max_record_duration_ms", defaultValue: Self.defaultMaxRecordDurationMs)
    }

    func getMinRecordDurationMs() -> Int {
        return getIntFromDic("min_record_duration_ms", defaultValue: Self.defaultMinRecordDurationMs)
    }

    func getRecordeMode() -> Int {
        return getIntFromDic("record_mode", defaultValue: Self.defaultRecordMode)
    }

    private func getBoolFromDic(_ dicKey: String, defaultValue: Bool) -> Bool {
        guard let value = configValue(dicKey) else { return defaultValue }
        if let stringValue = value as? String {
            return stringValue.caseInsensitiveCompare("true") == .orderedSame
        }
        return (value as? NSNumber)?.boolValue ?? false
    }

    private func getIntFromDic(_ dicKey: String, defaultValue: Int) -> Int {
        guard let value = configValue(dicKey) else { return defaultValue }
        if let numberValue = value as? NSNumber {
            return numberValue.intValue
        }
        return Int((value as? NSString)?.intValue ?? 0)
    }

    private func getStringFromDic(_ dicKey: String, defaultValue: String) -> String {
        guard let value = configValue(dicKey) else { return defaultValue }
        return value as? String ?? defaultValue
    }

    private func configValue(_ dicKey: String) -> Any? {
        if let value = jsonDicFromSetting?[dicKey] {
            return value
        }
        return jsonDicFromConfigFile?[dicKey]
    }

    private static func parseJsonDictionary(_ jsonData: Data, failureLog: String) -> [String: Any]? {
        do {
            let object = try JSONSerialization.jsonObject(with: jsonData, options: .mutableContainers)
            guard let dictionary = object as? [String: Any] else {
                print("\(failureLog): nil")
                return nil
            }
            return dictionary
        } catch {
            print("\(failureLog): \(error)")
            return nil
        }
    }
}
