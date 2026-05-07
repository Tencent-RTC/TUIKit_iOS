//
//  AppLifecycleRegistry.swift
//  Login
//

import UIKit

// MARK: - Protocol

public protocol AppLifecycleHandler: AnyObject {
    
    func handleOpenURL(_ url: URL, options: [UIApplication.OpenURLOptionsKey: Any]) -> Bool
    
    func applicationDidFinishLaunching(_ application: UIApplication)
    
    func applicationWillEnterForeground(_ application: UIApplication)
    
    func applicationDidEnterBackground(_ application: UIApplication)
    
    func applicationDidRegisterForRemoteNotifications(deviceToken: Data)
}

public extension AppLifecycleHandler {
    func handleOpenURL(_ url: URL, options: [UIApplication.OpenURLOptionsKey: Any]) -> Bool { return false }
    func applicationDidFinishLaunching(_ application: UIApplication) {}
    func applicationWillEnterForeground(_ application: UIApplication) {}
    func applicationDidEnterBackground(_ application: UIApplication) {}
    func applicationDidRegisterForRemoteNotifications(deviceToken: Data) {}
}

// MARK: - Registry

public final class AppLifecycleRegistry {
    public static let shared = AppLifecycleRegistry()
    private init() {}
    
    private struct WeakHandler {
        weak var value: AppLifecycleHandler?
    }
    
    private var handlers: [WeakHandler] = []
    
    public func register(_ handler: AppLifecycleHandler) {
        cleanUp()
        guard !handlers.contains(where: { $0.value === handler }) else { return }
        handlers.append(WeakHandler(value: handler))
    }
    
    public func unregister(_ handler: AppLifecycleHandler) {
        handlers.removeAll { $0.value === handler }
    }
    
    @discardableResult
    public func handleOpenURL(_ url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        cleanUp()
        for wrapper in handlers {
            if let handler = wrapper.value, handler.handleOpenURL(url, options: options) {
                return true
            }
        }
        return false
    }
    
    public func applicationDidFinishLaunching(_ application: UIApplication) {
        cleanUp()
        handlers.forEach { $0.value?.applicationDidFinishLaunching(application) }
    }
    
    public func applicationWillEnterForeground(_ application: UIApplication) {
        cleanUp()
        handlers.forEach { $0.value?.applicationWillEnterForeground(application) }
    }
    
    public func applicationDidEnterBackground(_ application: UIApplication) {
        cleanUp()
        handlers.forEach { $0.value?.applicationDidEnterBackground(application) }
    }
    
    public func applicationDidRegisterForRemoteNotifications(deviceToken: Data) {
        cleanUp()
        handlers.forEach { $0.value?.applicationDidRegisterForRemoteNotifications(deviceToken: deviceToken) }
    }
    
    // MARK: - Private
    
    private func cleanUp() {
        handlers.removeAll { $0.value == nil }
    }
}
