//
//  AIMinutesConfig.swift
//  AIMinutesView
//

import UIKit

/// Configuration for the AI minutes list view.
public struct AIMinutesConfig {
    public var displayMode: DisplayMode
    public var sourceStyle: TextStyle
    public var translationStyle: TextStyle
    public var speakerStyle: SpeakerStyle
    public var showSpeaker: Bool
    public var showTimestamp: Bool
    public var backgroundColor: UIColor
    public var itemBackgroundColor: UIColor
    public var itemCornerRadius: CGFloat
    public var itemContentInsets: UIEdgeInsets
    public var itemSpacing: CGFloat
    public var lineSpacing: CGFloat
    public var listContentInsets: UIEdgeInsets
    /// Custom timestamp formatter. Receives millisecond timestamp, returns formatted string.
    public var timestampFormatter: ((Int64) -> String)?
    
    public init(
        displayMode: DisplayMode = .dual,
        sourceStyle: TextStyle = TextStyle(textColor: UIColor(red: 0.13, green: 0.15, blue: 0.18, alpha: 1.0), fontSize: 15),
        translationStyle: TextStyle = TextStyle(textColor: UIColor(red: 0.13, green: 0.15, blue: 0.18, alpha: 0.6), fontSize: 12),
        speakerStyle: SpeakerStyle = SpeakerStyle(
            nameColor: UIColor(red: 0.13, green: 0.15, blue: 0.18, alpha: 1.0),
            nameFont: UIFont.systemFont(ofSize: 14, weight: .medium),
            timestampColor: UIColor(red: 0.56, green: 0.56, blue: 0.58, alpha: 1.0),
            timestampFont: UIFont.systemFont(ofSize: 13, weight: .regular),
            nameTimestampSpacing: 6,
            bottomSpacing: 8
        ),
        showSpeaker: Bool = true,
        showTimestamp: Bool = true,
        backgroundColor: UIColor = .white,
        itemBackgroundColor: UIColor = UIColor(red: 0.95, green: 0.96, blue: 0.98, alpha: 1.0),
        itemCornerRadius: CGFloat = 10,
        itemContentInsets: UIEdgeInsets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16),
        itemSpacing: CGFloat = 0,
        lineSpacing: CGFloat = 12,
        listContentInsets: UIEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 12, right: 0),
        timestampFormatter: ((Int64) -> String)? = nil
    ) {
        self.displayMode = displayMode
        self.sourceStyle = sourceStyle
        self.translationStyle = translationStyle
        self.speakerStyle = speakerStyle
        self.showSpeaker = showSpeaker
        self.showTimestamp = showTimestamp
        self.backgroundColor = backgroundColor
        self.itemBackgroundColor = itemBackgroundColor
        self.itemCornerRadius = itemCornerRadius
        self.itemContentInsets = itemContentInsets
        self.itemSpacing = itemSpacing
        self.lineSpacing = lineSpacing
        self.listContentInsets = listContentInsets
        self.timestampFormatter = timestampFormatter
    }
    
    public static var `default`: AIMinutesConfig {
        return AIMinutesConfig()
    }
    
    // MARK: - Helpers
    
    func formatTimestamp(_ timestamp: Int64) -> String {
        if let formatter = timestampFormatter {
            return formatter(timestamp)
        }
        let date = Date(timeIntervalSince1970: Double(timestamp) / 1000.0)
        let df = DateFormatter()
        df.dateFormat = "MM-dd HH:mm"
        return df.string(from: date)
    }
}
