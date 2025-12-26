//
//  ThemeModels..swift
//  Runtime Theme & Design Tokens
//
//  Created: 2025-11-13
//  Feature: 001-runtime-theme-tokens
//

import Foundation
import Combine
import RTCCommon

// MARK: - Theme model

public struct Theme {
    public let id: String
    public let displayName: String
    public let tokens: DesignTokenSet
    
    public init(id: String, displayName: String, tokens: DesignTokenSet) {
        self.id = id
        self.displayName = displayName
        self.tokens = tokens
    }
    
    public var color: ColorTokens {
        return self.tokens.color
    }
    
    public var typography: TypographyToken {
        return self.tokens.typography
    }
    
    public var shadows: Shadows {
        return self.tokens.shadows
    }
    
    public var borderRadius: BorderRadiusToken {
        return self.tokens.borderRadius
    }
}


extension Theme: Identifiable {}

extension Theme: Equatable {
    public static func == (lhs: Theme, rhs: Theme) -> Bool {
        return lhs.id == rhs.id
    }
}

extension Theme {
    public static var defaultTheme: Theme {
        return Theme(
            id: "default",
            displayName: "Default",
            tokens: DesignTokenSet.placeholder
        )
    }
}

