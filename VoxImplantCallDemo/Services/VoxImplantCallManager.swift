//
//  VoxImplantCallManager.swift
//  VoxImplantDemo
//
//  Created by Ayya Galieva on 25.07.2024.
//

import VoxImplantSDK

final class VoxImplantCallManager: NSObject, VIClientCallManagerDelegate, VICallDelegate {

    private struct Consts {
        static let ringtone = (name: "noisecollector-beam", extension: "aiff")
        static let progressTone = (name: "current_us_can", extension: "wav")
        static let reconnectTone = (name: "fennelliott-beeping", extension: "wav")
        static let soundsDirectory = "Sounds"
    }

    struct CallWrapper {

        let call: VICall
        let callee: String
        var displayName: String?
        var state: CallState = .connecting
        var previousState: CallState = .connecting
        let direction: CallDirection
        var duration: TimeInterval {
            call.duration()
        }
        var isMuted: Bool = false
        var isOnHold: Bool = false

        enum CallDirection {
            case incoming
            case outgoing
        }

        enum CallState: Equatable {
            case connecting
            case ringing
            case connected
            case reconnecting
            case ended(reason: CallEndReason)

            enum CallEndReason: Equatable, Error {
                case disconnected
                case failed(message: String)
            }
        }
    }

    private(set) var managedCallWrapper: CallWrapper? {
        willSet {
            if managedCallWrapper?.call != newValue?.call {
                managedCallWrapper?.call.remove(self)
            }
        }
        didSet {
            if let newValue = managedCallWrapper {
                callObserver?(newValue)
            }
            if managedCallWrapper?.call != oldValue?.call {
                managedCallWrapper?.call.add(self)
            }
        }
    }
    var hasManagedCall: Bool {
        managedCallWrapper != nil
    }

    var callObserver: ((CallWrapper) -> Void)?
    var didReceiveIncomingCall: (() -> Void)?

    // MARK: - Private

    private var hasNoManagedCalls: Bool {
        !hasManagedCall
    }

    private var callSettings: VICallSettings {
        let settings = VICallSettings()
        settings.videoFlags = VIVideoFlags.videoFlags(receiveVideo: false, sendVideo: false)
        settings.customData = "iOS"
        var header = ["X-DTMF-Enabled": "true", "X-App-Instance-Id": DeviceInfo.domainUID]
//        if let userId = userDataService.user?.id {
//            header["X-App-User-Id"] = "\(userId)"
//        }
        settings.extraHeaders = header
        return settings
    }

    private var ringtone: VoxImplantLoudAudioFile? = {
        guard let ringtonePath = Bundle.main.path(forResource: Consts.ringtone.name,
                                                  ofType: Consts.ringtone.extension,
                                                  inDirectory: Consts.soundsDirectory) else {
            return nil
        }
        return VoxImplantLoudAudioFile(url: URL(fileURLWithPath: ringtonePath), looped: true)
    }()

    private var progressTone: VIAudioFile? = {
        guard let progressTonePath = Bundle.main.path(forResource: Consts.progressTone.name,
                                                      ofType: Consts.progressTone.extension,
                                                      inDirectory: Consts.soundsDirectory) else {
            return nil
        }
        return VIAudioFile(url: URL(fileURLWithPath: progressTonePath), looped: true)
    }()

    private var reconnectTone: VIAudioFile? = {
        guard let reconnectTonePath = Bundle.main.path(forResource: Consts.reconnectTone.name,
                                                       ofType: Consts.reconnectTone.extension,
                                                       inDirectory: Consts.soundsDirectory) else {
            return nil
        }
        return VIAudioFile(url: URL(fileURLWithPath: reconnectTonePath), looped: true)
    }()

    // MARK: - Life Cycle

    private let client: VIClient
    private let authService: VoxImplantAuthService
//    private let userDataService: UserDataServiceProtocol

