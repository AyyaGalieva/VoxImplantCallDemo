//
//  UserDefaultsPropertyWrapper.swift
//  VoxImplantDemo
//
//  Created by Ayya Galieva on 25.07.2024.
//

import Combine
import Foundation

@propertyWrapper
public struct UserDefault<Value> {

    private let key: String
    private let defaultValue: Value
    private let container: UserDefaults

    private let publisher = PassthroughSubject<Value, Never>()

    public var wrappedValue: Value {
        get {
            return container.object(forKey: key) as? Value ?? defaultValue
        }
        set {
            if let optional = newValue as? AnyOptional, optional.isNil {
                container.removeObject(forKey: key)
            } else {
                container.set(newValue, forKey: key)
            }
            publisher.send(newValue)
        }
    }

    public var projectedValue: AnyPublisher<Value, Never> {
        publisher.eraseToAnyPublisher()
    }

    public init(key: String,
                defaultValue: Value,
                container: UserDefaults = .standard) {
        self.key = key
        self.defaultValue = defaultValue
        self.container = container
    }
}
