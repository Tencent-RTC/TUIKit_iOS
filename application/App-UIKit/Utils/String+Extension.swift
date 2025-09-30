//
//  String+Extension.swift
//  App-UIKit
//
//  Created by yukiwwwang on 2025/8/20.
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
