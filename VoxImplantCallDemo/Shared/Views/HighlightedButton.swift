//
//  HighlightedButton.swift
//  VoxImplantDemo
//
//  Created by Ayya Galieva on 25.07.2024.
//

import UIKit

open class HighlightedButton: UIButton {

    public override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
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
            if isEnabled {
                if newValue {
                    self.highlightedOn()
                } else {
                    self.highlightedOff()
                }
                super.isHighlighted = newValue
            }
        }
    }

    open func highlightedOn() {
        alpha = 0.5
    }

    open func highlightedOff() {
        alpha = 1
    }

    public func setEnabledWithoutHighlighting(_ isEnabled: Bool) {
        super.isEnabled = isEnabled
    }

    private func commonInit() {
        adjustsImageWhenHighlighted = false
        adjustsImageWhenDisabled = false
    }
}
