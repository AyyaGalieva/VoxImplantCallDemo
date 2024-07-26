//
//  ConfigurableButton.swift
//  VoxImplantDemo
//
//  Created by Ayya Galieva on 25.07.2024.
//

import UIKit

open class ConfigurableButton: UIButton {

    public struct State {
        let imageTintColor: UIColor
        let backgroundColor: UIColor
        let shouldShowBorder: Bool

        public init(imageTintColor: UIColor,
                    backgroundColor: UIColor,
                    shouldShowBorder: Bool) {
            self.imageTintColor = imageTintColor
            self.backgroundColor = backgroundColor
            self.shouldShowBorder = shouldShowBorder
        }
    }

    private let selectedState: State
    private let normalState: State
    private let borderColor: UIColor

    public init(selectedState: State, normalState: State, borderColor: UIColor) {
        self.selectedState = selectedState
        self.normalState = normalState
        self.borderColor = borderColor
        super.init(frame: .zero)
        commonInit()
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override var isEnabled: Bool {
        get {
            return super.isEnabled
        }
        set {
            if newValue {
                self.highlightedOff()
            } else {
                self.highlightedOn()
            }
            super.isEnabled = newValue
        }
    }

    public override var isHighlighted: Bool {
        get {
            return super.isHighlighted
        }
        set {
            if newValue {
                self.highlightedOn()
            } else {
                self.highlightedOff()
            }
            super.isHighlighted = newValue
        }
    }

    public override var isSelected: Bool {
        get {
            return super.isSelected
        }
        set {
            if newValue {
                apply(state: selectedState)
            } else {
                apply(state: normalState)
            }
            super.isSelected = newValue
        }
    }

    open func highlightedOn() {
        alpha = 0.5
    }

    open func highlightedOff() {
        alpha = 1
    }

    private func commonInit() {
        layer.borderColor = borderColor.cgColor
        adjustsImageWhenHighlighted = false
        adjustsImageWhenDisabled = false
        apply(state: normalState)
    }

    private func apply(state: State) {
        imageView?.tintColor = state.imageTintColor
        backgroundColor = state.backgroundColor
        layer.borderWidth = state.shouldShowBorder ? 2 : 0
    }
}

