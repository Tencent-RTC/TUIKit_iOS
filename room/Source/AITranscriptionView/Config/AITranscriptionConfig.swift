//
//  AITranscriptionConfig.swift
//  AITranscriptionView
//

import UIKit

// MARK: - Data Model

/// Transcription data for a single subtitle/minutes segment.
public struct AITranscriptionData: Equatable {
    public let segmentId: String
    public var speakerUserId: String
    public var speakerUserName: String
    public var sourceText: String
    public var translationText: String
    public var timestamp: Int64
    public var isCompleted: Bool
    
    public init(
        segmentId: String = "",
        speakerUserId: String = "",
        speakerUserName: String = "",
        sourceText: String = "",
        translationText: String = "",
        timestamp: Int64 = 0,
        isCompleted: Bool = false
    ) {
        self.segmentId = segmentId
        self.speakerUserId = speakerUserId
        self.speakerUserName = speakerUserName
        self.sourceText = sourceText
        self.translationText = translationText
        self.timestamp = timestamp
        self.isCompleted = isCompleted
    }
    
    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.segmentId == rhs.segmentId &&
        lhs.speakerUserId == rhs.speakerUserId &&
        lhs.speakerUserName == rhs.speakerUserName &&
        lhs.sourceText == rhs.sourceText &&
        lhs.translationText == rhs.translationText &&
        lhs.timestamp == rhs.timestamp &&
        lhs.isCompleted == rhs.isCompleted
    }
}

// MARK: - Display Mode

/// Display mode for subtitle and minutes views.
public enum DisplayMode {
    case sourceOnly
    case translationOnly
    /// Dual-language: source on top, translation below.
    case dual
    /// Dual-language reversed: translation on top, source below (subtitle only).
    case dualReversed
}

// MARK: - Text Style

/// Text appearance configuration shared by subtitle and minutes views.
public struct TextStyle {
    public var textColor: UIColor
    public var fontSize: CGFloat
    public var font: UIFont
    public var shadowColor: UIColor
    public var shadowOffset: CGSize
    public var shadowRadius: CGFloat
    
    public init(
        textColor: UIColor = .white,
        fontSize: CGFloat = 16,
        font: UIFont? = nil,
        shadowColor: UIColor = UIColor.black.withAlphaComponent(0.6),
        shadowOffset: CGSize = CGSize(width: 0, height: 1),
        shadowRadius: CGFloat = 2
    ) {
        self.textColor = textColor
        self.fontSize = fontSize
        self.font = font ?? UIFont.systemFont(ofSize: fontSize, weight: .regular)
        self.shadowColor = shadowColor
        self.shadowOffset = shadowOffset
        self.shadowRadius = shadowRadius
    }
}

// MARK: - Speaker Style

/// Speaker label appearance configuration.
public struct SpeakerStyle {
    public var nameColor: UIColor
    public var nameFont: UIFont
    public var timestampColor: UIColor
    public var timestampFont: UIFont
    public var nameTimestampSpacing: CGFloat
    public var bottomSpacing: CGFloat
    
    public init(
        nameColor: UIColor = UIColor.white.withAlphaComponent(0.7),
        nameFont: UIFont = UIFont.systemFont(ofSize: 16.0),
        timestampColor: UIColor = UIColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 1.0),
        timestampFont: UIFont = .systemFont(ofSize: 14, weight: .regular),
        nameTimestampSpacing: CGFloat = 8,
        bottomSpacing: CGFloat = 2
    ) {
        self.nameColor = nameColor
        self.nameFont = nameFont
        self.timestampColor = timestampColor
        self.timestampFont = timestampFont
        self.nameTimestampSpacing = nameTimestampSpacing
        self.bottomSpacing = bottomSpacing
    }
}

// MARK: - Avatar Style

/// Avatar appearance configuration (used by subtitle view).
public struct AvatarStyle {
    public var size: CGFloat
    public var spacing: CGFloat
    public var placeholder: UIImage?
    public var topOffset: CGFloat
    
    public init(
        size: CGFloat = 32,
        spacing: CGFloat = 8,
        placeholder: UIImage? = nil,
        topOffset: CGFloat = 0
    ) {
        self.size = size
        self.spacing = spacing
        self.placeholder = placeholder
        self.topOffset = topOffset
    }
}
