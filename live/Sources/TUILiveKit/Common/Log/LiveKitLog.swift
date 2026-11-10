import Foundation
import TXLiteAVSDK_Professional

/// Component diagnostics written through the LiteAV SDK logging pipeline.
enum LiveKitLog {
    private enum Level: Int {
        case info = 0
        case warn = 1
        case error = 2
    }

    static func info(_ message: String, file: String = #fileID, line: Int = #line) {
        log(.info, message: message, file: file, line: line)
    }

    static func warn(_ message: String, file: String = #fileID, line: Int = #line) {
        log(.warn, message: message, file: file, line: line)
    }

    static func error(_ message: String, file: String = #fileID, line: Int = #line) {
        log(.error, message: message, file: file, line: line)
    }

    private static func log(_ level: Level, message: String, file: String, line: Int) {
        let payload: [String: Any] = [
            "api": "TuikitLog",
            "params": [
                "level": level.rawValue,
                "message": message,
                "module": "TUILiveKit",
                "file": file,
                "line": line
            ]
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8) else { return }
        TRTCCloud.sharedInstance().callExperimentalAPI(json)
    }
}
