import UIKit

// MARK: - Constraint wrapper

internal class AlbumPickerConstraint {
    private var layoutConstraints: [NSLayoutConstraint]

    fileprivate init(_ constraints: [NSLayoutConstraint]) {
        layoutConstraints = constraints
    }

    internal func update(offset: CGFloat) {
        for constraint in layoutConstraints {
            constraint.constant = offset
        }
    }

    internal func deactivate() {
        NSLayoutConstraint.deactivate(layoutConstraints)
    }
}

internal typealias Constraint = AlbumPickerConstraint

// MARK: - Editable result

internal class AlbumPickerConstraintEditable {
    fileprivate var layoutConstraints: [NSLayoutConstraint]

    fileprivate init(_ constraints: [NSLayoutConstraint]) {
        layoutConstraints = constraints
    }

    @discardableResult
    internal func offset(_ value: CGFloat) -> AlbumPickerConstraintEditable {
        for constraint in layoutConstraints {
            constraint.constant = value
        }
        return self
    }

    internal var constraint: AlbumPickerConstraint {
        AlbumPickerConstraint(layoutConstraints)
    }
}

// MARK: - Anchor reference

internal struct AlbumPickerViewAnchor {
    fileprivate let attribute: NSLayoutConstraint.Attribute
    fileprivate let item: AnyObject
}

// MARK: - ConstraintItem

internal class AlbumPickerConstraintItem {
    fileprivate weak var maker: AlbumPickerConstraintMaker?
    fileprivate var attributes: [NSLayoutConstraint.Attribute]

    fileprivate init(maker: AlbumPickerConstraintMaker,
                     attributes: [NSLayoutConstraint.Attribute]) {
        self.maker = maker
        self.attributes = attributes
    }

    internal var top: AlbumPickerConstraintItem {
        appending(.top)
    }

    internal var bottom: AlbumPickerConstraintItem {
        appending(.bottom)
    }

    internal var leading: AlbumPickerConstraintItem {
        appending(.leading)
    }

    internal var trailing: AlbumPickerConstraintItem {
        appending(.trailing)
    }

    internal var centerX: AlbumPickerConstraintItem {
        appending(.centerX)
    }

    internal var centerY: AlbumPickerConstraintItem {
        appending(.centerY)
    }

    internal var width: AlbumPickerConstraintItem {
        appending(.width)
    }

    internal var height: AlbumPickerConstraintItem {
        appending(.height)
    }

    private func appending(_ attr: NSLayoutConstraint.Attribute) -> AlbumPickerConstraintItem {
        attributes.append(attr)
        return self
    }

    @discardableResult
    internal func equalToSuperview() -> AlbumPickerConstraintEditable {
        guard let maker else { fatalError("ConstraintItem: maker is nil") }
        return maker.applyToSuperview(attributes: attributes, relation: .equal)
    }

    @discardableResult
    internal func equalTo(_ target: Any) -> AlbumPickerConstraintEditable {
        guard let maker else { fatalError("ConstraintItem: maker is nil") }
        return maker.applyTo(target: target, attributes: attributes)
    }
}

// MARK: - ConstraintMaker

internal class AlbumPickerConstraintMaker {
    fileprivate let view: UIView
    private var pending: [NSLayoutConstraint] = []

    fileprivate init(view: UIView) {
        self.view = view
        view.translatesAutoresizingMaskIntoConstraints = false
    }

    internal var top: AlbumPickerConstraintItem {
        item(.top)
    }

    internal var bottom: AlbumPickerConstraintItem {
        item(.bottom)
    }

    internal var leading: AlbumPickerConstraintItem {
        item(.leading)
    }

    internal var trailing: AlbumPickerConstraintItem {
        item(.trailing)
    }

    internal var centerX: AlbumPickerConstraintItem {
        item(.centerX)
    }

    internal var centerY: AlbumPickerConstraintItem {
        item(.centerY)
    }

    internal var width: AlbumPickerConstraintItem {
        item(.width)
    }

    internal var height: AlbumPickerConstraintItem {
        item(.height)
    }

    internal var center: AlbumPickerConstraintItem {
        item(.centerX, .centerY)
    }

    internal var edges: AlbumPickerConstraintItem {
        item(.top, .leading, .trailing, .bottom)
    }

    private func item(_ attrs: NSLayoutConstraint.Attribute...) -> AlbumPickerConstraintItem {
        AlbumPickerConstraintItem(maker: self, attributes: attrs)
    }

