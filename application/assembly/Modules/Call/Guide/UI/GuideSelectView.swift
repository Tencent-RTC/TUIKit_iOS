//
//  GuideSelectView.swift
//  main
//

import UIKit
import AtomicX

enum GuideSelectedType {
    case app
    case web
}

class GuideSelectCell: UITableViewCell {
    static let reuseId = "GuideSelectCell"

    let selectLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16)
        label.textColor = ThemeStore.shared.colorTokens.textColorPrimary
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        constructViewHierarchy()
        activateConstraints()
        contentView.layer.borderColor = ThemeStore.shared.colorTokens.strokeColorPrimary.cgColor
        contentView.layer.borderWidth = 1
        contentView.layer.cornerRadius = ThemeStore.shared.borderRadius.radius8
        selectionStyle = .none
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func constructViewHierarchy() {
        contentView.addSubview(selectLabel)
    }

    private func activateConstraints() {
        selectLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20.scale375())
            make.centerY.equalToSuperview()
        }
    }
}

class GuideSelectView: UIView {
    var selectedTypeClosure: (GuideSelectedType) -> Void = { _ in }

    let selectLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16)
        label.textColor = ThemeStore.shared.colorTokens.textColorPrimary
        return label
    }()

    private let iconImageView: UIImageView = {
        let imageView = UIImageView(frame: .zero)
        imageView.image = AppAssemblyBundle.image(named: "guide_unfold_arrow")
        imageView.sizeToFit()
        return imageView
    }()

    private lazy var selectData: [[String: Any]] = {
        return [
            ["desc": GuideLocalize("Demo.TRTC.Guide.othersUseWeb"),
             "type": GuideSelectedType.web],
            ["desc": GuideLocalize("Demo.TRTC.Guide.othersUseApp"),
             "type": GuideSelectedType.app],
        ]
    }()

    convenience init(_ viewType: PageType?) {
        self.init(frame: .zero)
        if viewType == .MultiPlayerWithWeb {
            configSelectData(selectType: .web)
        } else if viewType == .MultiPlayerWithApp {
            configSelectData(selectType: .app)
        }
    }

    private var isViewReady: Bool = false
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else { return }
        isViewReady = true
        constructViewHierarchy()
        activateConstraints()
    }

    func configSelectData(selectType: GuideSelectedType) {
        if let selectDict = selectData.first(where: { $0["type"] as? GuideSelectedType == selectType }) {
            self.selectLabel.text = selectDict["desc"] as? String
        }
    }

    private func constructViewHierarchy() {
        addSubview(selectLabel)
        addSubview(iconImageView)
    }

    private func activateConstraints() {
        selectLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20.scale375())
            make.centerY.equalToSuperview()
        }
        iconImageView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-20.scale375())
            make.centerY.equalToSuperview()
        }
    }
}

extension GuideSelectView: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.selectData.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: GuideSelectCell.reuseId, for: indexPath) as! GuideSelectCell
        let dic = selectData[indexPath.row]
        cell.selectLabel.text = dic["desc"] as? String
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let dic = selectData[indexPath.row]
        let selectType = dic["type"] as! GuideSelectedType
        selectedTypeClosure(selectType)
    }
}
