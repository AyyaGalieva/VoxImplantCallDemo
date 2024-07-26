//
//  RepeatingTimer.swift
//  VoxImplantDemo
//
//  Created by Ayya Galieva on 25.07.2024.
//

import Combine
import UIKit

public final class RepeatigTimer {

    // MARK: - Public

    /// accuracy corresponds to the update interval
    public var timeLeft: TimeInterval {
        counterValue
    }

    // MARK: - Private

    private weak var timer: Timer?

    private var isTimerStarted: Bool = false

    private var counterValue: TimeInterval {
        didSet {
            guard oldValue != counterValue else {
                return
            }
            updateAction.perform(with: counterValue)
            if counterValue == 0 {
                stop()
                if let completion {
                    completion.perform()
                    self.completion = nil
                }
            }
        }
    }

    private var subscriptions = Set<AnyCancellable>()
    private var shortTimerTask: Task<Void, Error>?

    // MARK: - Life Cycle

    private var resignDate: Date?
    private let updateInterval: TimeInterval
    private var updateAction: ActionInput<TimeInterval>
    private var completion: Action?

    /// - Parameters:
    ///   - endDate: Timer end date
    ///   - timeInterval: Timer time interval
    ///   - updateAction: A closure to execute once every `timeInterval` seconds until the `endDate` is reached and returns the number of seconds until the timer ends
    public init(endDate: Date, updateInterval: TimeInterval, updateAction: ActionInput<TimeInterval>, completion: Action? = nil) {
        self.updateInterval = updateInterval
        self.updateAction = updateAction
        self.counterValue = Date().distance(to: endDate)
        self.completion = completion

        setupActiveNotification()
    }

    deinit {
        invalidateTimer()
    }

    // MARK: - Public

    public func start() {
        guard !isTimerStarted, counterValue > 0 else {
            return
        }

        isTimerStarted = true
        startTimer()
    }

    public func stop() {
        isTimerStarted = false
        invalidateTimer()
    }

    // MARK: - Private

    private func setupTimer() {
        guard timer == nil, counterValue > 0 else {
            return
        }

        timer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            guard let self else {
                return
            }
            reduceCounter(by: updateInterval)
        }
    }

    private func invalidateTimer() {
        shortTimerTask?.cancel()
        timer?.invalidate()
        timer = nil
    }

    private func startTimer() {
        let secondsForNextСycle = counterValue.truncatingRemainder(dividingBy: updateInterval)

        if secondsForNextСycle > 0 {
            setupShortTimer(seconds: secondsForNextСycle)
        } else {
            setupTimer()
        }
    }

    private func restartTimer() {
        guard isTimerStarted else {
            return
        }

        let distance: TimeInterval = resignDate?.distance(to: Date()) ?? TimeInterval(0)
        reduceCounter(by: distance)

        startTimer()
    }

    /// The method aligns the timer loop by making `counterValue` a multiple of `timeinterval`
    private func setupShortTimer(seconds: TimeInterval) {
        shortTimerTask?.cancel()

        shortTimerTask = Task { @MainActor [weak self] in
            try await Task.sleep(seconds: seconds)
            try Task.checkCancellation()

            self?.reduceCounter(by: seconds)
            self?.setupTimer()
        }
    }

    private func reduceCounter(by value: TimeInterval) {
        counterValue = max(counterValue - value, 0)
    }

    private func setupActiveNotification() {
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink(receiveValue: { [weak self] _ in
                self?.resignDate = Date()
                self?.invalidateTimer()
            })
            .store(in: &subscriptions)

        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink(receiveValue: { [weak self] _ in
                self?.restartTimer()
            })
            .store(in: &subscriptions)
    }
}
