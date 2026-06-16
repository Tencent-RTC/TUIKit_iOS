//
//  AppAssembly+CallGuard.swift
//  AppAssembly
//
//  通话态门禁扩展
//
//  职责：
//    1. 提供 `canStartNewRoom` 计算属性，供 Live / VoiceRoom / Room 模块
//       在"开播 / 创建房间"入口同步查询当前是否处于通话中。
//    2. 提供 `showCannotStartRoomToast()` 统一 Toast，避免三处重复
//       编写 keyWindow 查找 + 本地化文案。
//
//  拆分理由：
//    该能力依赖 `AtomicXCore`（CallStore）与 `Toast-Swift` 两个库，
//    而这两个库与装配中心主职责（模块创建 / 生命周期注册）无关——
//    放在独立文件可保持 `AppAssembly.swift` 的 import 清单纯粹，
//    未来若移除通话态门禁也只需删本文件，主文件零改动。
//

import AtomicXCore
import Toast_Swift
import UIKit

extension AppAssembly {

    // MARK: - Call Status Guard

    /// 当前是否允许开启新的直播 / 语聊房 / 会议
    ///
    /// 基于 `CallStore.shared.state.value.selfInfo.status`：
    ///   - `.none` — 无通话中，允许开启 → 返回 `true`
    ///   - 其它任意状态（呼出、响铃、接通等）— 通话中，禁止开启 → 返回 `false`
    ///
    /// 供 Live / VoiceRoom / Room 模块在"开播 / 创建房间"入口同步查询，
    /// 不需要订阅变更——每次点击时读当前快照即可。
    var canStartNewRoom: Bool {
        CallStore.shared.state.value.selfInfo.status == .none
    }

    /// 在当前 keyWindow 弹出"通话过程中不能开播"Toast
    ///
    /// Live / VoiceRoom / Room 三个模块命中 `canStartNewRoom == false` 时统一调用，
    /// 避免在各入口重复编写 keyWindow 查找 + Toast 代码。
    func showCannotStartRoomToast() {
        guard let window = Self.keyWindow else { return }
        window.makeToast(AssemblyLocalize("assembly_common_cannot_start_room_during_call"))
    }

    private static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}
