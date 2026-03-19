//
//  ThemeStore.swift
//  Runtime Theme & Design Tokens
//
//  Created: 2025-11-13
//  Feature: 001-runtime-theme-tokens
//

import Foundation
import Combine
import UIKit

public enum ThemeMode: String, Codable, CaseIterable {
    case system
    case light
    case dark
}

public final class ThemeStore {
    
    public static let shared = ThemeStore()
    
    // MARK: - Published State
    @Published public private(set) var currentTheme: Theme
    
    private var settings: ThemeSettings
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        self.settings = ThemeSettings.load()
        
        let concreteMode = ThemeStore.resolveConcreteMode(from: settings.mode)
        
        self.currentTheme = ThemeStore.resolveTheme(
            mode: concreteMode,
            customColor: settings.primaryColor
        )
        
        observeSystemAppearance()
    }
    
    // MARK: - Public Methods
    
    public func setMode(_ mode: ThemeMode) {
        guard mode != settings.mode else { return }
        updateTheme(mode: mode, customColor: settings.primaryColor)
    }
    
    public func setPrimaryColor(_ hex: String) {
        guard hex != settings.primaryColor else { return }
        updateTheme(mode: settings.mode, customColor: hex)
    }
    
    // MARK: - Token Accessors (便捷访问器)
    public var currentMode: ThemeMode {
        return settings.mode
    }
    
    public var space: SpaceTokens {
        return currentTheme.tokens.space
    }
    
    public var colorTokens: ColorTokens {
        return currentTheme.tokens.color
    }
    
    public var borderRadius: BorderRadiusToken {
        return currentTheme.tokens.borderRadius
    }
    
    public var typographyTokens: TypographyToken {
        return currentTheme.tokens.typography
    }
    
    public var shadows: Shadows {
        return currentTheme.tokens.shadows
    }
    
    // MARK: - Core Logic
    
    private func updateTheme(mode: ThemeMode, customColor: String?) {
        self.settings = ThemeSettings(mode: mode, primaryColor: customColor)
        self.settings.save()
        
        let concreteMode = ThemeStore.resolveConcreteMode(from: mode)
        
        let newTheme = ThemeStore.resolveTheme(mode: concreteMode, customColor: customColor)
        
        if newTheme != currentTheme {
            self.currentTheme = newTheme
        }
    }
    
    private static func resolveTheme(mode: ThemeMode, customColor: String?) -> Theme {
        if let color = customColor {
            return Theme.makeTheme(mode: mode, primaryColor: color)
        }
        
        switch mode {
        case .dark:
            return Theme.darkTheme
        case .light, .system:
            return Theme.lightTheme
        }
    }
    
    private static func resolveConcreteMode(from mode: ThemeMode) -> ThemeMode {
        switch mode {
        case .light: return .light
        case .dark: return .dark
        case .system:
            return UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light
        }
    }
    
    // MARK: - System Observation
    
    private func observeSystemAppearance() {
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.refreshSystemThemeIfNeeded()
            }
            .store(in: &cancellables)
    }
    
    public func refreshSystemThemeIfNeeded() {
        guard settings.mode == .system else { return }
        
        let newConcreteMode = ThemeStore.resolveConcreteMode(from: .system)
        
        if newConcreteMode != currentTheme.mode {
            let newTheme = ThemeStore.resolveTheme(
                mode: newConcreteMode,
                customColor: settings.primaryColor
            )
            currentTheme = newTheme
        }
    }
}

// MARK: - Helper: Persistence
fileprivate struct ThemeSettings {
    var mode: ThemeMode
    var primaryColor: String?
    
    private static let keyMode = "com.theme.store.mode"
    private static let keyColor = "com.theme.store.primaryColor"
    
    static func load() -> ThemeSettings {
        let defaults = UserDefaults.standard
        
        let modeRaw = defaults.string(forKey: keyMode) ?? ThemeMode.dark.rawValue
        let mode = ThemeMode(rawValue: modeRaw) ?? .dark
        
        let color = defaults.string(forKey: keyColor)
        
        return ThemeSettings(mode: mode, primaryColor: color)
    }
    
    func save() {
        let defaults = UserDefaults.standard
        defaults.set(mode.rawValue, forKey: ThemeSettings.keyMode)
        
        if let color = primaryColor {
            defaults.set(color, forKey: ThemeSettings.keyColor)
        } else {
            defaults.removeObject(forKey: ThemeSettings.keyColor)
        }
    }
}
