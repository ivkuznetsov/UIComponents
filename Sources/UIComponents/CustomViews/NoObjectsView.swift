//
//  NoObjectsView.swift
//

import UIKit

open class NoObjectsView: UIView {
    
    @IBOutlet open var title: UILabel!
    @IBOutlet open var details: UILabel!
    @IBOutlet open var actionButton: BorderedButton?
    @IBOutlet open var centerConstraint: NSLayoutConstraint?
    
    open var actionClosure: (()->())? {
        didSet { actionButton?.isHidden = actionClosure == nil }
    }
    
    @IBAction private func action(sender: UIButton) {
        actionClosure?()
    }
    
    open override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if actionButton?.frame.contains(point) == true {
            return super.hitTest(point, with: event)
        }
        return nil
    }
}
