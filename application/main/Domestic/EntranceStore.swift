//
//  EntranceStore.swift
//  main
//

import Combine
import UIKit
import AppAssembly

final class EntranceStore {

    @Published private(set) var state = EntranceState()

    private var cancellables = Set<AnyCancellable>()

    func loadModules() {
        var resolved = ModuleRegistry.shared.resolvedModules()

        resolved = ModulePermissionService.shared.filter(resolved)

        state.modules = resolved

        subscribeDynamicUpdates()
    }

    func selectModule(at index: Int) -> UIViewController? {
        guard index < state.modules.count else { return nil }
        let module = state.modules[index]

        guard ModulePermissionService.shared.isModuleEnabled(module) else {
            return nil
        }

        if !module.config.analyticsEvent.isEmpty {
            trackAnalytics(event: module.config.analyticsEvent)
        }

        return module.config.targetProvider()
    }

    func badgeCount(at index: Int) -> UInt64 {
        guard index < state.modules.count else { return 0 }
        return state.modules[index].badgeCount
    }

    func updateBadgeCount(for identifier: String, count: UInt64) {
        guard let index = state.modules.firstIndex(where: { $0.config.identifier == identifier }) else { return }
        state.modules[index].badgeCount = count
    }

    // MARK: - Private

    private func subscribeDynamicUpdates() {
        cancellables.removeAll()

        for (index, module) in state.modules.enumerated() {
            guard let provider = module.provider else { continue }

            provider.badgeCountPublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] count in
                    guard let self = self, index < self.state.modules.count else { return }
                    self.state.modules[index].badgeCount = count
                }
                .store(in: &cancellables)

            provider.isVisiblePublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] visible in
                    guard let self = self, index < self.state.modules.count else { return }
                    self.state.modules[index].isVisible = visible
                }
                .store(in: &cancellables)
        }
    }

    private func trackAnalytics(event: String) {
        AppLogger.App.debug(" trackAnalytics: \(event)")
    }
}
