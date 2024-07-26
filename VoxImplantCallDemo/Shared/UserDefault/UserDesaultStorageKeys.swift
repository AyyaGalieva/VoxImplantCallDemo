//
//  UserDesaultStorageKeys.swift
//  VoxImplantCallDemo
//
//  Created by Ayya Galieva on 26.07.2024.
//

import Foundation

public enum UserDefaultsKey: String, CaseIterable {
    case voxImplantTokenAccess = "VoxImplant.Token.Access"
    case voxImplantDateAccess = "VoxImplant.Date.Access"
    case voxImplantTokenRefresh = "VoxImplant.Token.Refresh"
    case voxImplantDateRefresh = "VoxImplant.Date.Refresh"
}

// MARK: Property Wrappers init

public extension UserDefault {

    init(_ key: UserDefaultsKey,
         defaultValue: Value,
         container: UserDefaults = .standard) {
        self.init(key: key.rawValue,
                  defaultValue: defaultValue,
                  container: container)
    }
}

public extension UserDefault where Value: ExpressibleByNilLiteral {

    init(_ key: UserDefaultsKey, container: UserDefaults = .standard) {
        self.init(key: key.rawValue,
                  defaultValue: nil,
                  container: container)
    }
}
