//
//  Action.swift
//  VoxImplantDemo
//
//  Created by Ayya Galieva on 25.07.2024.
//

public final class Action: Hashable {

    private let identifier: String
    private let closure: () -> Void

    public init(identifier: String = "", closure: @escaping () -> Void) {
        self.identifier = identifier
        self.closure = closure
    }

    public func perform() {
        closure()
    }

    public static func == (lhs: Action, rhs: Action) -> Bool {
        lhs.identifier == rhs.identifier
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine("Action")
        hasher.combine(identifier)
    }
}

public final class ActionInput<T>: Hashable {

    private let identifier: String
    private let closure: (T) -> Void

    public init(identifier: String = "", closure: @escaping (T) -> Void) {
        self.identifier = identifier
        self.closure = closure
    }

    public func perform(with argument: T) {
        closure(argument)
    }

    public static func == (lhs: ActionInput<T>, rhs: ActionInput<T>) -> Bool {
        lhs.identifier == rhs.identifier
    }

    public func hash(into hasher: inout Hasher) {
        let typeHash = "<\(T.self)>"
        hasher.combine("ActionInput" + typeHash)
        hasher.combine(identifier + typeHash)
    }
}

public final class ActionInputOutput<T, R>: Hashable {

    private let identifier: String
    private let closure: (T) -> R

    public init(identifier: String = "", closure: @escaping (T) -> R) {
        self.identifier = identifier
        self.closure = closure
    }

    public func perform(with argument: T) -> R {
        closure(argument)
    }

    public static func == (lhs: ActionInputOutput<T, R>, rhs: ActionInputOutput<T, R>) -> Bool {
        lhs.identifier == rhs.identifier
    }

    public static func handle(_ closure: @escaping (T) -> R) -> ActionInputOutput<T, R> {
        .init(closure: closure)
    }

    public func hash(into hasher: inout Hasher) {
        let typeHash = "<\(T.self), \(R.self)>"
        hasher.combine("ActionInputOutput" + typeHash)
        hasher.combine(identifier + typeHash)
    }
}