    init(client: VIClient,
         authService: VoxImplantAuthService
//         userDataService: UserDataServiceProtocol
    ) {
        self.client = client
        self.authService = authService
//        self.userDataService = userDataService
        super.init()
        self.client.callManagerDelegate = self
    }

    func makeOutgoingCall(to contact: String) throws {
        guard authService.isLoggedIn else {
            throw VoxImplantError.notLoggedIn
        }
        guard hasNoManagedCalls else {
            throw VoxImplantError.alreadyManagingACall
        }
        if let call = client.call(contact, settings: callSettings) {
            managedCallWrapper = CallWrapper(call: call, callee: contact, direction: .outgoing)
        } else {
            throw VoxImplantError.internalError
        }
    }

    func startOutgoingCall() throws {
        guard let call = managedCallWrapper?.call else {
            throw VoxImplantError.hasNoActiveCall
        }
        guard authService.isLoggedIn else {
            throw VoxImplantError.notLoggedIn
        }
        call.start()
        progressTone?.play()
    }

    func makeIncomingCallActive() throws {
        guard let call = managedCallWrapper?.call else {
            throw VoxImplantError.hasNoActiveCall
        }
        guard authService.isLoggedIn else {
            throw VoxImplantError.notLoggedIn
        }
        ringtone?.stop()
        call.answer(with: callSettings)
        if managedCallWrapper?.state == .reconnecting {
            reconnectTone?.play()
        }
    }

    func toggleMute() throws {
        guard let wrapper = managedCallWrapper else {
            throw VoxImplantError.hasNoActiveCall
        }
        wrapper.call.sendAudio = wrapper.isMuted
        managedCallWrapper?.isMuted.toggle()
    }

    func toggleHold(_ completion: @escaping (Error?) -> Void) {
        guard let wrapper = managedCallWrapper else {
            completion(VoxImplantError.hasNoActiveCall)
            return
        }
        wrapper.call.setHold(!wrapper.isOnHold) { [weak self] error in
            if let error {
                completion(error)
            } else {
                self?.managedCallWrapper?.isOnHold.toggle()
                completion(nil)
            }
        }
    }

    func sendDTMF(_ symbol: String) throws {
        guard let wrapper = managedCallWrapper else {
            throw VoxImplantError.hasNoActiveCall
        }
        wrapper.call.sendDTMF(symbol)
    }

    func endCall() throws {
        guard let call = managedCallWrapper?.call else {
            throw VoxImplantError.hasNoActiveCall
        }
        call.hangup(withHeaders: nil)
    }

    func rejectCall() throws {
        guard let call = managedCallWrapper?.call else {
            throw VoxImplantError.hasNoActiveCall
        }
        call.reject(with: VIRejectMode.decline, headers: nil)
    }

    // MARK: - VIClientCallManagerDelegate

    func client(_ client: VIClient,
                didReceiveIncomingCall call: VICall,
                withIncomingVideo video: Bool,
                headers: [AnyHashable: Any]?) {
        if hasManagedCall {
            call.reject(with: .busy, headers: nil)
        } else {
            managedCallWrapper = CallWrapper(call: call,
                                             callee: call.endpoints.first?.user ?? "",
                                             displayName: call.endpoints.first?.userDisplayName,
                                             direction: .incoming)
            didReceiveIncomingCall?()
            ringtone?.configureAudioBeforePlaying()
            ringtone?.play()
        }
    }

    // MARK: - VICallDelegate

    func call(_ call: VICall,
              didConnectWithHeaders headers: [AnyHashable: Any]?) {
        guard let wrapper = managedCallWrapper, call.callId == wrapper.call.callId else {
            return
        }
        managedCallWrapper?.displayName = call.endpoints.first?.userDisplayName ?? call.endpoints.first?.user
        managedCallWrapper?.previousState = wrapper.state
        managedCallWrapper?.state = .connected
    }

