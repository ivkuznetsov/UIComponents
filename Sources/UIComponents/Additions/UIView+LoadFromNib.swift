//
//  UIView+LoadFromNib.swift
//

import CommonUtils

#if os(iOS)
import UIKit

#else
import AppKit

#endif

public extension View {
    
    static func loadFromNib() -> Self {
        loadFrom(nib: String(describing: self))
    }
    
    static func loadFrom(nib: String, owner: Any? = nil) -> Self {
        loadFrom(nib: nib, owner: owner, type: self)
    }
    
    static func loadFrom<T: View>(nib: String, owner: Any?, type: T.Type) -> T  {
        var bundle = Bundle.main
        if bundle.path(forResource: nib, ofType: "nib") == nil {
            bundle = Bundle(for: type)
        }
        if bundle.path(forResource: nib, ofType: "nib") == nil {
            bundle = Bundle.module
        }
        
        var objects: [Any] = []
        
        #if os(iOS)
        objects = bundle.loadNibNamed(nib, owner: owner, options: nil) ?? []
        #else
        var array: NSArray? = nil
        Bundle.main.loadNibNamed(nib, owner: self, topLevelObjects: &array)
        objects = (array ?? []) as! [Any]
        #endif
        
        return objects.first(where: { $0 is T }) as! T // crash if didn't find
    }
}
