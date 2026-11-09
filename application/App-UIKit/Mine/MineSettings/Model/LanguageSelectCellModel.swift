//
//  LanguageSelectCellModel.swift
//  App-UIKit
//
//  Created by yukiwwwang on 2025/8/19.
//

struct LanguageSelectCellModel {
    let languageID: String
    let languageName: String
    var selected: Bool
    
    init(languageID: String, languageName: String = "", selected: Bool = false) {
        self.languageID = languageID
        self.languageName = languageName
        self.selected = selected
    }
}
