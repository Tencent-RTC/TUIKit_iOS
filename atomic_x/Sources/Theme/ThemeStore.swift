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

enum ThemePreference: String {
    case manual
    case followSystem
}

/// ThemeStore - Singleton for managing global theme state
public final class ThemeStore {
    
    // MARK: - Singleton
    public static let shared = ThemeStore()
    
    // MARK: - Published State
    @Published public private(set) var currentTheme: Theme = Theme.darkTheme
    
    // MARK: - Private Properties
    private let userDefaultsHelper = UserDefaultsHelper()
    private var cancellables = Set<AnyCancellable>()
    private var debounceWorkItem: DispatchWorkItem?
    private let debounceDelay: TimeInterval = 0.3
    
    // MARK: - Initialization
    private init() {
        loadPersistedTheme()
        observeSystemAppearanceChanges()
    }
    
    // MARK: - Public Methods
    
    public func setTheme(_ theme: Theme) {
        debounceWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.currentTheme = theme
            self.persistTheme(theme)
        }
        
        debounceWorkItem = workItem
        
        DispatchQueue.main.asyncAfter(deadline: .now() + debounceDelay, execute: workItem)
    }
    
    // MARK: - Token Accessors (便捷访问器)
    
    public var space: SpaceTokens {
        return currentTheme.tokens.space
    }
    
    public var color: ColorTokens {
        return currentTheme.tokens.color
    }
    

    public var borderRadius: BorderRadiusToken {
        return currentTheme.tokens.borderRadius
    }
    
    public var typography: TypographyToken {
        return currentTheme.tokens.typography
    }
    
    public var shadows: Shadows {
        return currentTheme.tokens.shadows
    }
    
    // MARK: - Persistence
    
    private func loadPersistedTheme() {
        switch userDefaultsHelper.getThemePreference() {
        case .manual:
            if let themeId = userDefaultsHelper.getCurrentThemeId() {
                loadTheme(byId: themeId)
            }
        case .followSystem:
            loadThemeBasedOnSystemAppearance()
        }
    }
    
    private func persistTheme(_ theme: Theme) {
        userDefaultsHelper.setCurrentThemeId(theme.id)
        userDefaultsHelper.setThemePreference(.manual)
    }
    
    private func loadTheme(byId themeId: String) {
        let loadedTheme: Theme
        switch themeId {
        case "light":
            loadedTheme = .lightTheme
        case "dark":
            loadedTheme = .darkTheme
        default:
            loadedTheme = .defaultTheme
        }
        currentTheme = loadedTheme
    }
    
    private func loadThemeBasedOnSystemAppearance() {
        let loadedTheme: Theme
        switch UITraitCollection.current.userInterfaceStyle {
        case .dark:
            loadedTheme = .darkTheme
        case .light, .unspecified:
            loadedTheme = .lightTheme
        @unknown default:
            loadedTheme = .darkTheme
        }

        currentTheme = loadedTheme
    }
    
    private func observeSystemAppearanceChanges() {
        if #available(iOS 13.0, *) {
            NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
                .sink { [weak self] _ in
                    guard let self = self else { return }
                    
                    if self.userDefaultsHelper.getThemePreference() == .followSystem {
                        self.loadThemeBasedOnSystemAppearance()
                    }
                }
                .store(in: &cancellables)
        }
    }
}

final class UserDefaultsHelper {
    
    private let defaults: UserDefaults
    
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }
    
    // MARK: - Read
    
    func getCurrentThemeId() -> String? {
        return defaults.string(forKey: .currentThemeId)
    }
    
    func getThemePreference() -> ThemePreference {
        guard let raw = defaults.string(forKey: .themePreference),
              let preference = ThemePreference(rawValue: raw) else {
            return .manual
        }
        return preference
    }
    
    // MARK: - Write
    
    func setCurrentThemeId(_ themeId: String) {
        defaults.set(themeId, forKey: .currentThemeId)
    }
    
    func setThemePreference(_ preference: ThemePreference) {
        defaults.set(preference.rawValue, forKey: .themePreference)
    }
    
    // MARK: - Clear
    
    func clearThemePreferences() {
        defaults.removeObject(forKey: .currentThemeId)
        defaults.removeObject(forKey: .themePreference)
    }
}

fileprivate extension String {
    static let currentThemeId = "com.theme.currentThemeId"
    static let themePreference = "com.theme.preference"
}
