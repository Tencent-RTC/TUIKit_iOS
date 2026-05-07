//
//  ModuleProvider.swift
//  AppAssembly
//

import Combine
import UIKit

public protocol ModuleProvider: AnyObject {
    var config: ModuleConfig { get }

    var badgeCountPublisher: AnyPublisher<UInt64, Never> { get }

    var isVisiblePublisher: AnyPublisher<Bool, Never> { get }

    func setup(with environment: ModuleEnvironment)
}

// MARK: - Default Implementations

public extension ModuleProvider {
    var badgeCountPublisher: AnyPublisher<UInt64, Never> {
        Just(0).eraseToAnyPublisher()
    }

    var isVisiblePublisher: AnyPublisher<Bool, Never> {
        Just(true).eraseToAnyPublisher()
    }
    
    func setup(with environment: ModuleEnvironment) {}
}

public let stubUIComponentGradient: [UIColor] = [
    UIColor(red: 204 / 255.0, green: 223 / 255.0, blue: 255 / 255.0, alpha: 1),
    UIColor(red: 204 / 255.0, green: 223 / 255.0, blue: 255 / 255.0, alpha: 0.3),
    UIColor(red: 204 / 255.0, green: 223 / 255.0, blue: 255 / 255.0, alpha: 0),
]
