//
//  VoxImplantError.swift
//  VoxImplantDemo
//
//  Created by Ayya Galieva on 25.07.2024.
//

enum VoxImplantError: Error {

    case audioPermissionDenied
    case videoPermissionDenied

    case loginDataNotFound
    case notLoggedIn

    case internalError
    case alreadyManagingACall
    case hasNoActiveCall

    var localizedDescription: String {
        switch self {
        case .audioPermissionDenied:
            "Record audio permission needed for call to work"
        case .videoPermissionDenied:
            "Record video permission needed for video call to work"
        case .loginDataNotFound:
            "Login data was not found, try to login with password"
        case .notLoggedIn:
            "User is not logged in"
        case .internalError:
            "There was an internal error starting the call. Try again"
        case .alreadyManagingACall:
            "The app already managing a call, only a single call at a time allowed"
        case .hasNoActiveCall:
            "Active call not found, action cancelled"
        }
    }
}
