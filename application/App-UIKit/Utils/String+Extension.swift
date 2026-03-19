//
//  String+Extension.swift
//  App-UIKit
//
//  Created by yukiwwwang on 2025/8/20.
//

//  Description:
//  This extension provides utility methods for String manipulation and conversion.
//
//  Features:
//  1. addIntervalSpace: Inserts a separator string at regular intervals
//     - Useful for formatting phone numbers, card numbers, ID numbers, etc.
//     - Example: "13812345678".addIntervalSpace(intervalStr: " ", interval: 3)
//       → "138 123 456 78"
//
//  2. convertToDic: Converts a JSON string to a Dictionary
//     - Parses JSON formatted strings into [String: Any] dictionaries
//     - Returns nil if parsing fails
//     - Example: "{\"name\":\"John\"}".convertToDic()
//       → ["name": "John"]
//

import Foundation

extension String {
    func addIntervalSpace(intervalStr: String, interval: Int) -> String {
        var output = ""
        enumerated().forEach { index, c in
            if (index % interval == 0) && index > 0 {
                output += intervalStr
            }
            output.append(c)
        }
        return output
    }
    
    func convertToDic() -> [String : Any]?{
        guard let data = self.data(using: String.Encoding.utf8) else { return nil }
        if let dict = try? JSONSerialization.jsonObject(with: data,
                                                        options: .mutableContainers) as? [String : Any] {
            return dict
        }
        return nil
    }
}
