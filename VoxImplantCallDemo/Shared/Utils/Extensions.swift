//
//  Extensions.swift
//  VoxImplantDemo
//
//  Created by Ayya Galieva on 25.07.2024.
//

import UIKit
import Combine

// MARK: - UIExtensions

private var controlHandlerKey: Int8 = 0

public extension UIImage {

    static func imageWithColor(_ color: UIColor, size: CGSize = .init(width: 1, height: 1)) -> UIImage {
        let rect = CGRect(origin: CGPoint.zero, size: size)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        color.setFill()
        UIRectFill(rect)
        let image: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return image
    }
}

extension UIButton {

    public func setBackgroundColor(_ color: UIColor, for state: UIControl.State) {
        self.setBackgroundImage(UIImage.imageWithColor(color), for: state)
    }
}

extension UIControl {

    public func addHandler(for controlEvents: UIControl.Event, handler: @escaping (UIControl) -> Void) {
        removeHandlers(for: controlEvents)

        let target = CocoaTarget<UIControl>(handler)
        objc_setAssociatedObject(self, &controlHandlerKey, target, .OBJC_ASSOCIATION_RETAIN)
        self.addTarget(target, action: #selector(target.sendNext), for: controlEvents)
    }

    public func removeHandlers(for controlEvents: UIControl.Event) {
        if let oldTarget = objc_getAssociatedObject(self, &controlHandlerKey) as? CocoaTarget<UIControl> {
            self.removeTarget(oldTarget, action: #selector(oldTarget.sendNext), for: controlEvents)
        }
    }
}

final class CocoaTarget<Value>: NSObject {

    init(_ action: @escaping (Value) -> Void) {
        self.action = action
    }

    @objc
    func sendNext(_ receiver: Any?) {
        action(receiver as! Value)
    }

    private let action: (Value) -> Void
}

// MARK: - AnyPublishable

extension Publisher {

    public func receiveForUI() -> AnyPublisher<Output, Failure> {
        receive(on: DispatchQueue.main).eraseToAnyPublisher()
    }
}

// MARK: - Task

extension Task where Success == Never, Failure == Never {

    public static func sleep(seconds: TimeInterval) async throws {
        let oneSecond: TimeInterval = 1_000_000_000
        let delay = oneSecond * seconds
        try await Task<Never, Never>.sleep(nanoseconds: UInt64(delay))
    }
}

// MARK: - AnyOptional

public protocol AnyOptional {
    /// Returns `true` if `nil`, otherwise `false`.
    var isNil: Bool { get }
}

extension Optional: AnyOptional {

    public var isNil: Bool { self == nil }
}

// MARK: - Error

public extension Error {

    var code: Int {
        (self as NSError).code
    }
}

public extension Error {

    var responseCode: Int {
        if let error = self as? ErrorResponseProtocol {
            return error.responseCode ?? 0
        }
        return self.code
    }
}

public protocol ErrorResponseProtocol: Error {

    var responseCode: Int? { get }
}
