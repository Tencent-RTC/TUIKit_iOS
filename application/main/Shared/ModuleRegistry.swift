//
//  ModuleRegistry.swift
//  main
//

import Foundation
import AppAssembly

final class ModuleRegistry {
    static let shared = ModuleRegistry()
    private init() {}

    private(set) var providers: [ModuleProvider] = []

    func register(_ provider: ModuleProvider) {
        guard !providers.contains(where: { $0.config.identifier == provider.config.identifier }) else {
            AppLogger.App.warn(" 重复注册被忽略: \(provider.config.identifier)")
            return
        }
        providers.append(provider)
    }

    func resolvedModules() -> [ResolvedModule] {
        return providers.map { provider in
            ResolvedModule(config: provider.config, provider: provider)
        }
    }

    func reset() {
        providers.removeAll()
    }
}
