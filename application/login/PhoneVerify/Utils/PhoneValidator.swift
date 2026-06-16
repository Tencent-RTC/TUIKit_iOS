//
//  PhoneValidator.swift
//  login
//
//  手机号校验工具
//

import Foundation

struct PhoneValidator {
    /// 校验手机号是否有效（最大 11 位数字）
    static func isValid(_ phone: String) -> Bool {
        let digits = phone.filter { $0.isNumber }
        return digits.count > 0 && digits.count <= 11
    }
    
    /// 是否为测试手机号
    static func isTestPhone(_ number: String) -> Bool {
        let pattern = "^86100000000(0[1-9]|[1-4]\\d|50)$"
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: number.utf16.count)
        let matches = regex?.matches(in: number, options: [], range: range)
        return matches?.count == 1
    }
}
