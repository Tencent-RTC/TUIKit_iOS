//
//  RoomTimeZoneSelectViewController.swift
//  TUIRoomKit
//
//  Created by adamsfliu on 2026/7/28.
//  Copyright © 2026 Tencent. All rights reserved.
//
//

import UIKit

public class RoomTimeZoneSelectViewController: UIViewController, RouterContext {
    
    // MARK: - Public API
    
    public var onSelected: ((String, TimeZone) -> Void)? {
        didSet { timeZoneSelectView.onSelected = onSelected }
    }
    
    // MARK: - Properties
    
    private let selectedIdentifier: String?
    private let allTimeZones: [TimeZone]
    
    private lazy var timeZoneSelectView: RoomTimeZoneSelectView = {
        let view = RoomTimeZoneSelectView(
            selectedTimeZoneIdentifier: selectedIdentifier,
            allTimeZones: allTimeZones
        )
        view.routerContext = self
        return view
    }()
    
    // MARK: - Init
    
    public init(selectedTimeZoneIdentifier: String?) {
        self.selectedIdentifier = selectedTimeZoneIdentifier
        self.allTimeZones = RoomTimeZoneSelectViewController.buildSortedTimeZones()
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    public override func loadView() {
        view = timeZoneSelectView
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    public override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    
    public override var shouldAutorotate: Bool {
        return false
    }
    
    public override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .portrait
    }
}

// MARK: - Helpers

extension RoomTimeZoneSelectViewController {
    
    static func buildSortedTimeZones() -> [TimeZone] {
        let ids = TimeZone.knownTimeZoneIdentifiers
        let zones = ids.compactMap { TimeZone(identifier: $0) }
        return zones.sorted { lhs, rhs in
            if lhs.secondsFromGMT() != rhs.secondsFromGMT() {
                return lhs.secondsFromGMT() < rhs.secondsFromGMT()
            }
            return lhs.identifier < rhs.identifier
        }
    }
    
    public static func displayString(for tz: TimeZone) -> String {
        let seconds = tz.secondsFromGMT()
        let sign = seconds >= 0 ? "+" : "-"
        let abs = Swift.abs(seconds)
        let hours = abs / 3600
        let minutes = (abs % 3600) / 60
        let gmt = String(format: "GMT%@%02d:%02d", sign, hours, minutes)
        let locale = Locale.current
        let name = tz.localizedName(for: .standard, locale: locale) ?? tz.identifier
        return "(\(gmt)) \(name)"
    }
}
