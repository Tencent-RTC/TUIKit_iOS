//
//  LoginLogger.swift
//  Login
//
//  Login 模块统一日志工具 — 基于 AtomicX Loggable 协议封装
//
//  Login 是独立的 pod，无法引用壳工程的 AppLogger.App，
//  本类型与 AppLogger.App 同构，仅 moduleName 为 "Login"。
//
//  使用方式：
//    LoginLogger.Login.info("入口")
//    LoginLogger.Login.warn("非预期分支")
//    LoginLogger.Login.debug("仅 Debug 构建输出参数 dump")
//

import AtomicX
import Foundation

enum LoginLogger {
    enum Login: Loggable {
        static var moduleName: String { "Login" }

        /// Debug 级别 — 仅 Debug 构建通过 debugPrint 输出，不走 TRTC 日志通道
        ///
        /// 与 AppLogger.swift 中针对 Loggable 的 `debug` 扩展行为一致；
        /// 此处直接定义在 LoginLogger.Login 上，避免对 Loggable 协议做跨模块扩展。
        static func debug(file: String = #file, line: Int = #line, _ messages: String...) {
            #if DEBUG
            let fileName = (file as NSString).lastPathComponent
            debugPrint("[DEBUG][\(moduleName)][\(fileName):\(line)] \(messages.joined())")
            #endif
        }
    }
}
