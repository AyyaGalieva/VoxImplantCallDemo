//
//  VoipCallService.swift
//  VoxImplantDemo
//
//  Created by Ayya Galieva on 25.07.2024.
//

import VoxImplantSDK
import Combine

enum VoipCallAudioDeviceType: String {
    case none
    case receiver
    case speaker
    case wired
    case bluetooth
}

protocol VoipCallServiceProtocol {

    var audioDelegate: VoipCallServiceAudioDelegate? { get set }
    var state: Property<VoipCallServiceState> { get }

    func startCall() throws
    func stopCall()

    func sendDTMF(symbol: String)
    func changeMuteMode(isEnabled: Bool)

    func getCurrentAudioDevice() -> VoipCallAudioDeviceType?
    func getAudioDevices() -> [VoipCallAudioDeviceType]
    func set(audioDevice: VoipCallAudioDeviceType)
}

protocol VoipCallServiceAudioDelegate: AnyObject {

    func audioDeviceChanged(audioDevice: VoipCallAudioDeviceType)
    func audioDeviceUnavailable()
}

enum VoipCallServiceState {
    case connection
    case calling
    case call(duration: Double)
    case end(error: Error?)
    case hangUp
}

final class VoipCallService: NSObject, VoipCallServiceProtocol {

    private struct Consts {
        static let callTimelimit: TimeInterval = 3 * 60 * 60 // 3 hours
    }

    // MARK: - VoipCallServiceDelegate

    weak var audioDelegate: VoipCallServiceAudioDelegate?
    var state: Property<VoipCallServiceState> {
        mutableState
    }

    // MARK: - Private

    private lazy var client = VIClient(delegateQueue: DispatchQueue.main)
    private lazy var authService = VoxImplantAuthService(client: client)
    private lazy var callManager: VoxImplantCallManager = {
        let manager = VoxImplantCallManager(client: client,
                                            authService: authService)
        manager.callObserver = { [weak self] call in
            switch call.state {
            case let .ended(reason):
                self?.mutableState.value = .end(error: reason)
            default:
                break
            }
        }
        return manager
    }()

    private var reconnectSubscription: AnyCancellable?
    private let mutableState: MutableProperty<VoipCallServiceState>
    private var timer: RepeatigTimer?

    // MARK: - Life Cycle

    override init() {
        self.mutableState = MutableProperty(value: VoipCallServiceState.connection)
        super.init()

        VIClient.setLogLevel(.error)
        VIAudioManager.shared().delegate = self
    }

    // MARK: - VoipCallServiceDelegate

    func startCall() throws {
        PermissionsHelper.requestRecordPermissions { [weak self] error in
            guard let self else {
                return
            }
            if let error {
                self.mutableState.value = .end(error: error)
                return
            }
            if !self.authService.isLoggedIn {
                self.reconnect(onSuccess: { [weak self] in
                    self?.makeOutgoingCall()
                })
            } else {
                self.makeOutgoingCall()
            }
        }
    }

    func stopCall() {
        do {
            try callManager.endCall()
            stopCallTimer()
            mutableState.value = .hangUp
        } catch {
            mutableState.value = .end(error: error)
        }
    }

    func sendDTMF(symbol: String) {
        do {
            try callManager.sendDTMF(symbol)
        } catch { }
    }

    func changeMuteMode(isEnabled: Bool) {
        guard let call = callManager.managedCallWrapper,
              call.isMuted != isEnabled else {
            return
        }
        try? callManager.toggleMute()
    }

    func getCurrentAudioDevice() -> VoipCallAudioDeviceType? {
        let viAudioDevice = VIAudioManager.shared().currentAudioDevice()
        if let device = VoipCallAudioDeviceType(deviceType: viAudioDevice.type) {
            return device
        }
        return nil
    }

    func getAudioDevices() -> [VoipCallAudioDeviceType] {
        return VIAudioManager.shared().availableAudioDevices().compactMap {
            VoipCallAudioDeviceType(deviceType: $0.type)
        }
    }

