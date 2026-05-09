//
//  AISubtitleConfig.swift
//  AISubtitle
//

import UIKit

/// Configuration for the real-time subtitle overlay view.
public struct AISubtitleConfig {
    public var displayMode: DisplayMode
    public var sourceStyle: TextStyle
    public var translationStyle: TextStyle
    public var speakerStyle: SpeakerStyle
    public var showSpeaker: Bool
    public var avatarStyle: AvatarStyle
    public var showAvatar: Bool
    public var backgroundColor: UIColor
    public var backgroundCornerRadius: CGFloat
    public var contentInsets: UIEdgeInsets
    public var lineSpacing: CGFloat
    /// Auto-fade duration in seconds. 0 disables auto-fade.
    public var fadeOutDuration: TimeInterval
    /// Display hold time in seconds before fade-out begins.
    public var displayDuration: TimeInterval
    /// Per-character streaming animation interval.
    public var streamAnimationDuration: TimeInterval
    /// Maximum width ratio relative to the parent view.
    public var maxWidthRatio: CGFloat
    /// Maximum number of visible speaker subtitle cells.
    public var maxVisibleSpeakers: Int
    /// Spacing between speaker subtitle items.
    public var speakerItemSpacing: CGFloat
    
    public init(
        displayMode: DisplayMode = .dual,
        sourceStyle: TextStyle = TextStyle(textColor: .white, fontSize: 16, font: .systemFont(ofSize: 16, weight: .medium)),
        translationStyle: TextStyle = TextStyle(textColor: UIColor.white.withAlphaComponent(0.7), fontSize: 14, font: .systemFont(ofSize: 14, weight: .medium)),
        speakerStyle: SpeakerStyle = SpeakerStyle(),
        showSpeaker: Bool = true,
        avatarStyle: AvatarStyle = AvatarStyle(),
        showAvatar: Bool = true,
        backgroundColor: UIColor = UIColor.black.withAlphaComponent(0.5),
        backgroundCornerRadius: CGFloat = 8,
        contentInsets: UIEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12),
        lineSpacing: CGFloat = 4,
        fadeOutDuration: TimeInterval = 0.5,
        displayDuration: TimeInterval = 5.0,
        streamAnimationDuration: TimeInterval = 0.03,
        maxWidthRatio: CGFloat = 0.9,
        maxVisibleSpeakers: Int = 2,
        speakerItemSpacing: CGFloat = 8
    ) {
        self.displayMode = displayMode
        self.sourceStyle = sourceStyle
        self.translationStyle = translationStyle
        self.speakerStyle = speakerStyle
        self.showSpeaker = showSpeaker
        self.avatarStyle = avatarStyle
        self.showAvatar = showAvatar
        self.backgroundColor = backgroundColor
        self.backgroundCornerRadius = backgroundCornerRadius
        self.contentInsets = contentInsets
        self.lineSpacing = lineSpacing
        self.fadeOutDuration = fadeOutDuration
        self.displayDuration = displayDuration
        self.streamAnimationDuration = streamAnimationDuration
        self.maxWidthRatio = maxWidthRatio
        self.maxVisibleSpeakers = maxVisibleSpeakers
        self.speakerItemSpacing = speakerItemSpacing
    }
    
    public static var `default`: AISubtitleConfig {
        return AISubtitleConfig()
    }
}
