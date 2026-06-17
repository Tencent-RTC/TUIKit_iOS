import AlbumPickerCore
import UIKit

// MARK: - AlbumPickerTheme + CoreTheme Sync

extension AlbumPickerTheme {
    internal func applyToCoreTheme() {
        let core = AlbumPickerCoreTheme.shared
        if let value = currentPrimaryColor { core.currentPrimaryColor = value }
        if let value = backgroundColor { core.backgroundColor = value }
        if let value = backgroundColorSecondary { core.backgroundColorSecondary = value }
        if let value = textColor { core.textColor = value }
        if let value = textColorSecondary { core.textColorSecondary = value }
        core.confirmButtonIcon = confirmButtonIcon
        if let value = bigFontSize { core.bigFontSize = value }
        if let value = normalFontSize { core.normalFontSize = value }
        if let value = smallFontSize { core.smallFontSize = value }
        if let value = bigRadius { core.bigRadius = value }
        if let value = normalRadius { core.normalRadius = value }
        if let value = smallRadius { core.smallRadius = value }
    }
}
