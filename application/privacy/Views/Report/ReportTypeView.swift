//
//  ReportTypeView.swift
//  privacy
//

import Foundation
import UIKit
import RTCCommon
import SnapKit

// MARK: - ReportTypeCollectionCell

class ReportTypeCollectionCell: UICollectionViewCell {

    lazy var titleLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.textColor = UIColor.black
        label.backgroundColor = UIColor(hex: "F4F5F9")
        label.font = UIFont.systemFont(ofSize: 12)
        label.textAlignment = .center
        return label
    }()

    private var isViewReady = false
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else { return }
        isViewReady = true
        constructViewHierarchy()
        activateConstraints()
    }

    private func constructViewHierarchy() {
        contentView.addSubview(titleLabel)
    }

    private func activateConstraints() {
        titleLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func updateSelect(_ isSelect: Bool) {
        titleLabel.textColor = isSelect ? UIColor.white : UIColor.black
        titleLabel.backgroundColor = UIColor(hex: (isSelect ? "006EFF" : "F4F5F9"))
    }
}

// MARK: - ReportTypeView

class ReportTypeView: UIView {

    var currentSelectType: ReportType = .none
    var selectTypeBlock: ((_ type: ReportType) -> Void)?

    convenience init(types: [ReportType]) {
        self.init(frame: .zero)
        self.types = types
    }

    private var types: [ReportType] = []

    private lazy var titleLabel: UILabel = {
        let label = UILabel(frame: .zero)
        let content = NSMutableAttributedString(
            string: PrivacyLocalize("Privacy.Report.type.title") + "*",
            attributes: [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor(hex: "888888") ?? UIColor.lightText,
            ]
        )
        content.addAttributes(
            [.foregroundColor: UIColor.red],
            range: (content.string as NSString).range(of: "*")
        )
        label.attributedText = content
        label.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        label.textColor = .black
        return label
    }()

    private lazy var collectionLayout: UICollectionViewFlowLayout = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.sectionInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        layout.minimumInteritemSpacing = 16
        layout.minimumLineSpacing = 16
        let width = (UIScreen.main.bounds.width - layout.sectionInset.left - layout.sectionInset.right - layout.minimumInteritemSpacing * 2) / 3
        layout.itemSize = CGSize(width: width, height: 30)
        return layout
    }()

    private lazy var collectionView: UICollectionView = {
        let view = UICollectionView(frame: .zero, collectionViewLayout: collectionLayout)
        view.backgroundColor = .white
        view.register(ReportTypeCollectionCell.self, forCellWithReuseIdentifier: "CellID")
        view.delegate = self
        view.dataSource = self
        view.isScrollEnabled = false
        return view
    }()

    private var isViewReady = false
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else { return }
        isViewReady = true
        constructViewHierarchy()
        activateConstraints()
    }
}

// MARK: - UI Layout

extension ReportTypeView {

    private func constructViewHierarchy() {
        addSubview(titleLabel)
        addSubview(collectionView)
    }

    private func activateConstraints() {
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(20)
            make.top.equalTo(0)
        }
        collectionView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(10)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(122)
            make.bottom.equalTo(0)
        }
    }
}

// MARK: - UICollectionViewDataSource

extension ReportTypeView: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return types.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CellID", for: indexPath) as! ReportTypeCollectionCell
        cell.titleLabel.text = types[indexPath.item].title
        let isSelect = currentSelectType == types[indexPath.item]
        cell.updateSelect(isSelect)
        return cell
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension ReportTypeView: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        currentSelectType = types[indexPath.item]
        selectTypeBlock?(currentSelectType)
        collectionView.reloadData()
    }
}
