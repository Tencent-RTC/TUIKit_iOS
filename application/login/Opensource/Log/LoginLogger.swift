//
//  LoginLogger.swift
//  Login
//

import AtomicX
import Foundation

enum LoginLogger {
    enum Login: Loggable {
        static var moduleName: String { "Login" }

        static func debug(file: String = #file, line: Int = #line, _ messages: String...) {
            #if DEBUG
            let fileName = (file as NSString).lastPathComponent
            debugPrint("[DEBUG][\(moduleName)][\(fileName):\(line)] \(messages.joined())")
            #endif
        }
    }
}
