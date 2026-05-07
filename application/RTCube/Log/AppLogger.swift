//
//  AppLogger.swift
//  RTCube
//

import Foundation
import AtomicX

// MARK: - Loggable + Debug

extension Loggable {
    static func debug(file: String = #file, line: Int = #line, _ messages: String...) {
        #if DEBUG
        let fileName = (file as NSString).lastPathComponent
        debugPrint("[DEBUG][\(moduleName)][\(fileName):\(line)] \(messages.joined())")
        #endif
    }
}

enum AppLogger {
    enum App: Loggable      { static var moduleName: String { "App" } }
}
