import Foundation

/**
 * Shared role enum definition
 * Used to pass the user role between feature pages
 */
enum Role: String {
    case anchor
    case audience

    var titleKey: String {
        switch self {
        case .anchor: return "roleSelect.anchor"
        case .audience: return "roleSelect.audience"
        }
    }
}
