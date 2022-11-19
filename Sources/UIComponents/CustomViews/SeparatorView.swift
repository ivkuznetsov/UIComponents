//
//  SeparatorView.swift
//

#if os(iOS)

import UIKit

open class SeparatorView: UIView {
    
    open var color: UIColor?
    
    open override var backgroundColor: UIColor? {
        set {
            color = newValue
            setNeedsDisplay()
        }
        get { color }
    }
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    func commonInit() {
        super.backgroundColor = UIColor.clear
    }
    
    open override func draw(_ rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()!
        context.beginPath()
        
        color?.setStroke()
        
        let lineWidth: CGFloat = 1.0 / UIScreen.main.scale
        
        context.setLineWidth(lineWidth)
        
        if bounds.size.height == 1 {
            let y = contentMode == .top ? lineWidth / 2.0 : (bounds.size.height - lineWidth / 2.0)
            context.move(to: CGPoint(x: 0, y: y))
            context.addLine(to: CGPoint(x: bounds.size.width, y: y))
        } else if bounds.size.width == 1 {
            let x = contentMode == .right ? (bounds.size.width - lineWidth / 2.0) : lineWidth / 2.0
            context.move(to: CGPoint(x: x, y: 0))
            context.addLine(to: CGPoint(x: x, y: bounds.size.height))
        }
        context.strokePath()
    }
    
    open override func layoutSubviews() {
        super.layoutSubviews()
        setNeedsDisplay()
    }
}

#endif
