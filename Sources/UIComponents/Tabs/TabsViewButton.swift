//
//  TabsViewButton.swift
//

#if os(iOS)

import UIKit

@objcMembers
open class TabsViewButton: UIButton {
    
    open var badgeColor: UIColor = UIColor.red {
        didSet { setNeedsDisplay() }
    }
    
    open var showBadge: Bool = false {
        didSet { setNeedsDisplay() }
    }
    
    open override var frame: CGRect {
        didSet { setNeedsDisplay() }
    }
    
    open override var bounds: CGRect {
        didSet { setNeedsDisplay() }
    }
    
    open override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        if showBadge {
            let badgeWidth: CGFloat = 6.0
            
            badgeColor.setFill()
            UIBezierPath(roundedRect: CGRect(x: titleLabel!.x - 5 - badgeWidth,
                                             y: height / 2.0 - badgeWidth / 2.0 + 1,
                                             width: badgeWidth,
                                             height: badgeWidth), cornerRadius: badgeWidth / 2.0).fill()
        }
    }
}

#endif
