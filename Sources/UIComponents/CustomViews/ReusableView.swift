//
//  ReusableView.swift
//

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