    func callDidStartReconnecting(_ call: VICall) {
        guard let wrapper = managedCallWrapper, call.callId == wrapper.call.callId else {
            return
        }
        managedCallWrapper?.previousState = wrapper.state
        managedCallWrapper?.state = .reconnecting
        progressTone?.stop()
        if managedCallWrapper?.direction == .outgoing ||
            managedCallWrapper?.previousState == .connected {
            reconnectTone?.play()
        }
    }

    func callDidReconnect(_ call: VICall) {
        guard call.callId == managedCallWrapper?.call.callId else {
            return
        }
        reconnectTone?.stop()
        switch managedCallWrapper?.previousState {
        case .connecting:
            managedCallWrapper?.state = .connecting
        case .ringing:
            managedCallWrapper?.state = .ringing
            progressTone?.play()
        case .connected:
            managedCallWrapper?.state = .connected
        default:
            break
        }
    }

    func call(_ call: VICall,
              didDisconnectWithHeaders headers: [AnyHashable: Any]?,
              answeredElsewhere: NSNumber) {
        guard let wrapper = managedCallWrapper, call.callId == wrapper.call.callId else {
            return
        }
        managedCallWrapper?.previousState = wrapper.state
        managedCallWrapper?.state = .ended(reason: .disconnected)
        managedCallWrapper = nil
        ringtone?.stop()
        progressTone?.stop()
        reconnectTone?.stop()
    }

    func call(_ call: VICall,
              didFailWithError error: Error,
              headers: [AnyHashable: Any]?) {
        guard let wrapper = managedCallWrapper, call.callId == wrapper.call.callId else {
            return
        }
        managedCallWrapper?.previousState = wrapper.state
        managedCallWrapper?.state = .ended(reason: .failed(message: error.localizedDescription))
        managedCallWrapper = nil
        ringtone?.stop()
        progressTone?.stop()
        reconnectTone?.stop()
    }

    func call(_ call: VICall,
              startRingingWithHeaders headers: [AnyHashable: Any]?) {
        guard let wrapper = managedCallWrapper, call.callId == wrapper.call.callId else {
            return
        }
        managedCallWrapper?.previousState = wrapper.state
        managedCallWrapper?.state = .ringing
        progressTone?.play()
    }

    func callDidStartAudio(_ call: VICall) {
        progressTone?.stop()
    }
}

final class VoxImplantLoudAudioFile: NSObject, VIAudioFileDelegate {

    private var audioFile: VIAudioFile!
    weak var delegate: VIAudioFileDelegate?

    init?(url audioFileURL: URL, looped: Bool) {
        super.init()

        if let audioFile = VIAudioFile(url: audioFileURL, looped: looped) {
            audioFile.delegate = self
            self.audioFile = audioFile
        } else {
            return nil
        }
    }

    func configureAudioBeforePlaying() {
        let audioManager: VIAudioManager = VIAudioManager.shared()

        if audioManager.currentAudioDevice() == VIAudioDevice(type: .receiver) {
            audioManager.select(VIAudioDevice(type: .speaker))
        }
    }

    func deconfigureAudioAfterPlaying() {
        let audioManager: VIAudioManager = VIAudioManager.shared()

        if audioManager.currentAudioDevice() == VIAudioDevice(type: .speaker) {
            audioManager.select(VIAudioDevice(type: .receiver))
        }
    }

    func play() {
        audioFile.play()
    }

    func stop() {
        audioFile.stop()
    }

    // MARK: VIAudioFileDelegate

    func audioFile(_ audioFile: VIAudioFile?, didStopPlaying playbackError: Error?) {
        deconfigureAudioAfterPlaying()
        delegate?.audioFile?(audioFile, didStopPlaying: playbackError)
    }

    func audioFile(_ audioFile: VIAudioFile, didStartPlaying playbackError: Error?) {
        delegate?.audioFile?(audioFile, didStartPlaying: playbackError)
    }
}
