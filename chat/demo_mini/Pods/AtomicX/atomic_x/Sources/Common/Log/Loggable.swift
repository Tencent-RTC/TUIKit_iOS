//
//  BaseLogger.swift
//  AtomicX
//
//  Created by CY zhao on 2026/1/13.
//

import Foundation

#if canImport(TXLiteAVSDK_TRTC)
    import TXLiteAVSDK_TRTC
#elseif canImport(TXLiteAVSDK_Professional)
    import TXLiteAVSDK_Professional
#endif


public protocol Loggable {
    static var moduleName: String { get }
}

public enum LogLevel: Int {
    case error = 2
    case warn = 1
    case info = 0
}

public extension Loggable {
    static func error(file: String = #file, line: Int = #line, _ messages: String...) {
        log(level: .error, file: file, line: line, messages: messages)
    }

    static func warn(file: String = #file, line: Int = #line, _ messages: String...) {
        log(level: .warn, file: file, line: line, messages: messages)
    }

    static func info(file: String = #file, line: Int = #line, _ messages: String...) {
        log(level: .info, file: file, line: line, messages: messages)
    }

    private static func log(level: LogLevel, file: String, line: Int, messages: [String]) {
        let apiParams: [String: Any] = [
            "api": "TuikitLog",
            "params": [
                "level": level.rawValue,
                "message": messages.joined(),
                "module": self.moduleName,
                "file": file,
                "line": line,
            ],
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: apiParams, options: .prettyPrinted),
              let jsonString = String(data: jsonData, encoding: .utf8) else { return }
        
        TRTCCloud.sharedInstance().callExperimentalAPI(jsonString)
    }
}

internal class Logger: Loggable {
    static var moduleName: String { "AtomicX" }
}
