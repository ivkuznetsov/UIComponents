//
//  UIView+LoadFromNib.swift
//

import UIKit

public extension UIView {
    
    static func loadFromNib(_ nib: String? = nil, owner: Any? = nil) -> Self {
        loadFrom(nib: nib ?? String(describing: self), owner: owner, type: self)
    }
    
    private static func loadFrom<T: UIView>(nib: String, owner: Any?, type: T.Type) -> T  {
        var bundle = Bundle.main
        if bundle.path(forResource: nib, ofType: "nib") == nil {
            bundle = Bundle(for: type)
        }
        if bundle.path(forResource: nib, ofType: "nib") == nil {
            bundle = Bundle.module
        }
        let objects = bundle.loadNibNamed(nib, owner: owner, options: nil)
        
        return objects?.first(where: { $0 is T }) as! T // crash if didn't find
    }
}
