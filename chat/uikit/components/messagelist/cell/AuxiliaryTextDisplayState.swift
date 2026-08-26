import Foundation

enum AuxiliaryTextDisplayState {
    case hidden
    case loading
    case text(content: String, footer: String?)
}
