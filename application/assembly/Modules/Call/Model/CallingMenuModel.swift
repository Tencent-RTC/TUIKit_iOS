//
//  CallingMenuModel.swift
//  main
//

import UIKit

let TUICore_ContactUsService = "TUICore_ContactUsService"
let TUICore_ContactService_ShowContactEntrance = "TUICore_ContactService_ShowContactEntrance"
let TUICore_ContactService_HideContactEntrance = "TUICore_ContactService_HideContactEntrance"
let TUICore_ContactService_gotoContactUS = "TUICore_ContactService_gotoContactUS"

typealias HandlerType = (_ model: CallingMenuModel) -> Void

struct CallingMenuModel {
    var isUnfoled: Bool = false
    let iconImageName: String
    let title: String
    let content: String
    var selectHandle: () -> Void
    var subInfos: [CallingRobotModel] = []
    var stressContent: [String]
    var iconImage: UIImage? {
        AppAssemblyBundle.image(named: iconImageName)
    }

    init(title: String, content: String, imageName: String, stressContent: [String] = [], selectHandle: @escaping () -> Void) {
        self.title = title
        self.content = content
        self.selectHandle = selectHandle
        self.iconImageName = imageName
        self.stressContent = stressContent
    }
}
