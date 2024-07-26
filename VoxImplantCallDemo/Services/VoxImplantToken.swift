//
//  VoxImplantToken.swift
//  VoxImplantDemo
//
//  Created by Ayya Galieva on 25.07.2024.
//

import VoxImplantSDK

struct VoxImplantToken {

    let token: String
    let expireDate: Date
    var isExpired: Bool {
        Date() > expireDate
    }
}

struct VoxImplantTokens {

    static var access: VoxImplantToken? {
        get {
            if let token = accessToken,
               let date = accessTokenExpireDate {
                return VoxImplantToken(token: token, expireDate: date)
            }
            return nil
        }
        set {
            accessToken = newValue?.token
            accessTokenExpireDate = newValue?.expireDate
        }
    }

    static var areExist: Bool {
        access != nil && refresh != nil
    }

    static var areExpired: Bool {
        guard let access,
              let refresh = refresh else {
            return true
        }
        return access.isExpired || refresh.isExpired
    }

    @UserDefault(.voxImplantTokenAccess)
    private static var accessToken: String?

    @UserDefault(.voxImplantDateAccess)
    private static var accessTokenExpireDate: Date?

    static var refresh: VoxImplantToken? {
        get {
            if let token = refreshToken,
                let date = refreshTokenExprireDate {
                return VoxImplantToken(token: token, expireDate: date)
            }
            return nil
        }
        set {
            refreshToken = newValue?.token
            refreshTokenExprireDate = newValue?.expireDate
        }
    }

    @UserDefault(.voxImplantTokenRefresh)
    private static var refreshToken: String?

    @UserDefault(.voxImplantDateRefresh)
    private static var refreshTokenExprireDate: Date?

    static func clear() {
        access = nil
        refresh = nil
    }

    static func update(with authParams: VIAuthParams) {
        access = VoxImplantToken(
            token: authParams.accessToken,
            expireDate: Date(timeIntervalSinceNow: authParams.accessExpire)
        )
        refresh = VoxImplantToken(
            token: authParams.refreshToken,
            expireDate: Date(timeIntervalSinceNow: authParams.refreshExpire)
        )
    }
}
