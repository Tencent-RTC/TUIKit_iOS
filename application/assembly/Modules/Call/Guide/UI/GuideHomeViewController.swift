//
//  GuideHomeViewController.swift
//  main
//
//    pod 'JXSegmentedView'
//    pod 'JXPagingView/Paging'

import UIKit
import AtomicX
import JXSegmentedView
import JXPagingView
import TUICore

class GuideHomeModel {
    var singlePlayerJsonName: String?
    var withAppJsonName: String?
    var withWebJsonName: String?

    init(singlePlayerJsonName: String? = nil, withAppJsonName: String? = nil, withWebJsonName: String? = nil) {
        self.singlePlayerJsonName = singlePlayerJsonName
        self.withAppJsonName = withAppJsonName
        self.withWebJsonName = withWebJsonName
    }
}

class GuideHomeViewController: UIViewController {

    private let segmentBorderView: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = ThemeStore.shared.colorTokens.strokeColorSecondary
        return view
    }()

    var selectedIndex: Int = 0
    convenience init(selectedIndex: Int,
                     homeJsonData: GuideHomeModel,
                     copyUrl: String,
                     copyUrlEn: String) {
        self.init()
        self.selectedIndex = selectedIndex
        self.viewControllers.append(GuideViewController(viewType: .SinglePlayer,
                                                        jsonFileData: homeJsonData,
                                                        url: copyUrl,
                                                        urlEn: copyUrlEn))
        self.viewControllers.append(GuideViewController(viewType: .MultiPlayerWithWeb,
                                                        jsonFileData: homeJsonData,
                                                        url: copyUrl,
                                                        urlEn: copyUrlEn))
    }

    private var viewControllers: [GuideViewController] = []

    private lazy var dataSource: JXSegmentedDotDataSource = {
        let source = JXSegmentedDotDataSource()
        source.titles = [GuideLocalize("Demo.TRTC.Guide.RoomSingleUser"),
                         GuideLocalize("Demo.TRTC.Guide.RoomMultiUsers")]
        source.dotStates = [false, false]
        source.titleNormalColor = UIColor(red: 98, green: 110, blue: 132, alpha: 0.6)
        source.titleSelectedColor = UIColor(red: 0, green: 108, blue: 255)
        source.titleNormalFont = ThemeStore.shared.typographyTokens.Regular16
        source.titleSelectedFont = ThemeStore.shared.typographyTokens.Regular16
        source.isTitleZoomEnabled = false
        source.isTitleColorGradientEnabled = true
        source.isItemSpacingAverageEnabled = true
        source.itemSpacing = convertPixel(w: 9)
        source.dotSize = CGSize(width: convertPixel(w: 116), height: convertPixel(h: 20))
        source.itemWidth = convertPixel(w: 116)
        source.dotColor = UIColor.red
        return source
    }()

    private lazy var segmentedView: JXSegmentedView = {
        let view = JXSegmentedView(frame: .zero)
        view.backgroundColor = ThemeStore.shared.colorTokens.bgColorOperate
        view.dataSource = dataSource
        view.listContainer = listContainerView
        view.defaultSelectedIndex = selectedIndex
        let indicator = JXSegmentedIndicatorLineView()
        indicator.indicatorHeight = 4
        indicator.indicatorWidth = 84
        indicator.indicatorColor = UIColor(red: 10, green: 109, blue: 217)
        indicator.verticalOffset = 0
        view.indicators = [indicator]
        return view
    }()

    private lazy var listContainerView: JXSegmentedListContainerView = {
        let view = JXSegmentedListContainerView(dataSource: self)
        view.backgroundColor = UIColor.clear
        return view
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ThemeStore.shared.colorTokens.bgColorOperate
        let backBtn = UIButton(type: .custom)
        backBtn.setImage(AppAssemblyBundle.image(named: "calling_back"), for: .normal)
        backBtn.addTarget(self, action: #selector(backBtnClick), for: .touchUpInside)
        let item = UIBarButtonItem(customView: backBtn)
        item.tintColor = UIColor.black
        navigationItem.leftBarButtonItem = item
        self.navigationController?.navigationBar.shadowImage = UIImage()
        constructViewHierarchy()
        activateConstraints()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
    }
}

extension GuideHomeViewController: JXSegmentedListContainerViewDataSource {

    func numberOfLists(in listContainerView: JXSegmentedListContainerView) -> Int {
        if let titleDataSource = segmentedView.dataSource as? JXSegmentedBaseDataSource {
            return titleDataSource.dataSource.count
        }
        return 0
    }

    func listContainerView(_ listContainerView: JXSegmentedListContainerView, initListAt index: Int) -> JXSegmentedListContainerViewListDelegate {
        return viewControllers[index]
    }
}

extension GuideHomeViewController {
    private func constructViewHierarchy() {
        view.addSubview(segmentedView)
        view.addSubview(segmentBorderView)
        view.addSubview(listContainerView)
    }

    private func activateConstraints() {
        let naviFullHeight = navigationFullHeight()
        segmentedView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(navigationFullHeight())
            make.leading.trailing.equalTo(0)
            make.height.equalTo(49)
        }
        segmentBorderView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(naviFullHeight)
            make.left.right.equalToSuperview()
            make.height.equalTo(1)
        }
        listContainerView.snp.makeConstraints { make in
            make.leading.trailing.equalTo(0)
            make.bottom.equalToSuperview()
            make.top.equalTo(segmentedView.snp.bottom)
        }
    }
}

extension GuideHomeViewController {
    @objc func backBtnClick() {
        self.navigationController?.popViewController(animated: true)
    }
}

// MARK: - JXSegmentedListContainerViewListDelegate conformance for GuideViewController

extension GuideViewController: JXPagingViewListViewDelegate, JXSegmentedListContainerViewListDelegate {

    func listView() -> UIView {
        return view
    }

    func listScrollView() -> UIScrollView {
        return UIScrollView() // placeholder; guide page uses its own table scroll
    }

    func listViewDidScrollCallback(callback: @escaping (UIScrollView) -> Void) {
        self.listViewDidScrollCallback = callback
    }

    func listWillAppear() {}
    func listDidAppear() {}
    func listWillDisappear() {}
    func listDidDisappear() {}
}
