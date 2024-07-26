//
//  CallViewController.swift
//  VoxImplantDemo
//
//  Created by Ayya Galieva on 25.07.2024.
//

import SnapKit
import UIKit

protocol CallViewControllerProtocol: AnyObject {

    var isActiveCall: Bool { get set }
    var isMuteEnabled: Bool { get set }

    func set(title: String)
    func set(audioDevice: VoipCallAudioDeviceType)
    func dismiss()
    func showDevicePicker(controller: UIViewController)
}

final class CallViewController: UIViewController, CallViewControllerProtocol {

    var presenter: CallPresenterProtocol!

    // MARK: - SupportCallViewController

    var isActiveCall = true {
        didSet {
            if oldValue != isActiveCall {
                updateCallState()
            }
        }
    }
    var isMuteEnabled = false {
        didSet {
            muteButton.isEnabled = true
            if oldValue != isMuteEnabled {
                muteButton.isSelected = isMuteEnabled
            }
        }
    }

    // MARK: - Private

    private struct Consts {
        static let betweenBlocksOffset: CGFloat = 30
        static let betweenOffset: CGFloat = 20
        static let buttonSize: CGFloat = 70
        static let smallButtonSize: CGFloat = 60
    }

    private lazy var titleLabel: UILabel = {
        let view = UILabel()
        view.textColor = .black
        view.font = .systemFont(ofSize: 18)
        view.textAlignment = .center
        view.numberOfLines = 0
        return view
    }()

    private lazy var titleContainer: UIView = {
        let view = UIView()
        return view
    }()
    private lazy var numPadPadContainer: UIView = {
        let view = UIView()
        view.alpha = 0
        return view
    }()
    private lazy var activeCallButtonsContainer: UIView = {
        let view = UIView()
        return view
    }()
    private lazy var inactiveCallButtonsContainer: UIView = {
        let view = UIView()
        view.isHidden = true
        return view
    }()

    private lazy var numPadButtons: [UIButton] = {
        var buttons: [UIButton] = []
        for index in 1...9 {
            buttons.append(makeNumPadButton(symbol: String(index)))
        }
        // These are different asterisks, one for layout and one for correct DTMF operation
        buttons.append(makeNumPadButton(symbol: "∗", dtmfSymbol: "*"))
        buttons.append(makeNumPadButton(symbol: "0"))
        buttons.append(makeNumPadButton(symbol: "#"))
        return buttons
    }()

