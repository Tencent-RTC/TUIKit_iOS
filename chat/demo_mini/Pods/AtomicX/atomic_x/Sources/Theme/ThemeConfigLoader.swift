//
//  ThemeConfigLoader.swift
//  Pods
//
//  Created by ssc on 2026/1/26.
//


import Foundation

/// App configuration model matching appConfig.json structure
public struct AppConfig: Codable {
    public let scene: String?
    public let theme: ThemeConfig?
    public let button: ButtonConfig?
    public let toast: ToastConfig?
    public let icon: IconConfig?
    public let dialog: DialogConfig?
    public let messageBox: MessageBoxConfig?
    public let fullScreen: Bool?

    public struct ThemeConfig: Codable {
        public let color: String
        public let primaryColor: String
    }

    public struct ButtonConfig: Codable {
        public let color: String?
        public let shape: String?
        public let size: String?
    }

    public struct ToastConfig: Codable {
        public let shape: String?
        public let showIcon: Bool?
        public let showClose: Bool?
    }

    public struct IconConfig: Codable {
        public let size: String?
    }

    public struct DialogConfig: Codable {
        public let shape: String?
    }

    public struct MessageBoxConfig: Codable {
        public let type: String?
    }
}

/// Theme configuration loader
public final class ThemeConfigLoader {

    public static let shared = ThemeConfigLoader()

    private var configFilePath: String?
    private var loadedConfig: AppConfig?

    private init() {}

    // MARK: - Public Methods

    /// Set the path to appConfig.json file
    /// - Parameter path: Absolute path to the JSON configuration file
    public func setConfigPath(_ path: String) {
        self.configFilePath = path
    }

    /// Load and apply theme configuration from appConfig.json
    /// - Returns: True if configuration was successfully loaded and applied
    @discardableResult
    public func loadAndApplyThemeConfig() -> Bool {
        guard let config = loadConfig() else {
            print("⚠️ Failed to load appConfig.json")
            return false
        }

        self.loadedConfig = config

        guard let themeConfig = config.theme else {
            print("⚠️ No theme configuration found in appConfig.json")
            return false
        }

        applyThemeConfig(themeConfig)
        return true
    }

    /// Get the loaded configuration
    public func getConfig() -> AppConfig? {
        return loadedConfig
    }

    // MARK: - Private Methods

    private func loadConfig() -> AppConfig? {
        guard let path = configFilePath else {
            return nil
        }

        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            return nil
        }

        do {
            let decoder = JSONDecoder()
            let config = try decoder.decode(AppConfig.self, from: data)
            return config
        } catch {
            return nil
        }
    }

    private func applyThemeConfig(_ themeConfig: AppConfig.ThemeConfig) {
        // Parse theme mode from color field
        let themeMode = parseThemeMode(from: themeConfig.color)

        // Parse primary color (remove # prefix if present)
        let primaryColor = themeConfig.primaryColor.trimmingCharacters(in: CharacterSet(charactersIn: "#"))

        // Apply to ThemeStore
        ThemeStore.shared.setMode(themeMode)
        ThemeStore.shared.setPrimaryColor(primaryColor)
    }

    /// Parse theme mode from the color string
    /// - Parameter colorString: Color field from config ("dark", "light", "black", "white", etc.)
    /// - Returns: Corresponding ThemeMode
    private func parseThemeMode(from colorString: String) -> ThemeMode {
        let normalized = colorString.lowercased().trimmingCharacters(in: .whitespaces)

        switch normalized {
            case "dark", "black":
                return .dark
            case "light", "white":
                return .light
            case "system", "auto":
                return .system
            default:
                return .dark
        }
    }
}

// MARK: - Convenience Extensions

extension ThemeConfigLoader {

    /// Load configuration from Bundle's main bundle
    /// - Parameter fileName: JSON file name without extension (default: "appConfig")
    /// - Returns: True if successfully loaded
    @discardableResult
    public func loadFromMainBundle(fileName: String = "appConfig") -> Bool {
        guard let path = Bundle.main.path(forResource: fileName, ofType: "json") else {
            return false
        }

        setConfigPath(path)
        return loadAndApplyThemeConfig()
    }
}

