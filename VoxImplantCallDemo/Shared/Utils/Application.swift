//
//  Application.swift
//  VoxImplantDemo
//
//  Created by Ayya Galieva on 25.07.2024.
//

import Foundation

public struct Application {
    public static let version = getPlistValue(key: "CFBundleShortVersionString")

    private static func getPlistValue(bundle: Bundle = Bundle.main,
                                      key: String,
                                      defaultValue: String = "") -> String {
        if let value = bundle.infoDictionary?[key] as? String {
            return value
        }
        return defaultValue
    }
}
