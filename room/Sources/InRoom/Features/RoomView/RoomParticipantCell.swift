import UIKit
import SnapKit
import AtomicXCore

class RoomParticipantCell: UICollectionViewCell {

    class var streamType: VideoStreamType { .camera }

    private(set) var tile: RoomParticipantTileView?

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.clipsToBounds = true
        contentView.layer.cornerRadius = RoomVideoFlowLayout.cornerRadius
        applyStyle()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { applyStyle() }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        if let tile, tile.superview === contentView {
            tile.removeFromSuperview()
        }
        tile = nil
    }

    private func applyStyle() {
        contentView.backgroundColor = Self.streamType == .screen
            ? UIColor.roomKitBgInverse
            : UIColor.roomKitBgCanvas
    }
}

// MARK: - public methods

extension RoomParticipantCell {
    func host(_ tile: RoomParticipantTileView) {
        if self.tile === tile, tile.superview === contentView { return }
        if let current = self.tile, current.superview === contentView {
            current.removeFromSuperview()
        }
        self.tile = tile
        contentView.addSubview(tile)
        tile.snp.remakeConstraints { $0.edges.equalToSuperview() }
    }
}

// MARK: - subclasses

final class RoomScreenCell: RoomParticipantCell {

    override class var streamType: VideoStreamType { .screen }
}