    func set(audioDevice: VoipCallAudioDeviceType) {
        let type: VIAudioDeviceType
        switch audioDevice {
        case .none:
            type = .none
        case .receiver:
            type = .receiver
        case .speaker:
            type = .speaker
        case .wired:
            type = .wired
        case .bluetooth:
            type = .bluetooth
        }
        VIAudioManager.shared().select(VIAudioDevice(type: type))
    }

    // MARK: - Private

    private func startSubsriptionIfNeeded() {
        guard reconnectSubscription == nil else {
            return
        }
        reconnectSubscription = NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                guard let self,
                      !self.authService.isLoggedIn else {
                    return
                }
                self.reconnect()
            }
    }

    private func reconnect(onSuccess: (() -> Void)? = nil) {
        authService.loginWithAccessToken { [weak self] error in
            if let error {
                self?.mutableState.value = .end(error: error)
            } else {
                onSuccess?()
            }
        }
    }

    private func makeOutgoingCall() {
        let voipPhoneNumber = "78000000000"
        startSubsriptionIfNeeded()
        mutableState.value = .calling
        do {
            try callManager.makeOutgoingCall(to: voipPhoneNumber)
            try callManager.startOutgoingCall()
            startCallTimer()
        } catch {
            mutableState.value = .end(error: error)
        }
    }

    private func startCallTimer() {
        stopCallTimer()
        timer = RepeatigTimer(
            endDate: Date().addingTimeInterval(Consts.callTimelimit),
            updateInterval: 1,
            updateAction: ActionInput<TimeInterval> { [weak self] _ in
                guard let self,
                      self.callManager.hasManagedCall,
                      let call = self.callManager.managedCallWrapper,
                      call.duration > 0 else {
                    return
                }
                self.mutableState.value = .call(duration: call.duration)
            }
        )
        timer?.start()
    }

    private func stopCallTimer() {
        timer?.stop()
        timer = nil
    }
}

extension VoipCallService: VIAudioManagerDelegate {

    func audioDeviceChanged(_ audioDevice: VIAudioDevice) {
        if let device = VoipCallAudioDeviceType(deviceType: audioDevice.type) {
            audioDelegate?.audioDeviceChanged(audioDevice: device)
        } else {
            audioDelegate?.audioDeviceUnavailable()
        }
    }

    func audioDeviceUnavailable(_ audioDevice: VIAudioDevice) {
        audioDelegate?.audioDeviceUnavailable()
    }

    func audioDevicesListChanged(_ availableAudioDevices: Set<VIAudioDevice>) { }
}

private extension VoipCallAudioDeviceType {

    init?(deviceType: VIAudioDeviceType) {
        switch deviceType {
        case .none:
            self = .none
        case .receiver:
            self = .receiver
        case .speaker:
            self = .speaker
        case .wired:
            self = .wired
        case .bluetooth:
            self = .bluetooth
        @unknown default:
            return nil
        }
    }
}

private struct PermissionsHelper {

    static func requestRecordPermissions(includingVideo video: Bool = false,
                                         completion: @escaping (Error?) -> Void,
                                         accessRequestCompletionQueue: DispatchQueue = .main) {
        requestPermissions(for: .audio, queue: accessRequestCompletionQueue) { granted in
            if granted {
                if video {
                    requestPermissions(for: .video, queue: accessRequestCompletionQueue) { granted in
                        completion(granted ? nil : VoxImplantError.videoPermissionDenied)
                    }
                    return
                }
                completion(nil)
            } else {
                completion(VoxImplantError.audioPermissionDenied)
            }
        }
    }

    static func requestPermissions(for mediaType: AVMediaType,
                                   queue: DispatchQueue = .main,
                                   completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: mediaType) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: mediaType) { granted in
                queue.async {
                    completion(granted)
                }
            }
        case .authorized:
            completion(true)
        case .denied, .restricted:
            completion(false)
        @unknown default:
            completion(false)
        }
    }
}
