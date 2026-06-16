//
//  AppLogger.swift
//  RTCube
//
//  统一日志工具 — 基于 AtomicX Loggable 协议封装
//
//  使用方式：
//    AppLogger.App.info("用户允许了推送权限")
//    AppLogger.App.warn("日志目录读取失败")
//    AppLogger.App.debug("仅 Debug 构建输出")
//

import Foundation
import AtomicX

// MARK: - Loggable + Debug

extension Loggable {
    /// Debug 级别 — 仅 Debug 构建通过 debugPrint 输出，不走 TRTC 日志通道
    static func debug(file: String = #file, line: Int = #line, _ messages: String...) {
        #if DEBUG
        let fileName = (file as NSString).lastPathComponent
        debugPrint("[DEBUG][\(moduleName)][\(fileName):\(line)] \(messages.joined())")
        #endif
    }
}

// MARK: - AppLogger 模块定义

enum AppLogger {
    enum App: Loggable      { static var moduleName: String { "App" } }
}
