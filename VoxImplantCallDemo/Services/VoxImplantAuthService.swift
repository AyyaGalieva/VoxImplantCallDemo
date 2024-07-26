//
//  VoxImplantAuthService.swift
//  VoxImplantDemo
//
//  Created by Ayya Galieva on 25.07.2024.
//

import VoxImplantSDK

protocol PushTokenHolder {
    var pushToken: Data? { get set }
}

final class VoxImplantAuthService: NSObject, VIClientSessionDelegate, PushTokenHolder {

    private struct Сredentials {
        static let account = "aslobchenko"
        static let appName = "callcenter"
        static let password = "K5kW7q"
        static let user = "iOS@\(Сredentials.appName).\(Сredentials.account).voximplant.com"
    }

    private typealias ConnectCompletion = (Error?) -> Void
    private typealias DisconnectCompletion = (Error?) -> Void

    typealias LoginCompletion = (Error?) -> Void
    typealias LogoutCompletion = (Error?) -> Void

    var possibleToLogin: Bool {
        VoxImplantTokens.areExist && !VoxImplantTokens.areExpired
    }

    var pushToken: Data? {
        willSet {
            guard let pushToken, newValue == nil else {
                return
            }
            client.unregisterVoIPPushNotificationsToken(pushToken)
        }
    }

    var state: VIClientState {
        client.clientState
    }

    var isLoggedIn: Bool {
        state == .loggedIn || state == .reconnecting
    }

    var loggedInUserDisplayName: String?

    // MARK: - Private

    private var connectCompletion: ConnectCompletion?
    private var disconnectCompletion: DisconnectCompletion?

    // MARK: - Life Cycle

    private var client: VIClient

    init(client: VIClient) {
        self.client = client
        super.init()
        client.sessionDelegate = self
    }

    func login(completion: @escaping LoginCompletion) {
        connect { [weak self] error in
            if let error {
                completion(error)
                return
            }

            self?.client.login(
                withUser: Сredentials.user,
                password: Сredentials.password,
                success: { (displayUserName: String, tokens: VIAuthParams?) in
                    if let tokens {
                        VoxImplantTokens.update(with: tokens)
                    }
                    self?.loggedInUserDisplayName = displayUserName
                    if let pushToken = self?.pushToken {
                        self?.client.registerVoIPPushNotificationsToken(pushToken)
                    }
                    completion(nil)
                },
                failure: { (error: Error) in
                    completion(error)
                }
            )
        }
    }

    func loginWithAccessToken(registerPushToken: Bool = true, completion: @escaping LoginCompletion) {
        guard VoxImplantTokens.areExist, !VoxImplantTokens.areExpired else {
            login(completion: completion)
            return
        }
        connect { [weak self] error in
            if let error {
                completion(error)
                return
            }

            self?.updateAccessTokenIfNeeded(for: Сredentials.user) { [weak self] (result: Result<VoxImplantToken, Error>) in
                switch result {
                case let .failure(error):
                    completion(error)
                    return

                case let .success(accessKey):
                    self?.client.login(
                        withUser: Сredentials.user,
                        token: accessKey.token,
                        success: { (displayUserName: String, tokens: VIAuthParams?) in
                            if let tokens {
                                VoxImplantTokens.update(with: tokens)
                            }
                            self?.loggedInUserDisplayName = displayUserName
                            if let pushToken = self?.pushToken,
                               registerPushToken {
                                self?.client.registerVoIPPushNotificationsToken(pushToken)
                            }
                            completion(nil)
                        },
                        failure: { [weak self] error in
                            if error.responseCode == VILoginError.tokenExpired.rawValue {
                                self?.login(completion: completion)
                            } else {
                                completion(error)
                            }
                        }
                    )
                }
            }
        }
    }

    private func updateAccessTokenIfNeeded(for user: String,
                                           _ completion: @escaping (Result<VoxImplantToken, Error>) -> Void) {
        guard let accessToken = VoxImplantTokens.access,
              let refreshToken = VoxImplantTokens.refresh else {
            completion(.failure(VoxImplantError.loginDataNotFound))
            return
        }

        if accessToken.isExpired {
            client.refreshToken(withUser: user, token: refreshToken.token) { (authParams: VIAuthParams?, error: Error?) in
                guard let tokens = authParams else {
                    completion(.failure(error!))
                    return
                }
                VoxImplantTokens.update(with: tokens)
                completion(.success(VoxImplantTokens.access!))
            }
        } else {
            completion(.success(accessToken))
        }
    }

    private func connect(_ completion: @escaping ConnectCompletion) {
        if client.clientState == .disconnected || client.clientState == .connecting {
            connectCompletion = completion
            client.connect(to: VIConnectionNode.node3)
        } else {
            completion(nil)
        }
    }

    private func disconnect(_ completion: @escaping DisconnectCompletion) {
        if client.clientState == .disconnected {
            completion(nil)
        } else {
            disconnectCompletion = completion
            client.disconnect()
        }
    }

    func unregisterPushToken(token: Data, completion: @escaping (Error?) -> Void) {
        client.unregisterVoIPPushNotificationsToken(token) { [weak self] error in
            if let error {
                completion(error)
            } else {
                self?.disconnect(completion)
                self?.loggedInUserDisplayName = nil
                VoxImplantTokens.clear()
            }
        }
    }

    func logout(_ completion: @escaping LogoutCompletion) {
        guard let pushToken else {
            disconnect(completion)
            loggedInUserDisplayName = nil
            VoxImplantTokens.clear()
            return
        }
        if client.clientState != .loggedIn {
            loginWithAccessToken(registerPushToken: false, completion: { [weak self] error in
                if let error {
                    completion(error)
                } else {
                    self?.unregisterPushToken(token: pushToken, completion: completion)
                }
            })
        } else {
            self.unregisterPushToken(token: pushToken, completion: completion)
        }
    }

    // MARK: - VIClientSessionDelegate

    func clientSessionDidConnect(_ client: VIClient) {
        connectCompletion?(nil)
        connectCompletion = nil
    }

    func client(_ client: VIClient, sessionDidFailConnectWithError error: Error) {
        connectCompletion?(error)
        connectCompletion = nil
    }

    func clientSessionDidDisconnect(_ client: VIClient) {
        disconnectCompletion?(nil)
        disconnectCompletion = nil
    }
}

