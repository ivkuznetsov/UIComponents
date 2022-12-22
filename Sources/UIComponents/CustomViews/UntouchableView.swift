//
//  UntouchableView.swift
//

import UIKit

open class UntouchableView: UIView {

    open override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let view = super.hitTest(point, with: event), view != self {
            return view
        }
        return nil
    }
}
