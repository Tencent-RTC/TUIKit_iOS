import UIKit
import SnapKit
import AtomicXCore
import TUICallKit_Swift

final class MessageCallContentView: UIView, MessageContentView {
    private static let horizontalInset = CGFloat(SpacingScheme.iconIconSpacing)

    private static let verticalInset = CGFloat(SpacingScheme.smallSpacing)

    private static let iconTextSpacing = CGFloat(SpacingScheme.smallSpacing)

    private static let audioIconSize = CGSize(width: 22, height: 8)

    private static let videoIconSize = CGSize(width: 22, height: 15)

    private static let textMaxLines = 2

    private let textLabel = UILabel()

    private let iconImageView = UIImageView()

    private var currentMessage: MessageInfo?

    private var currentCallModel: CallMessageModel?

    private var currentIconSize: CGSize = .zero

    // MARK: - Init

    init() {
        super.init(frame: .zero)
        constructViewHierarchy()
        activateConstraints()
        setupViewStyle()
        bindInteraction()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - MessageContentView

    func bind(message: MessageInfo, context: MessageContentContext) {
        guard let callModel = CallMessageParser.parse(message) else {
            currentMessage = nil
            currentCallModel = nil
            textLabel.text = ""
            iconImageView.isHidden = true
            return
        }
        currentMessage = message
        currentCallModel = callModel

        let contentColor = context.isSelf
            ? TUIChatKitTheme.colors.textColorAntiPrimary
            : TUIChatKitTheme.colors.textColorPrimary

        textLabel.text = callModel.displayString(
            senderShowName: MessageListHelper.senderShowName(of: message)
        )
        textLabel.textColor = contentColor

        applyIcon(callModel: callModel, isSelf: context.isSelf, tintColor: contentColor)
        applyContentOrder(isSelf: context.isSelf)
    }

    // MARK: - Re-call（对齐 Android reInitiateCall）

    private func constructViewHierarchy() {
        addSubview(textLabel)
        addSubview(iconImageView)
    }

    private func activateConstraints() {
        textLabel.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().inset(Self.verticalInset)
            make.leading.equalToSuperview().offset(Self.horizontalInset)
            make.trailing.lessThanOrEqualToSuperview().offset(-Self.horizontalInset)
        }
        iconImageView.snp.makeConstraints { make in
            make.centerY.equalTo(textLabel)
        }
    }

    private func setupViewStyle() {
        textLabel.font = FontScheme.caption1Regular
        textLabel.numberOfLines = Self.textMaxLines
        iconImageView.contentMode = .scaleAspectFit
    }

    private func bindInteraction() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
        isUserInteractionEnabled = true
    }

    private func applyIcon(callModel: CallMessageModel, isSelf: Bool, tintColor: UIColor) {
        let iconName: String
        let iconSize: CGSize
        switch callModel.streamMediaType {
        case .voice:
            iconName = "message_call_audio"
            iconSize = Self.audioIconSize
        case .video:
            iconName = "message_call_video"
            iconSize = Self.videoIconSize
        default:
            iconImageView.isHidden = true
            iconImageView.transform = .identity
            return
        }
        iconImageView.isHidden = false
        iconImageView.image = AtomicXChatResources.image(named: iconName)
        iconImageView.tintColor = tintColor

        let shouldMirror = !isSelf && (callModel.streamMediaType == .video || callModel.streamMediaType == .voice)
        iconImageView.transform = shouldMirror ? CGAffineTransform(scaleX: -1, y: 1) : .identity
        currentIconSize = iconSize
    }

    private func applyContentOrder(isSelf: Bool) {
        let iconVisible = !iconImageView.isHidden
        textLabel.snp.remakeConstraints { make in
            make.top.bottom.equalToSuperview().inset(Self.verticalInset)
            if isSelf {
                make.leading.equalToSuperview().offset(Self.horizontalInset)
                if iconVisible {
                    make.trailing.equalTo(iconImageView.snp.leading).offset(-Self.iconTextSpacing)
                } else {
                    make.trailing.equalToSuperview().offset(-Self.horizontalInset)
                }
            } else {
                if iconVisible {
                    make.leading.equalTo(iconImageView.snp.trailing).offset(Self.iconTextSpacing)
                } else {
                    make.leading.equalToSuperview().offset(Self.horizontalInset)
                }
                make.trailing.equalToSuperview().offset(-Self.horizontalInset)
            }
        }
        iconImageView.snp.remakeConstraints { make in
            make.centerY.equalTo(textLabel)
            if iconVisible {
                make.width.equalTo(currentIconSize.width)
                make.height.equalTo(currentIconSize.height)
                if isSelf {
                    make.trailing.equalToSuperview().offset(-Self.horizontalInset)
                } else {
                    make.leading.equalToSuperview().offset(Self.horizontalInset)
                }
            }
        }
    }

    @objc private func handleTap() {
        guard let message = currentMessage, let callModel = currentCallModel else { return }
        let targetUserID: String
        if callModel.isCaller {
            targetUserID = callModel.inviteeList.first ?? message.to.trimmingCharacters(in: .whitespaces)
        } else {
            targetUserID = callModel.caller.trimmingCharacters(in: .whitespaces)
        }
        guard !targetUserID.isEmpty else { return }
        let mediaType: CallMediaType = callModel.streamMediaType == .video ? .video : .audio
        DataReport.reportInteractionMetrics(.chatInvokeCall)
        TUICallKit.createInstance().calls(
            userIdList: [targetUserID],
            mediaType: mediaType,
            params: nil,
            completion: nil
        )
    }
}
