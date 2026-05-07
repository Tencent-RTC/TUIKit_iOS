//
//  GuideViewController.swift
//  main
//

import UIKit
import AtomicX
import TUICore
import Toast_Swift

enum PageType: Int {
    case SinglePlayer
    case MultiPlayerWithWeb
    case MultiPlayerWithApp
}

class GuideViewController: UIViewController {
    var tableViewContentOffset: CGPoint = .zero
    var pageType: PageType?
    var jsonFileModel: GuideHomeModel?
    var copyUrl: String?
    var copyUrlEn: String?

    var guideItems: [GuideModel] = []
    var listViewDidScrollCallback: ((UIScrollView) -> Void)?

    private let reminderView: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = ThemeStore.shared.colorTokens.toastColorWarning
        return view
    }()

    private let stepsLable: UILabel = {
        let label = UILabel(frame: .zero)
        label.text = GuideLocalize("Demo.TRTC.calling.detailGuideSteps")
        label.font = ThemeStore.shared.typographyTokens.Medium16
        return label
    }()

    private let reminderLable: UILabel = {
        let label = UILabel(frame: .zero)
        label.textColor = ThemeStore.shared.colorTokens.textColorWarning
        label.font = ThemeStore.shared.typographyTokens.Regular12
        label.numberOfLines = 0
        return label
    }()

    private lazy var guideTableView: UITableView = {
        var table = UITableView(frame: .zero)
        table.isScrollEnabled = true
        table.dataSource = self
        table.separatorStyle = .none
        table.backgroundColor = UIColor.clear
        table.estimatedRowHeight = 42
        table.rowHeight = UITableView.automaticDimension
        table.showsVerticalScrollIndicator = false
        table.register(GuideTableViewCell.self, forCellReuseIdentifier: GuideTableViewCell.reuseId)
        table.separatorColor = .clear
        return table
    }()

    lazy var selectTableView: UITableView = {
        var table = UITableView(frame: .zero)
        table.isScrollEnabled = true
        table.dataSource = self.selectView
        table.delegate = self.selectView
        table.separatorStyle = .none
        table.backgroundColor = UIColor.clear
        table.rowHeight = 40.scale375()
        table.showsVerticalScrollIndicator = false
        table.register(GuideSelectCell.self, forCellReuseIdentifier: GuideSelectCell.reuseId)
        table.separatorColor = .clear
        table.isHidden = true
        return table
    }()

    lazy var selectView: GuideSelectView = {
        let view = GuideSelectView(self.pageType)
        view.selectedTypeClosure = { [weak self] selectType in
            guard let self = self else { return }
            var pt: PageType?
            if selectType == .web {
                pt = .MultiPlayerWithWeb
            } else if selectType == .app {
                pt = .MultiPlayerWithApp
            }
            if pt != self.pageType {
                self.pageType = pt
                self.configureData(withType: self.pageType)
                self.selectView.configSelectData(selectType: selectType)
                self.selectTableView.isHidden = true
                let firstIndexPath = IndexPath(row: 0, section: 0)
                self.guideTableView.scrollToRow(at: firstIndexPath, at: .top, animated: false)
            }
        }
        view.layer.borderColor = ThemeStore.shared.colorTokens.strokeColorPrimary.cgColor
        view.layer.borderWidth = 1
        view.layer.cornerRadius = ThemeStore.shared.borderRadius.radius8
        view.layer.masksToBounds = true
        return view
    }()

    convenience init(viewType: PageType,
                     jsonFileData: GuideHomeModel,
                     url: String,
                     urlEn: String) {
        self.init()
        self.pageType = viewType
        self.jsonFileModel = jsonFileData
        self.configureData(withType: viewType)
        self.copyUrl = url
        self.copyUrlEn = urlEn
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ThemeStore.shared.colorTokens.bgColorOperate
        let backBtn = UIButton(type: .custom)
        backBtn.setImage(AppAssemblyBundle.image(named: "calling_back"), for: .normal)
        backBtn.addTarget(self, action: #selector(backBtnClick), for: .touchUpInside)
        let item = UIBarButtonItem(customView: backBtn)
        item.tintColor = UIColor.black
        navigationItem.leftBarButtonItem = item
        navigationController?.navigationBar.shadowImage = UIImage()
        constructViewHierarchy()
        activateConstraints()
        let tap = UITapGestureRecognizer(target: self, action: #selector(showSelectTableView))
        selectView.isUserInteractionEnabled = true
        selectView.addGestureRecognizer(tap)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guideTableView.contentOffset = .zero
        navigationController?.setNavigationBarHidden(false, animated: false)
    }
}

extension GuideViewController {

    func loadGuideDataJson(_ pageType: PageType?) -> [[String: Any]] {
        if pageType == .SinglePlayer {
            guard let singleJsonFileName = jsonFileModel?.singlePlayerJsonName
            else { return [] }
            return loadGuideDataJson(withJsonName: singleJsonFileName)
        } else if pageType == .MultiPlayerWithWeb {
            guard let webJsonFileName = jsonFileModel?.withWebJsonName
            else { return [] }
            return loadGuideDataJson(withJsonName: webJsonFileName)
        } else {
            guard let appJsonFileName = jsonFileModel?.withAppJsonName
            else { return [] }
            return loadGuideDataJson(withJsonName: appJsonFileName)
        }
    }

    func loadGuideDataJson(withJsonName name: String) -> [[String: Any]] {
        guard let jsonPath = AppAssemblyBundle.path(forResource: name, ofType: "json")
        else {
            return []
        }
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: jsonPath)) else {
            return []
        }
        let value = try? JSONSerialization.jsonObject(with: data, options: .mutableLeaves)
        if let res = value as? [[String: Any]] {
            return res
        }
        return []
    }

    func configureData(withType pageType: PageType?) {
        guideItems.removeAll()
        configReminder()
        let list = loadGuideDataJson(pageType)
        var guideData: [GuideModel] = []
        list.forEach { dic in
            if let hasCopy = dic["hasCopyButton"] as? Bool,
               let avartarRawData = dic["avartarType"] as? Int,
               let avatarType = AvartarType(rawValue: avartarRawData),
               let avatarImageName = dic["avartarImageName"] as? String,
               let name = dic["name".guideLocale()] as? String,
               let contentImage = dic["leftContextImageName".guideLocale()] as? String,
               let text = dic["text".guideLocale()] as? String
            {
                let model = GuideModel(avartarType: avatarType,
                                       avatarImageName: avatarImageName,
                                       name: name,
                                       hasCopyButton: hasCopy,
                                       text: text,
                                       contextImageName: contentImage)
                guideData.append(model)
            }
        }
        guideItems = guideData
        guideTableView.reloadData()
    }

    func configReminder() {
        if pageType == .SinglePlayer {
            reminderLable.text = GuideLocalize("Demo.TRTC.calling.detailGuideReminerText")
        } else {
            reminderLable.text = GuideLocalize("Demo.TRTC.calling.detailMultiGuideReminerText")
        }
    }
}

