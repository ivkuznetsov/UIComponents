//
//  BorderedButton.swift
//

import UIKit

open class BorderedButton: FadeButton {
    
    @IBInspectable open var borderColor: UIColor? {
        set { layer.borderColor = newValue?.cgColor }
        get {
            if let color = layer.borderColor {
                return UIColor(cgColor: color)
            }
            return nil
        }
    }
    
    @IBInspectable open var onScreenPixelWidth: Bool = true {
        didSet { reloadBorder() }
    }
    
    @IBInspectable open var borderWidth: CGFloat = 0 {
        didSet { reloadBorder() }
    }
    
    @IBInspectable open var cornerRadius: CGFloat {
        set { layer.cornerRadius = newValue }
        get { layer.cornerRadius }
    }
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    private func commonInit() {
        reloadBorder()
        borderColor = titleColor(for: .normal)
        layer.borderColor = borderColor?.cgColor
    }
    
    private func reloadBorder() {
        if onScreenPixelWidth {
            layer.borderWidth = 1.0 / UIScreen.main.scale
        } else {
            layer.borderWidth = borderWidth
        }
    }
}
