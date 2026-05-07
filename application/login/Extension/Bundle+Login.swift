//
//  Bundle+Login.swift
//  Login
//

import Foundation
import UIKit

extension Bundle {
    static let loginResources: Bundle = {
        let frameworkBundle = Bundle(for: LoginBundleToken.self)
        guard let url = frameworkBundle.url(forResource: "LoginResources", withExtension: "bundle"),
              let bundle = Bundle(url: url) else {
            return frameworkBundle
        }
        return bundle
    }()
}

private final class LoginBundleToken {}

extension UIImage {
    static func loginImage(named name: String) -> UIImage? {
        return UIImage(named: name, in: Bundle.loginResources, compatibleWith: nil)
    }
}
