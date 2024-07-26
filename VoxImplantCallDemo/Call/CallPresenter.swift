//
//  CallPresenter.swift
//  VoxImplantDemo
//
//  Created by Ayya Galieva on 25.07.2024.
//

import Combine
import Darwin
import UIKit

protocol CallPresenterProtocol: AnyObject {

    func viewDidLoad()
    func numPadButtonPressed(symbol: String)
    func speakerButtonPressed()
    func muteButtonPressed()
    func hangUpButtonPressed()
    func cancelButtonPressed()
    func callBackButtonPressed()
}

final class CallPresenter: CallPresenterProtocol {

    private unowned let viewController: CallViewControllerProtocol
    private var voipCallService: VoipCallServiceProtocol

    private var subscriptions = Set<AnyCancellable>()

    init(viewController: CallViewControllerProtocol,
         voipCallService: VoipCallServiceProtocol) {
        self.viewController = viewController
        self.voipCallService = voipCallService

        self.voipCallService.audioDelegate = self
        self.voipCallService.state.publisher
            .receiveForUI()
            .sink { [weak self] state in
                guard let self else {
                    return
                }
                switch state {
                case .connection:
                    self.viewController.isActiveCall = true
                    self.viewController.set(title: "Connecting to the server...")
                case .calling:
                    self.viewController.isActiveCall = true
                    self.viewController.set(title: "Calling...")
                case let .call(duration):
                    self.viewController.isActiveCall = true
                    let formattedDuration = String(format: "%02li:%02li",
                                                   lround(floor(duration / 60)) % 60,
                                                   lround(floor(duration)) % 60)
                    self.viewController.set(title: formattedDuration)
                case let .end(error):
                    self.viewController.isActiveCall = false
                    if error != nil {
                        self.viewController.set(title: "It seems like there is no Internet connection")
                    } else {
                        self.viewController.set(title: "Call disconnected")
                    }
                case .hangUp:
                    self.viewController.isActiveCall = false
                    self.viewController.set(title: "Call ended")
                    self.viewController.dismiss()
                }
            }
            .store(in: &subscriptions)
    }

    deinit {
        if voipCallService.audioDelegate === self {
            voipCallService.audioDelegate = nil
        }
    }

    // MARK: - SupportCallPresenter

    func viewDidLoad() {
        updateSpeakerMode()
        startCall()
    }

    func numPadButtonPressed(symbol: String) {
        voipCallService.sendDTMF(symbol: symbol)
    }

    func hangUpButtonPressed() {
        voipCallService.stopCall()
    }

    func cancelButtonPressed() {
        viewController.dismiss()
    }

    func callBackButtonPressed() {
        startCall()
    }

    func speakerButtonPressed() {
        let audioDevices = voipCallService.getAudioDevices()
        let selectedAudioDevice = voipCallService.getCurrentAudioDevice()

        guard audioDevices.count > 2 else {
            if let newAudioDevice = audioDevices.first(where: { $0 != selectedAudioDevice }) {
                voipCallService.set(audioDevice: newAudioDevice)
            }
            return
        }
        let devicePicker = UIAlertController(
            title: nil,
            message: NSLocalizedString("InternetCall.SelectOutputDevice",
                                       comment: "Text prompting the user to select an audio output device"),
            preferredStyle: UIDevice.current.userInterfaceIdiom == .pad ? .alert : .actionSheet
        )
        audioDevices.forEach { device in
            let action = UIAlertAction(
                title: device.localizedDescription,
                style: .default,
                handler: { [weak self]  _ in
                    self?.voipCallService.set(audioDevice: device)
                })
            action.isEnabled = device != selectedAudioDevice
            devicePicker.addAction(action)
        }
        devicePicker.addAction(UIAlertAction(
            title: NSLocalizedString("Cancel", comment: ""),
            style: .cancel,
            handler: { [weak self] _ in
                self?.updateSpeakerMode()
            }))
        viewController.showDevicePicker(controller: devicePicker)
    }

    func muteButtonPressed() {
        let newState = !viewController.isMuteEnabled
        voipCallService.changeMuteMode(isEnabled: newState)
        viewController.isMuteEnabled = newState
    }

    // MARK: - Private

    private func startCall() {
        try? voipCallService.startCall()
    }

    private func updateSpeakerMode(audioDevice: VoipCallAudioDeviceType? = nil) {
        guard let audioDevice = audioDevice ?? voipCallService.getCurrentAudioDevice() else {
            return
        }
        viewController.set(audioDevice: audioDevice)
    }
}

extension CallPresenter: VoipCallServiceAudioDelegate {

    func audioDeviceChanged(audioDevice: VoipCallAudioDeviceType) {
        updateSpeakerMode(audioDevice: audioDevice)
    }

    func audioDeviceUnavailable() {
        updateSpeakerMode()
    }
}

private extension VoipCallAudioDeviceType {

    var localizedDescription: String {
        switch self {
        case .none:
            return "unknown"
        case .receiver:
            if UIDevice.current.userInterfaceIdiom == .pad {
                return NSLocalizedString("InternetCall.AudioDevice.Receiver.iPad",
                                         comment: "Text describing the audio output device — iPad receiver")
            } else {
                return NSLocalizedString("InternetCall.AudioDevice.Receiver.iPhone",
                                         comment: "Text describing the audio output device — iPhone receiver")
            }
        case .speaker:
            return NSLocalizedString("InternetCall.AudioDevice.Speaker",
                                     comment: "Text describing the audio output device — speaker")
        case .wired:
            return NSLocalizedString("InternetCall.AudioDevice.Wired",
                                     comment: "Text describing the audio output device connected via wire")
        case .bluetooth:
            return NSLocalizedString("InternetCall.AudioDevice.Bluetooth",
                                     comment: "Text describing the audio output device connected via bluetooth")
        }
    }
}
