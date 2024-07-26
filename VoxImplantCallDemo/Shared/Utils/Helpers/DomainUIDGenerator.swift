//
//  DomainUIDGenerator.swift
//  VoxImplantDemo
//
//  Created by Ayya Galieva on 25.07.2024.
//

import CryptoKit
import Foundation

final class DomainUIDGenerator {

    init() {}

    func generate(withAppPlatform appPlatform: String, timestamp: Int, appVersion: String, deviceID: String) -> String {
        return [
            firstFourBytesOfMD5(from: appPlatform),
            pack(timestamp: timestamp),
            firstFourBytesOfMD5(from: appVersion),
            firstFourBytesOfMD5(from: deviceID)
            ]
            .reduce(Data()) { (fullData, partData) in
                var mutableFullData = fullData
                mutableFullData.append(partData)

                return mutableFullData
            }
            .base64EncodedString()
    }

    private func firstFourBytesOfMD5(from string: String) -> Data {
        guard let data = string.data(using: .utf8) else {
            fatalError("Failed to convert \(string) to data")
        }

        let hash = Insecure.MD5.hash(data: data)
        return Data(hash).prefix(through: 3)
    }

    private func pack(timestamp: Int) -> Data {
        // swiftlint:disable operator_usage_whitespace
        let firstByte = timestamp / 2^^24
        let secondByte = (timestamp - firstByte * 2^^24) / 2^^16
        let thirdByte = (timestamp - firstByte * 2^^24 - secondByte * 2^^16) / 2^^8
        let fourthByte = timestamp - firstByte * 2^^24 - secondByte * 2^^16 - thirdByte * 2^^8
        // swiftlint:enable operator_usage_whitespace

        let bytes = [firstByte, secondByte, thirdByte, fourthByte].map { UInt8($0) }

        return Data(bytes)
    }
}

precedencegroup PowerPrecedence { higherThan: MultiplicationPrecedence }
infix operator ^^ : PowerPrecedence
func ^^ (radix: Int, power: Int) -> Int {
    return Int(pow(Double(radix), Double(power)))
}