    fileprivate func activateAll() {
        NSLayoutConstraint.activate(pending)
    }

    fileprivate func applyToSuperview(
        attributes: [NSLayoutConstraint.Attribute],
        relation: NSLayoutConstraint.Relation
    ) -> AlbumPickerConstraintEditable {
        guard let superview = view.superview else { fatalError("No superview") }
        var result: [NSLayoutConstraint] = []
        for attr in attributes {
            let constraint = NSLayoutConstraint(
                item: view, attribute: attr, relatedBy: relation,
                toItem: superview, attribute: attr, multiplier: 1, constant: 0
            )
            result.append(constraint)
        }
        pending.append(contentsOf: result)
        return AlbumPickerConstraintEditable(result)
    }

    fileprivate func applyTo(
        target: Any,
        attributes: [NSLayoutConstraint.Attribute]
    ) -> AlbumPickerConstraintEditable {
        var result: [NSLayoutConstraint] = []

        if let constant = target as? CGFloat {
            result = makeDimensions(attributes: attributes, constant: constant)
        } else if let constant = target as? Int {
            result = makeDimensions(attributes: attributes, constant: CGFloat(constant))
        } else if let constant = target as? Double {
            result = makeDimensions(attributes: attributes, constant: CGFloat(constant))
        } else if let anchor = target as? AlbumPickerViewAnchor {
            for attr in attributes {
                result.append(NSLayoutConstraint(
                    item: view, attribute: attr, relatedBy: .equal,
                    toItem: anchor.item, attribute: anchor.attribute,
                    multiplier: 1, constant: 0
                ))
            }
        } else if let targetView = target as? UIView {
            for attr in attributes {
                result.append(NSLayoutConstraint(
                    item: view, attribute: attr, relatedBy: .equal,
                    toItem: targetView, attribute: attr,
                    multiplier: 1, constant: 0
                ))
            }
        } else if let guide = target as? UILayoutGuide {
            for attr in attributes {
                result.append(NSLayoutConstraint(
                    item: view, attribute: attr, relatedBy: .equal,
                    toItem: guide, attribute: attr,
                    multiplier: 1, constant: 0
                ))
            }
        } else {
            fatalError("Unsupported target: \(type(of: target))")
        }

        pending.append(contentsOf: result)
        return AlbumPickerConstraintEditable(result)
    }

    private func makeDimensions(
        attributes: [NSLayoutConstraint.Attribute], constant: CGFloat
    ) -> [NSLayoutConstraint] {
        attributes.map { attr in
            NSLayoutConstraint(
                item: view, attribute: attr, relatedBy: .equal,
                toItem: nil, attribute: .notAnAttribute,
                multiplier: 1, constant: constant
            )
        }
    }
}

// MARK: - UIView.snp

internal struct AlbumPickerLayoutProxy {
    fileprivate let view: UIView

    internal var top: AlbumPickerViewAnchor {
        .init(attribute: .top, item: view)
    }

    internal var bottom: AlbumPickerViewAnchor {
        .init(attribute: .bottom, item: view)
    }

    internal var leading: AlbumPickerViewAnchor {
        .init(attribute: .leading, item: view)
    }

    internal var trailing: AlbumPickerViewAnchor {
        .init(attribute: .trailing, item: view)
    }

    internal var centerX: AlbumPickerViewAnchor {
        .init(attribute: .centerX, item: view)
    }

    internal var centerY: AlbumPickerViewAnchor {
        .init(attribute: .centerY, item: view)
    }

    internal func makeConstraints(_ closure: (AlbumPickerConstraintMaker) -> Void) {
        let maker = AlbumPickerConstraintMaker(view: view)
        closure(maker)
        maker.activateAll()
    }
}

internal extension UIView {
    var snp: AlbumPickerLayoutProxy {
        AlbumPickerLayoutProxy(view: self)
    }
}

// MARK: - UILayoutGuide.snp

internal struct AlbumPickerGuideProxy {
    fileprivate let guide: UILayoutGuide

    internal var top: AlbumPickerViewAnchor {
        .init(attribute: .top, item: guide)
    }

    internal var bottom: AlbumPickerViewAnchor {
        .init(attribute: .bottom, item: guide)
    }
}

internal extension UILayoutGuide {
    var snp: AlbumPickerGuideProxy {
        AlbumPickerGuideProxy(guide: self)
    }
}
