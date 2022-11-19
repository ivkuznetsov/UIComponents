//
//  ReusableView.swift
//

#if os(macOS)

import AppKit

open class ReusableView: NSView {

    @IBInspectable public var nibName: String?
    private var nibLoaded = false
    
    open override func awakeFromNib() {
        super.awakeFromNib()
        
        if nibLoaded { return }
        
        nibLoaded = true
        var array: NSArray? = nil
        
        Bundle.main.loadNibNamed(nibName ?? String(describing: type(of: self)), owner: self, topLevelObjects: &array)
        
        var view: NSView? = array?.first(where: { $0 is NSView }) as? NSView
        
        if let view = view {
            view.frame = CGRect(x: 0, y: 0, width: frame.size.width, height: frame.size.height)
            addSubview(view)
            view.translatesAutoresizingMaskIntoConstraints = false
            view.leftAnchor.constraint(equalTo: leftAnchor).isActive = true
            view.rightAnchor.constraint(equalTo: rightAnchor).isActive = true
            view.topAnchor.constraint(equalTo: topAnchor).isActive = true
            view.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        }
    }
}

#else

import UIKit

open class ReusableView: UntouchableView {

    @IBInspectable public var nibName: String?
    
    open override func awakeFromNib() {
        super.awakeFromNib()
        
        var view: UIView?
        
        if let array = Bundle(for: type(of: self)).loadNibNamed(nibName ?? String(describing: type(of: self)), owner: self, options: nil) {
            view = array.first(where: { $0 is UIView }) as? UIView
        }
        
        if let view = view {
            view.frame = CGRect(x: 0, y: 0, width: frame.size.width, height: frame.size.height)
            view.autoresizingMask = [.flexibleHeight, .flexibleWidth]
            insertSubview(view, at: 0)
            layoutMargins = .zero
        }
    }
}

#endif