extension GuideViewController {
    private func constructViewHierarchy() {
        view.addSubview(reminderView)
        reminderView.addSubview(reminderLable)
        view.addSubview(stepsLable)
        view.addSubview(selectView)
        view.addSubview(guideTableView)
        view.addSubview(selectTableView)
    }

    private func activateConstraints() {
        reminderView.snp.makeConstraints { make in
            make.left.greaterThanOrEqualTo(reminderLable).offset(10)
            make.height.lessThanOrEqualTo(52)
            make.height.greaterThanOrEqualTo(42)
            make.top.left.trailing.equalToSuperview()
        }
        reminderLable.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(TUIGlobalization.isChineseAppLocale() ? 16 : 10)
            make.left.right.lessThanOrEqualToSuperview().inset(16)
            make.bottom.top.lessThanOrEqualToSuperview().inset(12)
        }
        selectView.snp.makeConstraints { make in
            make.top.equalTo(reminderLable.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(pageType == .SinglePlayer ? 0 : 40)
        }
        selectTableView.snp.makeConstraints { make in
            make.leading.trailing.equalTo(selectView)
            make.top.equalTo(selectView).offset(40)
            make.height.equalTo(90)
        }
        stepsLable.snp.makeConstraints { make in
            make.top.equalTo(selectView.snp.bottom).offset(20)
            make.leading.equalTo(reminderLable)
        }

        guideTableView.snp.makeConstraints { make in
            make.top.equalTo(stepsLable.snp.bottom)
            make.left.equalToSuperview().offset(20)
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().offset(-10)
        }
    }
}

extension GuideViewController: UITableViewDataSource, UITabBarControllerDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return guideItems.count
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCell(withIdentifier: GuideTableViewCell.reuseId, for: indexPath) as! GuideTableViewCell
        if cell.isEqual(nil) {
            cell = GuideTableViewCell(frame: .zero)
        }
        let model = guideItems[indexPath.row]
        cell.config(model: model)
        cell.selectionStyle = .none
        cell.copyAction = { [weak self] in
            guard let self = self else { return }
            self.copyH5URL()
        }
        return cell
    }
}

extension GuideViewController {
    @objc func backBtnClick() {
        self.navigationController?.popViewController(animated: true)
    }

    func copyH5URL() {
        var stringToCopy: String?
        if TUIGlobalization.isChineseAppLocale() {
            stringToCopy = copyUrl
        } else {
            stringToCopy = copyUrlEn
        }
        UIPasteboard.general.string = stringToCopy
        view.makeToast(GuideLocalize("Demo.TRTC.calling.guideCopySucess"))
    }

    @objc func showSelectTableView() {
        selectTableView.isHidden = !selectTableView.isHidden
    }
}

extension String {
    fileprivate func guideLocale() -> String {
        if TUIGlobalization.isChineseAppLocale() {
            return self
        } else {
            return self + "_en"
        }
    }
}