    private lazy var speakerButton: UIButton = {
        let view = makeCallSettingsButton()
        view.setImage(UIImage(named: "callSpeaker"), for: .normal)
        view.addTarget(self, action: #selector(didTapSpeakerButton), for: .touchUpInside)
        return view
    }()
    private lazy var numPadButton: UIButton = {
        let view = makeCallSettingsButton()
        view.setImage(UIImage(named: "callNumPad"), for: .normal)
        view.addTarget(self, action: #selector(didTapNumPadButton), for: .touchUpInside)
        return view
    }()
    private lazy var muteButton: UIButton = {
        let view = makeCallSettingsButton()
        view.setImage(UIImage(named: "callMute"), for: .normal)
        view.addTarget(self, action: #selector(didTapMuteButton), for: .touchUpInside)
        return view
    }()

    private lazy var hangUpButton: UIButton = {
        let view = HighlightedButton()
        view.setImage(UIImage(named: "callHangUp"), for: .normal)
        view.setBackgroundColor(.red, for: .normal)
        view.layer.masksToBounds = true
        view.addTarget(self, action: #selector(didTapHangUpButton), for: .touchUpInside)
        return view
    }()
    private lazy var callBackButton: UIButton = {
        let view = HighlightedButton()
        view.setImage(UIImage(named: "callBack"), for: .normal)
        view.addTarget(self, action: #selector(didTapCallBackButton), for: .touchUpInside)
        return view
    }()
    private lazy var cancellButton: UIButton = {
        let view = HighlightedButton()
        view.setImage(UIImage(named: "callCancel"), for: .normal)
        view.addTarget(self, action: #selector(didTapCancelButton), for: .touchUpInside)
        return view
    }()

    private var titleContainerBottomToNumPadConstraint: Constraint?
    private var titleContainerBottomToActiveConstraint: Constraint?

    private var titleCenterYForNumPadConstraint: Constraint?
    private var titleCenterYForActiveConstraint: Constraint?

    // MARK: - Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .white

        addSubviews()
        addConstraints()

        presenter?.viewDidLoad()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        for button in numPadButtons + [speakerButton, numPadButton, muteButton, hangUpButton] {
            button.layer.cornerRadius = button.bounds.width / 2
        }
    }

    // MARK: - Public

    func set(title: String) {
        titleLabel.text = title
    }

    func set(audioDevice: VoipCallAudioDeviceType) {
        speakerButton.isEnabled = true
        switch audioDevice {
        case .none, .receiver, .wired:
            speakerButton.isSelected = false
            speakerButton.setImage(UIImage(named: "callSpeaker"), for: .normal)
        case .speaker:
            speakerButton.isSelected = true
            speakerButton.setImage(UIImage(named: "callSpeaker"), for: .normal)
        case .bluetooth:
            speakerButton.isSelected = true
            speakerButton.setImage(UIImage(named: "callSpeakerBluetooth"), for: .normal)
        }
    }

    func dismiss() {
        self.dismiss(animated: true)
    }

    func showDevicePicker(controller: UIViewController) {
        self.present(controller, animated: true)
    }

    // MARK: - Private

    // MARK: - Configuration

    private func addSubviews() {
        for container in [titleContainer, numPadPadContainer, activeCallButtonsContainer, inactiveCallButtonsContainer] {
            view.addSubview(container)
        }

        titleContainer.addSubview(titleLabel)

        for button in numPadButtons {
            numPadPadContainer.addSubview(button)
        }

        for button in [speakerButton, numPadButton, muteButton, hangUpButton] {
            activeCallButtonsContainer.addSubview(button)
        }

        inactiveCallButtonsContainer.addSubview(cancellButton)
        inactiveCallButtonsContainer.addSubview(callBackButton)
    }

    private func addConstraints() {
        titleContainer.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            $0.leading.trailing.equalToSuperview()

            titleContainerBottomToNumPadConstraint = $0.bottom.equalTo(numPadPadContainer.snp.top).priority(.medium).constraint
            titleContainerBottomToNumPadConstraint?.deactivate()
            titleContainerBottomToActiveConstraint = $0.bottom.equalTo(activeCallButtonsContainer.snp.top).priority(.high).constraint
            titleContainerBottomToActiveConstraint?.activate()
        }

        numPadPadContainer.snp.makeConstraints {
            $0.bottom.equalTo(activeCallButtonsContainer.snp.top).offset(-Consts.betweenBlocksOffset)
            $0.centerX.equalToSuperview()
        }
        activeCallButtonsContainer.snp.makeConstraints {
            $0.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-20)
            $0.leading.trailing.equalToSuperview()
        }
        inactiveCallButtonsContainer.snp.makeConstraints {
            $0.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-15)
            $0.leading.trailing.equalToSuperview()
        }

        titleLabel.snp.makeConstraints {
            titleCenterYForNumPadConstraint = $0.centerY.equalToSuperview().priority(.medium).constraint
            titleCenterYForNumPadConstraint?.deactivate()
            titleCenterYForActiveConstraint = $0.centerY.equalToSuperview().multipliedBy(0.7).priority(.high).constraint
            titleCenterYForActiveConstraint?.activate()
            $0.leading.equalTo(view.layoutMarginsGuide.snp.leading)
            $0.trailing.equalTo(view.layoutMarginsGuide.snp.trailing)
        }

        speakerButton.snp.makeConstraints {
            $0.centerY.equalTo(numPadButton.snp.centerY)
            $0.trailing.equalTo(numPadButton.snp.leading).offset(-Consts.betweenOffset)
            $0.size.equalTo(Consts.smallButtonSize)
        }
        muteButton.snp.makeConstraints {
            $0.centerY.equalTo(numPadButton.snp.centerY)
            $0.leading.equalTo(numPadButton.snp.trailing).offset(Consts.betweenOffset)
            $0.size.equalTo(Consts.smallButtonSize)
        }
        numPadButton.snp.makeConstraints {
            $0.top.equalToSuperview()
            $0.bottom.equalTo(hangUpButton.snp.top).offset(-Consts.betweenBlocksOffset)
            $0.centerX.equalToSuperview()
            $0.size.equalTo(Consts.smallButtonSize)
        }
        hangUpButton.snp.makeConstraints {
            $0.bottom.centerX.equalToSuperview()
            $0.size.equalTo(Consts.buttonSize)
        }

        cancellButton.snp.makeConstraints {
            $0.top.bottom.equalToSuperview()
            $0.leading.equalToSuperview().offset(60)
            $0.size.equalTo(Consts.buttonSize)
        }
        callBackButton.snp.makeConstraints {
            $0.top.bottom.equalToSuperview()
            $0.trailingMargin.equalToSuperview().offset(-60)
            $0.size.equalTo(Consts.buttonSize)
        }

        for (index, button) in numPadButtons.enumerated() {
            button.snp.makeConstraints {
                $0.size.equalTo(Consts.buttonSize)
                if 0...2 ~= index {
                    $0.top.equalToSuperview()
                } else {
                    $0.top.equalTo(numPadButtons[index - 3].snp.bottom).offset(Consts.betweenOffset)
                }
                if index == numPadButtons.count - 1 {
                    $0.bottom.equalToSuperview()
                }
                if index % 3 == 0 {
                    $0.leading.equalToSuperview()
                } else {
                    $0.leading.equalTo(numPadButtons[index - 1].snp.trailing).offset(Consts.betweenOffset)
                    if index % 3 == 2 {
                        $0.trailing.equalToSuperview()
                    }
                }
            }
        }
    }

    // MARK: - State

    private func updateNumPadState() {
        UIView.animate(withDuration: 0.3, delay: 0, options: [.allowUserInteraction, .transitionCrossDissolve], animations: {
            if self.numPadButton.isSelected {
                self.numPadPadContainer.alpha = 1
                self.titleCenterYForNumPadConstraint?.activate()
                self.titleCenterYForActiveConstraint?.deactivate()
                self.titleContainerBottomToNumPadConstraint?.activate()
                self.titleContainerBottomToActiveConstraint?.deactivate()
            } else {
                self.numPadPadContainer.alpha = 0
                self.titleCenterYForActiveConstraint?.activate()
                self.titleCenterYForNumPadConstraint?.deactivate()
                self.titleContainerBottomToActiveConstraint?.activate()
                self.titleContainerBottomToNumPadConstraint?.deactivate()
            }
            self.view.layoutIfNeeded()
        })
    }

    private func updateCallState() {
        if isActiveCall {
            numPadPadContainer.isHidden = false
            activeCallButtonsContainer.isHidden = false
            inactiveCallButtonsContainer.isHidden = true
        } else {
            numPadButton.isSelected = false
            updateNumPadState()

            numPadPadContainer.isHidden = true
            activeCallButtonsContainer.isHidden = true
            inactiveCallButtonsContainer.isHidden = false
        }
    }

    // MARK: - Helpers

    private func makeCallSettingsButton() -> UIButton {
        let backgroundColor: UIColor = .blue
        let button = ConfigurableButton(selectedState: .init(imageTintColor: .white,
                                                             backgroundColor: backgroundColor,
                                                             shouldShowBorder: false),
                                        normalState: .init(imageTintColor: .black,
                                                           backgroundColor: .white,
                                                           shouldShowBorder: true),
                                        borderColor: .lightGray)
        button.layer.masksToBounds = true
        return button
    }

    private func makeNumPadButton(symbol: String, dtmfSymbol: String? = nil) -> UIButton {
        let view = HighlightedButton()
        view.titleLabel?.font = .systemFont(ofSize: 28, weight: .regular)
        view.setTitle(symbol, for: .normal)
        view.setTitleColor(.black, for: .normal)
        view.setBackgroundColor(.lightGray, for: .normal)
        view.layer.masksToBounds = true
        view.addHandler(for: .touchUpInside, handler: { [weak self] _ in
            self?.presenter?.numPadButtonPressed(symbol: dtmfSymbol ?? symbol)
        })
        return view
    }

    // MARK: - Actions

    @objc
    private func didTapSpeakerButton() {
        speakerButton.isEnabled = false
        presenter?.speakerButtonPressed()
    }

    @objc
    private func didTapNumPadButton() {
        numPadButton.isSelected.toggle()
        updateNumPadState()
    }

    @objc
    private func didTapMuteButton() {
        muteButton.isEnabled = false
        presenter?.muteButtonPressed()
    }

    @objc
    private func didTapHangUpButton() {
        presenter?.hangUpButtonPressed()
    }

    @objc
    private func didTapCallBackButton() {
        presenter?.callBackButtonPressed()
    }

    @objc
    private func didTapCancelButton() {
        presenter?.cancelButtonPressed()
    }
}
