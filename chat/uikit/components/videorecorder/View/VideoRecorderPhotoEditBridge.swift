import UIKit
import SnapKit
import AlbumPickerCore

@objcMembers
final class VideoRecorderPhotoEditBridge: NSObject {

    public static func present(from source: UIViewController,
                               image: UIImage,
                               onConfirm: @escaping (UIImage) -> Void,
                               onCancel: @escaping () -> Void) {
        AlbumPickerCoreTheme.shared.currentPrimaryColor = TUIChatKitTheme.colors.buttonColorPrimaryDefault
        let editor = VideoRecorderPhotoEditViewController(image: image, onConfirm: onConfirm, onCancel: onCancel)
        editor.modalPresentationStyle = .fullScreen
        source.present(editor, animated: true)
    }
}

private final class VideoRecorderPhotoEditViewController: UIViewController {
    override var prefersStatusBarHidden: Bool {
        return true
    }

    private let editView: ImageEditView

    private let onConfirm: (UIImage) -> Void

    private let onCancel: () -> Void

    init(image: UIImage, onConfirm: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
        self.editView = ImageEditView(sourceImage: image)
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(editView)
        editView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        editView.editDelegate = self
    }
}

extension VideoRecorderPhotoEditViewController: ImageEditDelegate {

    func imageEditView(_ editView: ImageEditView, didCompleteWithImage editedImage: UIImage) {
        presentingViewController?.dismiss(animated: false)
        onConfirm(editedImage)
    }

    func imageEditViewDidCancel(_ editView: ImageEditView) {
        dismiss(animated: true) { [onCancel] in
            onCancel()
        }
    }
}
