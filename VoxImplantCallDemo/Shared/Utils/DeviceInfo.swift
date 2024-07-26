//
//  DeviceInfo.swift
//  VoxImplantDemo
//
//  Created by Ayya Galieva on 25.07.2024.
//

import Foundation
import UIKit
import SwiftKeychainWrapper

public class DeviceInfo {

    public static let vendorID = UIDevice.current.identifierForVendor?.uuidString

    public static func domainUID(url: URL) -> String {
        let domainUIDKeychainKey = "domain_uid"

        if let domainUID = KeychainWrapper.standard.string(forKey: domainUIDKeychainKey) {
            return domainUID
        }

        // Migration from Cookies Storage
        let cookieName = "uid"
        if let cookieDomainUID = HTTPCookieStorage.shared.cookies(for: url)?
            .filter({ $0.name == cookieName }).first?
            .value {
            KeychainWrapper.standard.set(cookieDomainUID, forKey: domainUIDKeychainKey)
            return cookieDomainUID
        }

        let domainUID = DomainUIDGenerator().generate(
            withAppPlatform: "appios",
            timestamp: Int(Date().timeIntervalSince1970),
            appVersion: Application.version,
            deviceID: Self.vendorID ?? UUID().uuidString
        )
        KeychainWrapper.standard.set(domainUID, forKey: domainUIDKeychainKey)

        return domainUID
    }

    public static func appInstallDate(domainUID: String) -> Date? {
        guard let data = Data(base64Encoded: domainUID), data.count == 16 else {
            return nil
        }

        let timestampData = data[4..<data.count - 8]
        let firstByte = Int(timestampData[4]) * 2 ^^ 24
        let secondByte = Int(timestampData[5]) * 2 ^^ 16
        let thirdByte = Int(timestampData[6]) * 2 ^^ 8
        let fourthByte = Int(timestampData[7])
        let timestamp = firstByte + secondByte + thirdByte + fourthByte
        return Date(timeIntervalSince1970: TimeInterval(timestamp))
    }
}

extension DeviceInfo {

    static let domainUID: String = domainUID(url: URL(string: "https://mota.p.ostrovok.ru")!)

    static let appInstallDate: Date? = appInstallDate(domainUID: domainUID)
}
