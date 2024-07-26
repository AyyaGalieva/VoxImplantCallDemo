//
//  Properties.swift
//  VoxImplantDemo
//
//  Created by Ayya Galieva on 25.07.2024.
//

import os.lock
import Combine

// MARK: - BaseProperty

public class BaseProperty<T>: Hashable {

    public static func == (lhs: BaseProperty<T>, rhs: BaseProperty<T>) -> Bool {
        return lhs === rhs
    }

    public func hash(into hasher: inout Hasher) {
        let hash = Unmanaged.passUnretained(self).toOpaque()
        hasher.combine(hash)
    }

    public var publisher: AnyPublisher<T, Never> {
        storedPublisher.eraseToAnyPublisher()
    }

    var value: T {
        get {
            defer {
                os_unfair_lock_unlock(&lock)
            }
            os_unfair_lock_lock(&lock)
            return storedValue
        }
        set {
            if let valueWriteModifier {
                let modifiedValue = valueWriteModifier.perform(with: newValue)
                os_unfair_lock_lock(&lock)
                storedValue = modifiedValue
                os_unfair_lock_unlock(&lock)
                storedPublisher.send(modifiedValue)
            } else {
                os_unfair_lock_lock(&lock)
                storedValue = newValue
                os_unfair_lock_unlock(&lock)
                storedPublisher.send(newValue)
            }
        }
    }

    private var lock = os_unfair_lock_s()
    private var storedValue: T
    private var storedPublisher = PassthroughSubject<T, Never>()
    private let valueWriteModifier: ActionInputOutput<T, T>?

    init(value: T, valueWriteModifier: ActionInputOutput<T, T>? = nil) {
        self.storedValue = value
        self.valueWriteModifier = valueWriteModifier
    }

    /// without publishing
    func setForced(value: T) {
        if let valueWriteModifier {
            let modifiedValue = valueWriteModifier.perform(with: value)
            os_unfair_lock_lock(&lock)
            storedValue = modifiedValue
            os_unfair_lock_unlock(&lock)
        } else {
            os_unfair_lock_lock(&lock)
            storedValue = value
            os_unfair_lock_unlock(&lock)
        }
    }
}

// MARK: - Property

/// With read only value
public class Property<T>: BaseProperty<T> {
    public internal(set) override var value: T {
        get {
            super.value
        }
        set {
            super.value = newValue
        }
    }
}

// MARK: - MutableProperty

/// With read/write value
public class MutableProperty<T>: Property<T> {

    public override var value: T {
        get {
            super.value
        }
        set {
            super.value = newValue
        }
    }

    public override init(value: T, valueWriteModifier: ActionInputOutput<T, T>? = nil) {
        super.init(value: value, valueWriteModifier: valueWriteModifier)
    }

    /// without publishing
    public override func setForced(value: T) {
        super.setForced(value: value)
    }
}

